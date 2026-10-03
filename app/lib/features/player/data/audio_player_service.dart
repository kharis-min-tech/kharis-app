import 'dart:async';
import 'dart:math' as math;

import 'package:audio_session/audio_session.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

import 'package:kharis_app/core/constants/http_constants.dart';
import 'package:kharis_app/core/services/cache_service.dart';
import 'package:kharis_app/features/player/data/playback_history.dart';
import 'package:kharis_app/features/player/data/playback_queue.dart';
import 'package:kharis_app/shared/models/sermon.dart';

export 'package:kharis_app/features/player/data/playback_queue.dart';

/// A playback load that failed, carried with the sermon it belongs to so a
/// banner never outlives the message it describes.
@immutable
class PlaybackFailure {
  const PlaybackFailure({required this.sermonId, required this.message});

  /// [Sermon.id] the failure belongs to.
  final String sermonId;

  /// Member-facing explanation, ready to render.
  final String message;

  @override
  bool operator ==(Object other) =>
      other is PlaybackFailure &&
      other.sermonId == sermonId &&
      other.message == message;

  @override
  int get hashCode => Object.hash(sermonId, message);
}

/// Wraps [AudioPlayer] (just_audio) with a sermon-aware, queue-aware API.
///
/// Lifecycle: create once, dispose when the owning scope is destroyed.
/// The Riverpod provider calls [dispose] via [ref.onDispose].
///
/// Queue: every [play] carries the list the member launched from as a
/// [PlaybackQueue]. The native player holds a window of that queue (the
/// current message and its neighbours) in a [ConcatenatingAudioSource], so
/// the lock screen, notification and CarPlay show the same Previous / Next
/// as the app, and a finished message advances on its own. The window grows
/// at its edges as the member moves, never reloading the message on air.
///
/// Playback resume: position is persisted through [PlaybackHistory] every
/// ~5 s while playing and immediately on pause/stop/skip/dispose. [play]
/// starts at an explicit `startAt` or the saved resume point; a finished
/// message resets to 0.
///
/// Failures: [play] never throws. It returns whether playback started, and a
/// load or mid-stream failure is recorded on [failure] / [failureStream] so
/// the UI can show it and offer [retry]. Every failed load releases the
/// native player, and [resume] reloads when there is nothing live to resume.
class AudioPlayerService {
  AudioPlayerService(this._cache)
    : _history = PlaybackHistory(_cache),
      _player = AudioPlayer(
        // Send the Cloudflare-passing browser UA natively — ExoPlayer's
        // setUserAgent on Android, AVURLAssetHTTPUserAgentKey on iOS — by
        // opting out of just_audio's header proxy. That proxy re-serves the
        // stream from plain `http://127.0.0.1:<port>`, which iOS App
        // Transport Security blocks unless the app ships
        // NSAllowsArbitraryLoads, so every header-bearing load stalled on
        // device. Native headers keep the request HTTPS end to end.
        userAgent: kBrowserUserAgent,
        useProxyForRequestHeaders: false,
      ) {
    _setupListeners();
    unawaited(_configureSession());
    final speed = _savedSpeed();
    if (speed != 1.0) unawaited(_player.setSpeed(speed));
  }

  /// A source that never answers leaves just_audio parked on
  /// [ProcessingState.loading] forever, so every load is bounded.
  static const Duration _loadTimeout = Duration(seconds: 25);

  /// Preference key of the persisted playback speed.
  static const String speedPreferenceKey = 'playback_speed';

  final AudioPlayer _player;
  final CacheService _cache;
  final PlaybackHistory _history;
  Sermon? _currentSermon;

  /// The list playback was launched from, positioned on [_currentSermon].
  PlaybackQueue? _queue;

  /// The native source and the queue index of its first child. The children
  /// are always the contiguous slice `_queue.items[_windowStart ..]`.
  ConcatenatingAudioSource? _source;
  int _windowStart = 0;

  /// Queue index an app-initiated skip is moving to, so the index listener
  /// does not re-apply a resume point the skip already sought to.
  int? _expectedIndex;

