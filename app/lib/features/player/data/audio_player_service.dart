import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio_background/just_audio_background.dart';

import 'package:kharis_app/core/services/cache_service.dart';
import 'package:kharis_app/core/constants/http_constants.dart';
import 'package:kharis_app/shared/models/sermon.dart';

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

/// Wraps [AudioPlayer] (just_audio) with a sermon-aware API.
///
/// Lifecycle: create once, dispose when the owning scope is destroyed.
/// The Riverpod provider calls [dispose] via [ref.onDispose].
///
/// Playback resume: position is persisted to [CacheService] every ~5 s while
/// playing and immediately on pause/stop/dispose.  On [play], any saved
/// position > 10 s and more than 15 s before the end is restored so the
/// listener picks up where they left off.  A completed sermon resets to 0.
///
/// Failures: [play] never throws. It returns whether playback started, and a
/// load that fails is recorded on [failure] / [failureStream] so the UI can
/// show it and offer [retry]. Every failed load releases the native player, and
/// [resume] reloads when there is nothing live to resume, so a bad load never
/// needs an app restart to clear.
class AudioPlayerService {
  AudioPlayerService(this._cache)
      : _player = AudioPlayer(
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
  }

  /// A source that never answers leaves just_audio parked on
  /// [ProcessingState.loading] forever, so every load is bounded.
  static const Duration _loadTimeout = Duration(seconds: 25);

  final AudioPlayer _player;
  final CacheService _cache;
  Sermon? _currentSermon;

  /// Incremented per load request. A load whose token is stale has been
  /// superseded (the member picked another message) and must not touch state.
  int _loadToken = 0;

  final StreamController<PlaybackFailure?> _failureController =
      StreamController<PlaybackFailure?>.broadcast();
  PlaybackFailure? _failure;

  /// Tracks last time a position was persisted; avoids hammering Hive.
  DateTime? _lastPositionSave;

  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<PlayerState>? _stateSub;
  StreamSubscription<AudioInterruptionEvent>? _interruptionSub;
  StreamSubscription<void>? _noisySub;

  /// Whether playback was paused by an interruption (call, Siri, nav prompt)
  /// and should resume when the interruption ends.
  bool _resumeOnInterruptionEnd = false;

  // ── Private helpers ────────────────────────────────────────────────────────

  void _setupListeners() {
    // Throttle-save position every ~5 s while actively playing.
    _positionSub = _player.positionStream.listen((pos) {
      final sermon = _currentSermon;
      if (sermon == null || !_player.playing) return;
      if (pos.inMilliseconds <= 10000) return;

      final now = DateTime.now();
      final last = _lastPositionSave;
      if (last == null || now.difference(last) >= const Duration(seconds: 5)) {
        _lastPositionSave = now;
        _cache.cachePlaybackPosition(sermon.id, pos.inMilliseconds);
      }
    }, onError: (Object _) {/* load failures are reported by _loadSource */});

    // Save on pause; clear on natural completion.
    _stateSub = _player.playerStateStream.listen((state) {
      final sermon = _currentSermon;
      if (sermon == null) return;

      if (state.processingState == ProcessingState.completed) {
        // Reset so the next play() starts from the beginning.
        _cache.cachePlaybackPosition(sermon.id, 0);
        return;
      }

      if (!state.playing) {
        final pos = _player.position;
        if (pos.inMilliseconds > 10000) {
          _cache.cachePlaybackPosition(sermon.id, pos.inMilliseconds);
          _lastPositionSave = DateTime.now();
        }
      }
    }, onError: (Object _) {/* load failures are reported by _loadSource */});
  }

  /// Premium in-car / on-the-go session behavior:
  /// - phone call, Siri, or nav prompt pauses playback and resumes after
  ///   (when iOS says resuming is appropriate);
  /// - unplugging headphones / disconnecting Bluetooth pauses instead of
  ///   blasting the speaker.
  Future<void> _configureSession() async {
    final session = await AudioSession.instance;
    _interruptionSub = session.interruptionEventStream.listen((event) {
      if (event.begin) {
        switch (event.type) {
          case AudioInterruptionType.duck:
            // iOS ducks system-wide automatically; nothing to do.
            break;
          case AudioInterruptionType.pause:
          case AudioInterruptionType.unknown:
            if (_player.playing) {
              _resumeOnInterruptionEnd = true;
              _player.pause();
            }
        }
      } else {
        switch (event.type) {
          case AudioInterruptionType.pause:
            if (_resumeOnInterruptionEnd) {
              _resumeOnInterruptionEnd = false;
              _player.play();
            }
          case AudioInterruptionType.duck:
          case AudioInterruptionType.unknown:
            _resumeOnInterruptionEnd = false;
        }
      }
    });
    _noisySub = session.becomingNoisyEventStream.listen((_) {
      _resumeOnInterruptionEnd = false;
      _player.pause();
    });
  }

  void _saveCurrentPosition() {
    final sermon = _currentSermon;
    if (sermon == null) return;
    final pos = _player.position;
    if (pos.inMilliseconds > 10000) {
      _cache.cachePlaybackPosition(sermon.id, pos.inMilliseconds);
      _lastPositionSave = DateTime.now();
    }
  }

  // ── Accessors ──────────────────────────────────────────────────────────────

  Sermon? get currentSermon => _currentSermon;

  /// Current playback position, for handing the timeline to another engine.
  Duration get position => _player.position;

  /// The load failure the member still needs to see, or null when the last
  /// load succeeded. Read this to seed a widget that mounts after the failure.
  PlaybackFailure? get failure => _failure;