  /// Incremented per load request. A load whose token is stale has been
  /// superseded (the member picked another message) and must not touch state.
  int _loadToken = 0;

  /// Loads in progress; their errors are reported by [_loadSource], so the
  /// mid-stream error channel stays quiet meanwhile.
  int _loadsInFlight = 0;

  final StreamController<PlaybackFailure?> _failureController =
      StreamController<PlaybackFailure?>.broadcast();
  PlaybackFailure? _failure;

  final StreamController<PlaybackQueue?> _queueController =
      StreamController<PlaybackQueue?>.broadcast();

  /// Tracks last time a position was persisted; avoids hammering Hive.
  DateTime? _lastPositionSave;

  final List<StreamSubscription<Object?>> _subscriptions = [];

  // ── Private helpers ────────────────────────────────────────────────────────

  void _setupListeners() {
    // Throttle-save position every ~5 s while actively playing.
    _subscriptions.add(
      _player.positionStream.listen((pos) {
        final sermon = _currentSermon;
        if (sermon == null || !_player.playing) return;
        final now = DateTime.now();
        final last = _lastPositionSave;
        if (last == null ||
            now.difference(last) >= const Duration(seconds: 5)) {
          _lastPositionSave = now;
          _history.savePosition(sermon, pos);
        }
      }, onError: _ignore),
    );

    // Save on pause; clear on natural completion.
    _subscriptions.add(
      _player.playerStateStream.listen((state) {
        final sermon = _currentSermon;
        if (sermon == null) return;
        if (state.processingState == ProcessingState.completed) {
          // Reset so the next play() starts from the beginning.
          _history.clearPosition(sermon);
          return;
        }
        if (!state.playing) _saveCurrentPosition();
      }, onError: _ignore),
    );

    // Errors that surface after a successful load (connection dropped
    // mid-stream, next item unplayable) used to be swallowed, leaving a
    // silent player with a Pause button.
    _subscriptions.add(
      _player.playbackEventStream.listen((_) {}, onError: _onStreamError),
    );

    // The native player moves on its own: a finished message advances, and
    // the lock screen / CarPlay skip buttons seek the window directly.
    _subscriptions.add(_player.currentIndexStream.listen(_onNativeIndex));

    _subscriptions.add(
      _player.positionDiscontinuityStream.listen((event) {
        if (event.reason != PositionDiscontinuityReason.autoAdvance) return;
        final finished = _sermonAtNative(event.previousEvent.currentIndex);
        if (finished != null) _history.clearPosition(finished);
      }, onError: _ignore),
    );

    // Learn lengths the catalogue lacks, so "Continue listening" can draw
    // progress for them later.
    _subscriptions.add(
      _player.durationStream.listen((duration) {
        final sermon = _currentSermon;
        if (sermon == null || duration == null) return;
        // Only once the native player is on this message, never the outgoing
        // one's length mid-skip.
        if (_sermonAtNative(_player.currentIndex)?.id != sermon.id) return;
        _history.rememberDuration(sermon, duration);
      }, onError: _ignore),
    );
  }

  static void _ignore(Object _) {}

  /// Spoken-word session: ducks for navigation prompts, pauses for calls.
  /// just_audio's own `handleInterruptions` (on by default) does the pausing,
  /// resuming and headphone-unplug handling against this configuration.
  Future<void> _configureSession() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.speech());
    } catch (_) {
      // No audio session on this platform (tests, web): nothing to configure.
    }
  }

  double _savedSpeed() {
    final value = _cache.getPreference<Object?>(speedPreferenceKey, null);
    return value is num && value > 0 ? value.toDouble() : 1.0;
  }

  void _saveCurrentPosition() {
    final sermon = _currentSermon;
    if (sermon == null) return;
    _history.savePosition(sermon, _player.position);
    _lastPositionSave = DateTime.now();
  }

  void _onStreamError(Object error, [StackTrace? _]) {
    if (_loadsInFlight > 0 || error is PlayerInterruptedException) return;
    final sermon = _currentSermon;
    if (sermon == null) return;
    _saveCurrentPosition();
    _setFailure(
      PlaybackFailure(
        sermonId: sermon.id,
        message:
            'Playback stopped unexpectedly. Check your connection and tap '
            'retry to pick up where you left off.',
      ),
    );
  }

  void _emitQueue() {
    if (!_queueController.isClosed) _queueController.add(_queue);
  }

  // ── Accessors ──────────────────────────────────────────────────────────────

  Sermon? get currentSermon => _currentSermon;

  /// Current playback position, for handing the timeline to another engine.
  Duration get position => _player.position;

  /// The queue playback was launched from, or null when nothing is loaded.
  PlaybackQueue? get queue => _queue;

  /// Emits on every queue move and replacement, including the clear to null.
  Stream<PlaybackQueue?> get queueStream => _queueController.stream;

  /// The load failure the member still needs to see, or null when the last
  /// load succeeded. Read this to seed a widget that mounts after the failure.
  PlaybackFailure? get failure => _failure;

  /// Emits on every failure transition, including the clear back to null.
  Stream<PlaybackFailure?> get failureStream => _failureController.stream;

  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;

  /// The playback rate, persisted across launches.
  double get speed => _player.speed;
  Stream<double> get speedStream => _player.speedStream;

  /// Whether the current message repeats when it ends.
  bool get repeatOne => _player.loopMode == LoopMode.one;
  Stream<bool> get repeatOneStream =>
      _player.loopModeStream.map((mode) => mode == LoopMode.one);

  // ── Source management ──────────────────────────────────────────────────────

  /// One queue entry as a native source, tagged with a [MediaItem] so the OS
  /// shows artwork, title and transport controls for it.
  ///
  /// The browser User-Agent the host demands is set once on the [AudioPlayer],
  /// so no per-source headers are needed (and no header proxy is engaged).
  static AudioSource _child(Sermon sermon) {
    final art = sermon.artworkUrl;
    return AudioSource.uri(
      Uri.parse(sermon.audioUrl),
      tag: MediaItem(
        id: sermon.id,
        title: sermon.title,
        artist: sermon.speaker,
        album: sermon.series ?? 'Kharis Church',
        artUri: art != null ? Uri.tryParse(art) : null,
        duration: sermon.duration,
      ),
    );
  }

  /// The queue entry behind native index [nativeIndex], matched by tag id so
  /// a window that shifted under an insert still resolves correctly.
  Sermon? _sermonAtNative(int? nativeIndex) {
    final queue = _queue;
    final sequence = _player.sequence;
    if (queue == null || nativeIndex == null || sequence == null) return null;
    if (nativeIndex < 0 || nativeIndex >= sequence.length) return null;
    final tag = sequence[nativeIndex].tag;
    if (tag is! MediaItem) return null;
    for (final sermon in queue.items) {
      if (sermon.id == tag.id) return sermon;
    }
    return null;
  }

  void _onNativeIndex(int? nativeIndex) {
    final queue = _queue;
    // Mid-load the sequence already shows the new window while the index
    // still points into the old one; the load itself positions the queue.
    if (queue == null || _source == null || _loadsInFlight > 0) return;
    final sermon = _sermonAtNative(nativeIndex);
    if (sermon == null) return;
    final index = queue.items.indexWhere((s) => s.id == sermon.id);
    _windowStart = index - nativeIndex!;
    if (index == queue.index) return;

    final appInitiated = _expectedIndex == index;
    _expectedIndex = null;
    _queue = queue.moveTo(index);
    _currentSermon = sermon;
    _lastPositionSave = null;
    _setFailure(null);
    _emitQueue();
    _history.recordPlay(sermon);
    if (!appInitiated) {
      // Lock-screen skips and auto-advance land at 0:00; pick the message up
      // where the member left it, like a tap in the app would.
      final resume = _history.resumePoint(sermon);
      if (resume != null) unawaited(_safely(_player.seek(resume)));
    }
    unawaited(_safely(_extendWindow()));
  }

  /// Keeps a neighbour on each side of the current message in the native
  /// window, so the lock screen always offers Previous / Next when the queue
  /// has them. Only appends or prepends: the message on air is never touched.
  Future<void> _extendWindow() async {
    final source = _source;
    final queue = _queue;
    if (source == null || queue == null) return;
    final end = _windowStart + source.length;
    if (queue.hasNext && queue.index + 1 >= end && end < queue.items.length) {
      await source.add(_child(queue.items[end]));
    }
    if (queue.hasPrevious && queue.index <= _windowStart && _windowStart > 0) {
      // Shift first: the native index bump this insert causes must resolve
      // against the new start.
      _windowStart -= 1;
      await source.insert(0, _child(queue.items[_windowStart]));
    }
  }

  /// Replaces the neighbours around the message on air with those of a new
  /// queue, without reloading it. Used when the member re-taps the playing
  /// message from a different list.
  Future<void> _rebuildWindow() async {
    final source = _source;
    final queue = _queue;
    final nativeIndex = _player.currentIndex;
    if (source == null || queue == null || nativeIndex == null) return;
    if (nativeIndex + 1 < source.length) {
      await source.removeRange(nativeIndex + 1, source.length);
    }
    if (nativeIndex > 0) await source.removeRange(0, nativeIndex);
    _windowStart = queue.index;
    await _extendWindow();
  }

  static Future<void> _safely(Future<void> work) => work.catchError((Object _) {
    /* reported via the event stream */
  });

  void _setFailure(PlaybackFailure? failure) {
    if (_failure == failure) return;
    _failure = failure;
    if (!_failureController.isClosed) _failureController.add(failure);
  }

  /// Prepares the queue window around [queue.current] within [_loadTimeout],
  /// positioned at [initialPosition].
  ///
  /// Returns false when the source could not be prepared; a member-facing
  /// [PlaybackFailure] is recorded unless this load was superseded by a newer
  /// one, in which case the newer load owns the player and its own outcome.
  Future<bool> _loadSource(
    PlaybackQueue queue,
    int token, {
    Duration? initialPosition,
    bool report = true,
  }) async {
    final start = math.max(0, queue.index - 1);
    final end = math.min(queue.items.length, queue.index + 2);
    final source = ConcatenatingAudioSource(
      children: [for (var i = start; i < end; i++) _child(queue.items[i])],
    );
    _source = source;
    _windowStart = start;

    _loadsInFlight++;
    final load = _player.setAudioSource(
      source,
      initialIndex: queue.index - start,
      initialPosition: initialPosition,
    );
    // Keep the raw future observed: after a timeout we stop awaiting it, and an
    // unobserved rejection would otherwise land in the zone error handler.
    unawaited(load.catchError((Object _) => null));
    try {
      await load.timeout(_loadTimeout);
      return token == _loadToken;
    } catch (error) {
      if (token != _loadToken || error is PlayerInterruptedException) {
        return false;
      }
      if (report) {
        _setFailure(
          PlaybackFailure(
            sermonId: queue.current.id,
            message: _describe(error),
          ),
        );
      }
      // Drop the native player so the retry starts from a clean instance
      // instead of inheriting a half-prepared one.
      await _release();
      return false;
    } finally {
      _loadsInFlight--;
    }
  }

  static String _describe(Object error) {
    if (error is TimeoutException) {
      return 'That message took too long to load. Check your connection and '
          'try again.';
    }
    if (error is PlayerException) {
      return 'We couldn\u2019t play that message (error ${error.code}). '
          'Tap retry to try again.';
    }
    return 'We couldn\u2019t play that message. Tap retry to try again.';
  }

  Future<void> _release() async {
    try {
      await _player.stop();
    } catch (_) {
      // Already torn down; nothing left to release.
    }
    _source = null;
  }

  /// Starts the engine WITHOUT waiting on it: just_audio's `play()` future
  /// completes only when playback pauses, stops or ends, so awaiting it held
  /// every caller (handoff seeks, note anchors, history) hostage until the
  /// member pressed pause.
  void _startEngine() {
    unawaited(
      _player.play().catchError((Object _) {
        // Reported through the playback event stream.
      }),
    );
  }

  /// Whether [sermon] is already loaded and healthy, so a new request can
  /// attach to it instead of reloading the source.
  bool _isLive(Sermon sermon) =>
      _currentSermon?.id == sermon.id &&
      _failure == null &&
      _source != null &&
      _player.processingState != ProcessingState.idle;

  // ── Playback control ───────────────────────────────────────────────────────

  /// Plays [sermon] as part of [queue] (the list the member launched from;
  /// null plays it alone), from [startAt] when given or else the saved
  /// resume point.
  ///
  /// Re-requesting the message already on air does not reload it: the queue
  /// is adopted, [startAt] is sought, and paused or finished playback
  /// resumes.
  ///
  /// Returns once the source is prepared and the engine has been started,
  /// never waiting for playback itself to end. Never throws: returns true
  /// when playback started, false when it did not (in which case [failure]
  /// describes why, unless a newer request took over).
  Future<bool> play(
    Sermon sermon, {
    Duration? startAt,
    List<Sermon>? queue,
  }) async {
    if (_isLive(sermon)) {
      if (queue != null) {
        final next = PlaybackQueue.from(sermon, queue);
        if (next != _queue) {
          _queue = next;
          _emitQueue();
          await _safely(_rebuildWindow());
        }
      }
      if (startAt != null) {
        await _player.seek(startAt);
      } else if (_player.processingState == ProcessingState.completed) {
        await _player.seek(Duration.zero, index: _player.currentIndex);
      }
      _startEngine();
      return true;
    }

    final token = ++_loadToken;
    _saveCurrentPosition();
    final playbackQueue = PlaybackQueue.from(sermon, queue);
    _queue = playbackQueue;
    _currentSermon = sermon;
    _expectedIndex = null;
    _setFailure(null);
    _emitQueue();

    if (!sermon.hasAudio) {
      // Nothing to stream. Loading an empty URL wedges the player rather than
      // failing, so refuse it up front.
      // The previous message must not keep playing under this failure.
      if (_source != null) await _release();
      _setFailure(
        PlaybackFailure(
          sermonId: sermon.id,
          // Video-only sermons are routed to the video engine before they can
          // reach this service (see startPlayback), so this is a backstop only.
          message: sermon.hasVideo
              ? 'This message has no audio recording.'
              : 'This message has no recording yet.',
        ),
      );
      return false;
    }

    final resume = startAt ?? _history.resumePoint(sermon);
    if (!await _loadSource(playbackQueue, token, initialPosition: resume)) {
      return false;
    }
    // The real length is known now: a saved point in the closing seconds
    // means the message was finished, so start it over.
    final duration = _player.duration;
    if (startAt == null &&
        resume != null &&
        duration != null &&
        resume >= duration - PlaybackHistory.endGuard) {
      await _player.seek(Duration.zero);
    }
    if (token != _loadToken) return false;
    _startEngine();

    // Recorded for this load only, once the source is real, so a failed or
    // superseded load never lands in "Recently played" or the play metric.
    _history.recordPlay(sermon);
    if (Firebase.apps.isNotEmpty) {
      // Fire-and-forget engagement event; never blocks playback.
      unawaited(
        FirebaseAnalytics.instance.logEvent(
          name: 'play_sermon',
          parameters: {
            'sermon_id': sermon.id,
            'title': sermon.title,
            'speaker': sermon.speaker,
          },
        ),
      );
    }
    return true;
  }

  /// Re-attempts the loaded sermon after a failure, in the same queue. False
  /// when there is nothing loaded to retry.
  Future<bool> retry() {
    final sermon = _currentSermon;
    if (sermon == null) return Future.value(false);
    return play(sermon, queue: _queue?.items);
  }

  /// Loads [sermon] paused at its saved resume position, without starting
  /// playback. Used on app launch to restore the minimised player where the
  /// listener left off.
  ///
  /// Yields to a real [play]: a restore that resolves after the member has
  /// tapped a message must not steal the player back, which is what used to
  /// leave the first tap of a session silent.
  Future<void> loadPaused(Sermon sermon) async {
    if (_currentSermon != null || !sermon.hasAudio) return;
    final token = ++_loadToken;
    final queue = PlaybackQueue.from(sermon);
    _currentSermon = sermon;
    _queue = queue;
    _emitQueue();
    // A silent restore: nothing was asked for, so nothing is reported.
    final loaded = await _loadSource(
      queue,
      token,
      initialPosition: _history.resumePoint(sermon),
      report: false,
    );
    if (!loaded && token == _loadToken) {
      _currentSermon = null;
      _queue = null;
      _emitQueue();
    }
  }

  /// Moves to the next message in the queue. No-op at the end.
  Future<void> skipToNext() async {
    final queue = _queue;
    if (queue == null || !queue.hasNext) return;
    await _moveTo(queue.index + 1);
  }

  /// Spotify-style Previous: restarts the current message once it is past
  /// [PlaybackQueue.restartThreshold], otherwise steps back one message.
  Future<void> skipToPrevious() async {
    final queue = _queue;
    if (queue == null) return;
    switch (queue.previousAction(_player.position)) {
      case PreviousAction.restart:
        if (_isLive(queue.current)) {
          await _player.seek(Duration.zero, index: _player.currentIndex);
          _startEngine();
        } else {
          await play(queue.current, startAt: Duration.zero, queue: queue.items);
        }
      case PreviousAction.previousItem:
        await _moveTo(queue.index - 1);
      case PreviousAction.none:
        return;
    }
  }

  Future<void> _moveTo(int index) async {
    final queue = _queue!;
    final target = queue.items[index];
    final source = _source;
    final nativeIndex = index - _windowStart;
    final inWindow =
        source != null && nativeIndex >= 0 && nativeIndex < source.length;
    if (!inWindow || !_isLive(queue.current)) {
      // Nothing live to move within (failed or released): load the target
      // fresh, keeping the queue.
      await play(target, queue: queue.items);
      return;
    }
    _saveCurrentPosition();
    _expectedIndex = index;
    await _safely(
      _player.seek(
        _history.resumePoint(target) ?? Duration.zero,
        index: nativeIndex,
      ),
    );
    _startEngine();
  }

  /// Pauses playback; position is saved via the [playerStateStream] listener.
  Future<void> pause() => _player.pause();

  /// Resumes after a [pause], reloading first when there is nothing live to
  /// resume (a failed load, or a native player that was released). A message
  /// that played to the end starts over instead of sitting on its last frame.
  Future<void> resume() async {
    final sermon = _currentSermon;
    if (sermon == null) return;
    if (_failure != null ||
        _source == null ||
        _player.processingState == ProcessingState.idle) {
      await play(sermon, queue: _queue?.items);
      return;
    }
    if (_player.processingState == ProcessingState.completed) {
      await _player.seek(Duration.zero, index: _player.currentIndex);
    }
    _startEngine();
  }

  /// Stops playback and releases the current audio source and queue.
  ///
  /// Position is captured synchronously before the async stop so it is not
  /// lost if [_currentSermon] is cleared mid-teardown.
  Future<void> stop() async {
    _loadToken++;
    _saveCurrentPosition();
    _setFailure(null);
    _source = null;
    await _player.stop();
    _currentSermon = null;
    _queue = null;
    _emitQueue();
  }

  Future<void> seek(Duration position) => _player.seek(position);

  /// Sets and persists the playback rate.
  Future<void> setSpeed(double speed) {
    _cache.cachePreference(speedPreferenceKey, speed);
    return _player.setSpeed(speed);
  }

  /// Repeats the current message when it ends (lock screen included).
  Future<void> setRepeatOne(bool enabled) =>
      _player.setLoopMode(enabled ? LoopMode.one : LoopMode.off);

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  Future<void> dispose() async {
    // Flush position before tearing down subscriptions.
    if (_player.playing) _saveCurrentPosition();
    for (final sub in _subscriptions) {
      await sub.cancel();
    }
    await _failureController.close();
    await _queueController.close();
    await _player.dispose();
  }
}