  /// Emits on every failure transition, including the clear back to null.
  Stream<PlaybackFailure?> get failureStream => _failureController.stream;

  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;

  // ── Playback control ───────────────────────────────────────────────────────

  /// Loads [sermon]'s audio with a [MediaItem] tag so the OS shows artwork,
  /// title, and transport controls on the lock screen / notification shade.
  ///
  /// The browser User-Agent the host demands is set once on the [AudioPlayer],
  /// so no per-source headers are needed (and no header proxy is engaged).
  Future<Duration?> _setSource(Sermon sermon) {
    final art = sermon.artworkUrl;
    return _player.setAudioSource(
      AudioSource.uri(
        Uri.parse(sermon.audioUrl),
        tag: MediaItem(
          id: sermon.id,
          title: sermon.title,
          artist: sermon.speaker,
          album: sermon.series ?? 'Kharis Church',
          artUri: art != null ? Uri.tryParse(art) : null,
          duration: sermon.duration,
        ),
      ),
    );
  }

  void _setFailure(PlaybackFailure? failure) {
    if (_failure == failure) return;
    _failure = failure;
    if (!_failureController.isClosed) _failureController.add(failure);
  }

  /// Prepares [sermon] for playback within [_loadTimeout].
  ///
  /// Returns false when the source could not be prepared; a member-facing
  /// [PlaybackFailure] is recorded unless this load was superseded by a newer
  /// one, in which case the newer load owns the player and its own outcome.
  Future<bool> _loadSource(
    Sermon sermon,
    int token, {
    bool report = true,
  }) async {
    final load = _setSource(sermon);
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
          PlaybackFailure(sermonId: sermon.id, message: _describe(error)),
        );
      }
      // Drop the native player so the retry starts from a clean instance
      // instead of inheriting a half-prepared one.
      await _release();
      return false;
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
  }

  /// Restores a saved resume position that falls inside the resumable window.
  Future<void> _restorePosition(Sermon sermon) async {
    final savedMs = _cache.getPlaybackPosition(sermon.id);
    final duration = _player.duration;
    if (savedMs > 10000 &&
        duration != null &&
        savedMs < duration.inMilliseconds - 15000) {
      await _player.seek(Duration(milliseconds: savedMs));
    }
  }

  /// Loads the sermon's audio URL, seeks to any saved resume position, and
  /// starts playback immediately.
  ///
  /// Never throws: returns true when playback started, false when it did not
  /// (in which case [failure] describes why, unless a newer request took over).
  Future<bool> play(Sermon sermon) async {
    final token = ++_loadToken;
    _currentSermon = sermon;
    _setFailure(null);

    if (!sermon.hasAudio) {
      // Nothing to stream. Loading an empty URL wedges the player rather than
      // failing, so refuse it up front.
      _setFailure(PlaybackFailure(
        sermonId: sermon.id,
        // Video-only sermons are routed to the video engine before they can
        // reach this service (see startPlayback), so this is a backstop only.
        message: sermon.hasVideo
            ? 'This message has no audio recording.'
            : 'This message has no recording yet.',
      ));
      return false;
    }

    if (!await _loadSource(sermon, token)) return false;
    await _restorePosition(sermon);
    if (token != _loadToken) return false;
    await _player.play();

    // Recorded only once playback is real, so a failed load never lands in
    // "Recently played" or inflates the play metric.
    _cache.addRecentlyPlayed(sermon.id);
    if (Firebase.apps.isNotEmpty) {
      // Fire-and-forget engagement event; never blocks playback.
      unawaited(FirebaseAnalytics.instance.logEvent(
        name: 'play_sermon',
        parameters: {
          'sermon_id': sermon.id,
          'title': sermon.title,
          'speaker': sermon.speaker,
        },
      ));
    }
    return true;
  }

  /// Re-attempts the loaded sermon after a failure. False when there is
  /// nothing loaded to retry.
  Future<bool> retry() {
    final sermon = _currentSermon;
    if (sermon == null) return Future.value(false);
    return play(sermon);
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
    _currentSermon = sermon;
    // A silent restore: nothing was asked for, so nothing is reported.
    if (!await _loadSource(sermon, token, report: false)) {
      if (token == _loadToken) _currentSermon = null;
      return;
    }
    await _restorePosition(sermon);
  }

  /// Pauses playback; position is saved via the [playerStateStream] listener.
  Future<void> pause() => _player.pause();

  /// Resumes after a [pause], reloading first when there is nothing live to
  /// resume — a failed load, or a native player that was released. Without
  /// that the play button stayed dead until the app was restarted.
  Future<void> resume() async {
    final sermon = _currentSermon;
    if (sermon == null) return;
    if (_failure != null || _player.processingState == ProcessingState.idle) {
      await play(sermon);
      return;
    }
    await _player.play();
  }

  /// Stops playback and releases the current audio source.
  ///
  /// Position is captured synchronously before the async stop so it is not
  /// lost if [_currentSermon] is cleared mid-teardown.
  Future<void> stop() async {
    _loadToken++;
    _saveCurrentPosition();
    _setFailure(null);
    await _player.stop();
    _currentSermon = null;
  }

  Future<void> seek(Duration position) => _player.seek(position);

  Future<void> setSpeed(double speed) => _player.setSpeed(speed);

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  Future<void> dispose() async {
    // Flush position before tearing down subscriptions.
    if (_player.playing) _saveCurrentPosition();
    await _positionSub?.cancel();
    await _stateSub?.cancel();
    await _interruptionSub?.cancel();
    await _noisySub?.cancel();
    await _failureController.close();
    await _player.dispose();
  }
}
