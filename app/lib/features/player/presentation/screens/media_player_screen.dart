import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/features/notes/data/note_timeline_key.dart';
import 'package:kharis_app/features/notes/presentation/widgets/sermon_notes_sheet.dart'
    show NoteTimelineBinding;
import 'package:kharis_app/features/player/data/audio_player_service.dart';
import 'package:kharis_app/features/player/data/playback_history.dart';
import 'package:kharis_app/features/player/presentation/media_mode.dart';
import 'package:kharis_app/features/player/presentation/playback_launcher.dart'
    show startAudioPlayback;
import 'package:kharis_app/features/player/presentation/widgets/like_button.dart';
import 'package:kharis_app/features/player/presentation/widgets/media_mode_toggle.dart';
import 'package:kharis_app/features/player/presentation/widgets/playback_error_banner.dart';
import 'package:kharis_app/features/player/presentation/widgets/player_actions.dart';
import 'package:kharis_app/features/player/presentation/widgets/player_controls.dart';
import 'package:kharis_app/features/player/presentation/widgets/seek_bar.dart';
import 'package:kharis_app/features/player/presentation/widgets/youtube_web_embed.dart';
import 'package:kharis_app/shared/models/sermon.dart';
import 'package:kharis_app/shared/providers/audio_provider.dart';
import 'package:kharis_app/shared/providers/notes_provider.dart';
import 'package:kharis_app/shared/providers/sermon_provider.dart';
import 'package:kharis_app/shared/widgets/artwork_image.dart';

export 'package:kharis_app/features/player/presentation/media_mode.dart';

/// Whether [a] and [b] are variants of the same physical message (API mp3,
/// `yt_` CMS doc, bare feed entry), which share one timeline.
bool _sameMessage(Sermon a, Sermon b) =>
    a.id == b.id ||
    NoteTimelineKey.of(a).canonical == NoteTimelineKey.of(b).canonical;

/// Unified media player: one screen for every message, whatever media it
/// carries. An Audio | Video segmented toggle switches engines in place,
/// handing the playback position across so the timeline never resets:
///
/// - Audio drives [AudioPlayerService] (just_audio) — mini-player, lock-screen
///   and CarPlay semantics are untouched.
/// - Video drives a [YoutubePlayerController]; while it owns playback the
///   audio source is fully stopped (not just paused) so the engines never
///   double-play or fight over the audio session.
/// - Switching back to audio disposes the YouTube controller outright — no
///   idle iframe keeps rendering behind an audio session — and the screen is
///   kept awake only while video is actually rolling.
///
/// Both engines save their position into one shared resume point
/// ([PlaybackHistory]), so a handoff is exact even when the other engine was
/// not the last one playing. That point lives on the AUDIO timeline: an API
/// sermon's video is the whole service and its mp3 starts [Sermon.videoStart]
/// into it, so every position crossing into or out of the video engine is
/// shifted by that offset. Previous / Next walk [queue] in both modes; in
/// audio mode the screen follows the audio engine as it moves through it.
class MediaPlayerScreen extends ConsumerStatefulWidget {
  const MediaPlayerScreen({
    super.key,
    required this.sermon,
    this.mode,
    this.queue,
    this.startAt,
  });

  final Sermon sermon;

  /// The medium to open. Null derives it from the sermon via
  /// [resolveInitialMode]; audio wins when both media exist.
  final MediaMode? mode;

  /// The list playback was launched from. Null uses the audio engine's
  /// current queue (opened from the mini player).
  final List<Sermon>? queue;

  /// Where to open, on the AUDIO timeline (a shared link's `t`). Wins over
  /// the live and saved positions; null keeps the usual resume behaviour.
  final Duration? startAt;

  /// A video that has not started after this long gets the error banner.
  static const Duration videoStartTimeout = Duration(seconds: 15);

  /// Skips creating the real YouTube engine (and its wakelock) so widget tests
  /// can pump the video layout without platform views.
  @visibleForTesting
  static bool debugDisableVideoEngine = false;

  /// Stands in for the video engine's note binding while
  /// [debugDisableVideoEngine] is on, so tests can prove note capture and
  /// anchor seeks route to the video engine. Its position stream also feeds
  /// the screen's video position persistence.
  @visibleForTesting
  static NoteTimelineBinding? debugVideoNoteBinding;

  /// Stands in for the YouTube controller's value stream while
  /// [debugDisableVideoEngine] is on, so tests can drive player states and
  /// errors (the error banner, the start watchdog).
  @visibleForTesting
  static Stream<YoutubePlayerValue>? debugVideoValues;

  /// The position the most recent video engine was started at.
  @visibleForTesting
  static Duration? debugLastVideoStart;

  /// The note pins most recently handed to the video seek bar (video
  /// timeline). The bar itself needs a live YouTube bridge, which
  /// [debugDisableVideoEngine] skips, so tests read the mapping here.
  @visibleForTesting
  static List<Duration>? debugLastVideoPins;

  @override
  ConsumerState<MediaPlayerScreen> createState() => _MediaPlayerScreenState();
}

/// Why the video engine is showing its error banner.
enum _VideoProblem { notEmbeddable, unavailable, failed, stalled }

class _MediaPlayerScreenState extends ConsumerState<MediaPlayerScreen> {
  late MediaMode _mode;

  /// The message on screen. Starts as [MediaPlayerScreen.sermon]; changes
  /// when the member skips, or the audio engine advances on its own.
  late Sermon _sermon;

  /// What Previous / Next walk while video owns playback (the audio engine,
  /// which holds the queue in audio mode, is stopped then).
  List<Sermon> _queueItems = const [];

  late final PlaybackHistory _history;
  late final AudioPlayerService _audio;

  YoutubePlayerController? _youtubeController;
  final List<StreamSubscription<Object?>> _videoSubs = [];
  Timer? _videoWatchdog;
  bool _wakelockOn = false;
  bool _switching = false;

  /// Last position the video engine reported (VIDEO timeline), kept so a
  /// dispose (when the bridge is already gone) still saves where the member
  /// was. Zero once the video ended, so nothing writes the finished point back.
  Duration _videoPosition = Duration.zero;
  DateTime? _lastVideoSave;
  bool _videoRecorded = false;

  /// Where the message begins inside the running video: [Sermon.videoStart]
  /// of its audio recording. Set when the engine starts; refreshed in build
  /// once the library reveals a video-only variant's audio twin.
  Duration _videoOffset = Duration.zero;

  /// Whether the embed ever left "unstarted"; the watchdog's question.
  bool _videoStarted = false;
  _VideoProblem? _videoProblem;

  /// Position handed to the web iframe embed, which takes it as a URL
  /// parameter rather than a controller call.
  int _webStartSeconds = 0;

  @override
  void initState() {
    super.initState();
    _history = ref.read(playbackHistoryProvider);
    _audio = ref.read(audioPlayerServiceProvider);
    _sermon = widget.sermon;
    _mode = resolveInitialMode(widget.sermon, widget.mode);
    _queueItems = widget.queue ?? _audio.queue?.items ?? const <Sermon>[];
    if (_mode == MediaMode.video) {
      final startAt = widget.startAt;
      final handoff = startAt != null
          ? startAt + _offsetFor(_sermon)
          : _audioHandoff();
      // Video owns playback now: release the audio source and session
      // entirely so nothing competes in the background. The stop saves the
      // resume position, so the message picks up cleanly if audio returns.
      unawaited(_audio.stop());
      _startVideoEngine(startAt: handoff);
    } else if (widget.startAt != null) {
      // play() seeks in place when this message is already on air.
      unawaited(
        startAudioPlayback(
          ref,
          _sermon,
          startAt: widget.startAt,
          queue: _queueItems,
        ),
      );
    } else {
      _attachOrStartAudio();
    }
  }

  @override
  void dispose() {
    // Audio deliberately keeps playing on close — the mini player takes over.
    if (_mode == MediaMode.video) _saveVideoPosition();
    _disposeVideoEngine();
    super.dispose();
  }

  // ── Engine management ──────────────────────────────────────────────────────

  /// Where [sermon]'s message begins inside its video. The audio recording
  /// carries the offset (the yt_ CMS variant does not), so the twin wins.
  Duration _offsetFor(Sermon sermon) =>
      (_audioTwinOf(sermon) ?? sermon).videoStart ?? Duration.zero;

  /// The saved shared resume point (audio timeline) for [sermon]. Read
  /// through the audio recording so the end guard compares against the
  /// audio length, not a whole-service video's.
  Duration _savedAudioPoint(Sermon sermon) =>
      _history.resumePoint(_audioTwinOf(sermon) ?? sermon) ?? Duration.zero;

  /// A video-timeline position mapped onto the audio timeline.
  Duration _toAudio(Duration video) {
    final audio = video - _videoOffset;
    return audio.isNegative ? Duration.zero : audio;
  }

  /// An audio-timeline position mapped onto the running video's timeline.
  Duration _toVideo(Duration audio) => audio + _videoOffset;

  /// This message's anchored notes as seek-bar pins, on the timeline of the
  /// engine on screen. Notes live on the AUDIO timeline (one per message), so
  /// video mode shifts them by the same offset the handoff and the notes
  /// binding use. General notes carry no position and pin nothing. Watching
  /// the notes keeps the pins live as the notes sheet adds or deletes one.
  List<Duration> _notePins() {
    final notes = ref.watch(sermonNotesProvider(NoteTimelineKey.of(_sermon)));
    final isVideo = _mode == MediaMode.video;
    return [
      for (final note in notes)
        if (note.positionMs case final ms?)
          isVideo
              ? _toVideo(Duration(milliseconds: ms))
              : Duration(milliseconds: ms),
    ];
  }

  /// Where video should start (video timeline): the live audio position when
  /// audio is on this message, else the shared saved resume point — shifted
  /// to where the message sits in the video. A fresh start therefore opens
  /// at the message itself in a full-service video.
  Duration _audioHandoff() {
    final offset = _offsetFor(_sermon);
    final playing = _audio.currentSermon;
    if (playing != null && _sameMessage(playing, _sermon)) {
      final live = _audio.position;
      if (live > Duration.zero) return live + offset;
    }
    return _savedAudioPoint(_sermon) + offset;
  }

  /// Starts audio, unless the service already holds this message healthy —
  /// opened from the mini player, or pushed right after [startPlayback] kicked
  /// the load off — in which case the screen just attaches to it.
  void _attachOrStartAudio() {
    if (_audio.currentSermon?.id == _sermon.id && _audio.failure == null) {
      return;
    }
    unawaited(startAudioPlayback(ref, _sermon, queue: _queueItems));
  }

  void _startVideoEngine({required Duration startAt}) {
    MediaPlayerScreen.debugLastVideoStart = startAt;
    _videoOffset = _offsetFor(_sermon);
    _videoPosition = startAt;
    _videoRecorded = false;
    _videoStarted = false;
    _videoProblem = null;
    _lastVideoSave = null;
    if (kIsWeb) {
      // Web renders a direct iframe embed (YoutubeWebEmbed) instead of
      // youtube_player_iframe, whose platform view fails silently in release
      // builds. The embed reports nothing back, so the play is recorded now.
      _webStartSeconds = startAt.inSeconds;
      _recordVideoPlay();
      return;
    }
    if (MediaPlayerScreen.debugDisableVideoEngine) {
      _recordVideoPlay();
      final positions = MediaPlayerScreen.debugVideoNoteBinding?.position;
      if (positions != null) {
        _videoSubs.add(positions.listen(_onVideoPosition));
      }
      final values = MediaPlayerScreen.debugVideoValues;
      if (values != null) {
        _videoSubs.add(values.listen(_onVideoValue));
        _armVideoWatchdog();
      }
      return;
    }
    final controller = YoutubePlayerController.fromVideoId(
      videoId: _sermon.videoId!,
      autoPlay: true,
      startSeconds: startAt > Duration.zero
          ? startAt.inSeconds.toDouble()
          : null,
      params: const YoutubePlayerParams(
        showControls: true,
        showFullscreenButton: true,
        // Inline, not the OS fullscreen player: the shared transport row and
        // the Audio|Video toggle must stay reachable while video plays.
        playsInline: true,
      ),
    );
    _youtubeController = controller;
    _videoSubs
      ..add(controller.stream.listen(_onVideoValue))
      ..add(
        controller.videoStateStream.listen(
          (state) => _onVideoPosition(state.position),
        ),
      );
    _armVideoWatchdog();
  }

  /// An embed that never leaves "unstarted" (blocked network, region lock
  /// without an error code) would otherwise spin forever.
  void _armVideoWatchdog() {
    _videoWatchdog?.cancel();
    _videoWatchdog = Timer(MediaPlayerScreen.videoStartTimeout, () {
      if (!mounted || _videoStarted || _videoProblem != null) return;
      setState(() => _videoProblem = _VideoProblem.stalled);
    });
  }

  void _disposeVideoEngine() {
    _videoWatchdog?.cancel();
    _videoWatchdog = null;
    for (final sub in _videoSubs) {
      unawaited(sub.cancel());
    }
    _videoSubs.clear();
    final controller = _youtubeController;
    _youtubeController = null;
    if (controller != null) unawaited(controller.close());
    if (_wakelockOn) {
      _wakelockOn = false;
      unawaited(WakelockPlus.disable());
    }
  }

  void _recordVideoPlay() {
    if (_videoRecorded) return;
    _videoRecorded = true;
    // The audio recording when there is one: its snapshot carries the audio
    // length and videoStart the shared (audio-timeline) point is measured on.
    _history.recordPlay(_audioTwin() ?? _sermon);
  }

  /// Throttled (5 s) save of the video position into the shared resume point.
  void _onVideoPosition(Duration position) {
    _videoPosition = position;
    final now = DateTime.now();
    final last = _lastVideoSave;
    if (last == null || now.difference(last) >= const Duration(seconds: 5)) {
      _lastVideoSave = now;
      _history.savePosition(_sermon, _toAudio(position));
    }
  }

  void _saveVideoPosition() {
    _history.savePosition(_sermon, _toAudio(_videoPosition));
    _lastVideoSave = DateTime.now();
  }

  void _onVideoValue(YoutubePlayerValue value) {
    _syncWakelock(value);
    if (value.hasError) {
      _videoWatchdog?.cancel();
      final problem = switch (value.error) {
        YoutubeError.notEmbeddable ||
        YoutubeError.sameAsNotEmbeddable ||
        YoutubeError.sameAsNotEmbeddable2 => _VideoProblem.notEmbeddable,
        YoutubeError.videoNotFound ||
        YoutubeError.cannotFindVideo => _VideoProblem.unavailable,
        _ => _VideoProblem.failed,
      };
      if (mounted && _videoProblem != problem) {
        setState(() => _videoProblem = problem);
      }
      return;
    }
    if (value.playerState != PlayerState.unStarted &&
        value.playerState != PlayerState.unknown) {
      _videoStarted = true;
    }
    switch (value.playerState) {
      case PlayerState.playing:
        _videoWatchdog?.cancel();
        if (!_videoRecorded) {
          _recordVideoPlay();
          final speed = _audio.speed;
          if (speed != 1.0) {
            unawaited(_youtubeController?.setPlaybackRate(speed));
          }
        }
        if (_videoProblem != null && mounted) {
          setState(() => _videoProblem = null);
        }
      case PlayerState.paused:
        _videoWatchdog?.cancel();
        _saveVideoPosition();
      case PlayerState.ended:
        // Forget the last tick too: later saves (dispose, switch, skip) must
        // not write the finished point back over the cleared one.
        _videoPosition = Duration.zero;
        _history.clearPosition(_sermon);
        if (_audio.repeatOne) {
          final controller = _youtubeController;
          if (controller != null) {
            unawaited(controller.seekTo(seconds: 0, allowSeekAhead: true));
            unawaited(controller.playVideo());
          }
        }
      case PlayerState.buffering:
      case PlayerState.cued:
        _videoWatchdog?.cancel();
      case PlayerState.unStarted:
      case PlayerState.unknown:
        break;
    }
  }

  void _syncWakelock(YoutubePlayerValue value) {
    // The test seam has no wakelock plugin behind it.
    if (MediaPlayerScreen.debugDisableVideoEngine) return;
    final active =
        value.playerState == PlayerState.playing ||
        value.playerState == PlayerState.buffering;
    if (active == _wakelockOn) return;
    _wakelockOn = active;
    unawaited(WakelockPlus.toggle(enable: active));
  }

  /// The video engine's position for a handoff, on the AUDIO timeline: a
  /// live query when the bridge is up, else the last reported tick, else the
  /// shared saved point.
  Future<Duration> _videoHandoff() async {
    final controller = _youtubeController;
    if (controller != null) {
      try {
        final seconds = await controller.currentTime;
        final live = Duration(milliseconds: (seconds * 1000).round());
        if (live > Duration.zero) return _toAudio(live);
      } catch (_) {
        // Bridge gone (already closed / never loaded): fall through.
      }
    }
    if (_videoPosition > Duration.zero) return _toAudio(_videoPosition);
    return _savedAudioPoint(_sermon);
  }

  /// Switches engines in place, handing the playback position across
  /// (mapped through [Sermon.videoStart], see [MediaPlayerScreen]).
  Future<void> _switchMode(MediaMode target) async {
    if (target == _mode || _switching) return;
    if (target == MediaMode.video) {
      if (!_sermon.hasVideo) return;
      final handoff = _audioHandoff();
      // Full stop, not pause: the video session must not fight a live
      // audio source. The stop also saves the shared resume point.
      unawaited(_audio.stop());
      _startVideoEngine(startAt: handoff);
      setState(() => _mode = MediaMode.video);
      return;
    }

    final twin = _audioTwin();
    if (twin == null) return;
    // Held only across the position query: the audio load below can take up
    // to its timeout, and a Video tap meanwhile must still switch back.
    _switching = true;
    final Duration handoff;
    try {
      handoff = await _videoHandoff();
    } finally {
      _switching = false;
    }
    if (!mounted || _mode != MediaMode.video) return;
    _history.savePosition(_sermon, handoff);
    _lastVideoSave = DateTime.now();
    // Dispose, don't pause: an iframe kept alive under an audio session is
    // exactly the battery drain this screen exists to avoid.
    _disposeVideoEngine();
    _adoptIntoQueue(twin);
    setState(() {
      _sermon = twin;
      _mode = MediaMode.audio;
    });
    // The engine seeks at load time, so the member hears the handoff
    // point straight away instead of a blip from the old resume point.
    unawaited(
      startAudioPlayback(
        ref,
        twin,
        startAt: handoff > Duration.zero ? handoff : null,
        queue: _queueItems,
      ),
    );
  }

  /// The audio recording of the message on screen. See [_audioTwinOf].
  Sermon? _audioTwin() => _audioTwinOf(_sermon);

  /// The audio recording of [sermon]: itself when it carries one, else the
  /// library's mp3 of the same video.
  Sermon? _audioTwinOf(Sermon sermon) {
    if (sermon.hasAudio) return sermon;
    final videoId = sermon.videoId;
    if (videoId == null || videoId.isEmpty) return null;
    final library = ref.read(sermonsProvider).valueOrNull ?? const <Sermon>[];
    for (final candidate in library) {
      if (candidate.hasAudio && candidate.videoId == videoId) return candidate;
    }
    return null;
  }

  /// Puts [sermon] in place of any other variant of its message in
  /// [_queueItems], so a queue built around it (audio after a twin swap,
  /// video after the engine moved) finds it where the member launched it,
  /// instead of collapsing to a one-item queue.
  void _adoptIntoQueue(Sermon sermon) {
    if (_queueItems.any((s) => s.id == sermon.id)) return;
    _queueItems = [
      for (final s in _queueItems) _sameMessage(s, sermon) ? sermon : s,
    ];
  }

  // ── Queue (video mode) ─────────────────────────────────────────────────────

  /// The video-mode queue: any entry with a medium to play.
  PlaybackQueue get _videoQueue =>
      PlaybackQueue.from(_sermon, _queueItems, (s) => s.hasAudio || s.hasVideo);

  /// Opens [target] in place: video when it has one, else hands it to audio.
  void _openInVideoMode(Sermon target) {
    _saveVideoPosition();
    _disposeVideoEngine();
    if (target.hasVideo) {
      setState(() => _sermon = target);
      _startVideoEngine(startAt: _savedAudioPoint(target) + _offsetFor(target));
      return;
    }
    setState(() {
      _sermon = target;
      _mode = MediaMode.audio;
    });
    unawaited(startAudioPlayback(ref, target, queue: _queueItems));
  }

  void _restartVideo() {
    final controller = _youtubeController;
    if (controller == null) return;
    unawaited(controller.seekTo(seconds: 0, allowSeekAhead: true));
  }

  /// Follows the audio engine through its queue (Next, lock-screen skip,
  /// auto-advance), so the title, artwork and notes always match what plays.
  ///
  /// The launch list is kept while it holds the message on air: the audio
  /// queue is filtered to audio-bearing entries, and adopting it would drop
  /// the video-only ones from Previous / Next once the member is back in
  /// video. Only playback that moved outside the list replaces it.
  void _followAudioQueue(PlaybackQueue? queue) {
    if (queue == null || _mode != MediaMode.audio || !mounted) return;
    final current = queue.current;
    if (_queueItems.any((s) => _sameMessage(s, current))) {
      _adoptIntoQueue(current);
    } else {
      _queueItems = queue.items;
    }
    if (current.id != _sermon.id) {
      setState(() => _sermon = current);
    }
  }

  /// How the notes sheet binds to the video engine, or null in audio mode —
  /// the sheet's own audio-service default is already the audio engine.
  ///
  /// Video mode must pass a binding: the audio source is fully stopped here,
  /// so without one a note would be written unstamped and an anchor tap would
  /// wake audio playback underneath the video.
  ///
  /// Notes share the audio timeline (one timeline per message), so the
  /// binding stamps `video - videoStart` and seeks to `anchor + videoStart`.
  NoteTimelineBinding? _videoNoteBinding() {
    if (_mode != MediaMode.video) return null;
    final NoteTimelineBinding? engine;
    if (MediaPlayerScreen.debugDisableVideoEngine) {
      engine = MediaPlayerScreen.debugVideoNoteBinding;
    } else if (kIsWeb) {
      // The iframe embed has no JS bridge: no live position (notes are
      // written unstamped), and a seek recreates the embed at the anchor via
      // the keyed start parameter.
      engine = NoteTimelineBinding(
        seek: (target) async {
          if (!mounted) return;
          setState(() => _webStartSeconds = target.inSeconds);
        },
      );
    } else {
      final controller = _youtubeController;
      engine = controller == null
          ? null
          : NoteTimelineBinding(
              position: _videoNotePositions(controller),
              seek: (target) => controller.seekTo(
                seconds: target.inMilliseconds / 1000,
                allowSeekAhead: true,
              ),
            );
    }
    if (engine == null || _videoOffset == Duration.zero) return engine;
    final seek = engine.seek;
    return NoteTimelineBinding(
      position: engine.position?.map(_toAudio),
      seek: seek == null ? null : (target) => seek(_toVideo(target)),
    );
  }

  /// The note sheet's position source for the video engine.
  ///
  /// [YoutubePlayerController.videoStateStream] only ticks while the video is
  /// PLAYING — the iframe clears its update interval on every other state —
  /// and, as a broadcast stream, never replays to a new subscriber. A sheet
  /// opened over a PAUSED video (the natural note-taking moment) would
  /// therefore never see a position and the note would be saved unstamped.
  /// Seed the stream with a one-shot `currentTime` query so the paused case
  /// is covered, then follow the live ticks.
  Stream<Duration> _videoNotePositions(
    YoutubePlayerController controller,
  ) async* {
    try {
      final seconds = await controller.currentTime;
      yield Duration(milliseconds: (seconds * 1000).round());
    } catch (_) {
      // Bridge gone / not ready: fall through to the live stream so the
      // button degrades to the unstamped "Add a note", as before.
    }
    yield* controller.videoStateStream.map((state) => state.position);
  }

  /// The active engine's position for a share link, on the AUDIO timeline
  /// so one link means the same moment in audio and in video.
  Duration _sharePosition() {
    if (_mode == MediaMode.video) return _toAudio(_videoPosition);
    final playing = _audio.currentSermon;
    return playing != null && _sameMessage(playing, _sermon)
        ? _audio.position
        : Duration.zero;
  }

  Future<void> _openInYouTube() async {
    final url = Uri.parse(
      'https://www.youtube.com/watch?v=${_sermon.videoId}'
      '${_videoPosition.inSeconds > 0 ? '&t=${_videoPosition.inSeconds}s' : ''}',
    );
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  // ── Layout ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<PlaybackQueue?>>(
      playbackQueueProvider,
      (_, next) => _followAudioQueue(next.valueOrNull),
    );
    final isVideo = _mode == MediaMode.video;
    if (isVideo && !_sermon.hasAudio) {
      // A video-only variant finds its audio twin, and the videoStart it
      // carries, in the library: follow the library as it arrives so the
      // Audio option appears and positions map through the right offset.
      ref.watch(sermonsProvider);
      _videoOffset = _offsetFor(_sermon);
    }
    // Flat page colour: no ambient wash. _buildVideoSurface's corner mask
    // paints this same colour, so the two must stay in step.
    return Scaffold(
      backgroundColor: context.kc.bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            // The video stays pinned outside the scrollable so a swipe on
            // the picture never scrolls the page out from under playback
            // (tester feedback); everything below it still scrolls.
            if (isVideo)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
                child: _buildVideoSurface(),
              ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!isVideo) ...[
                      _buildArtwork(),
                      const SizedBox(height: 24),
                    ],
                    _buildInfoRow(),
                    const SizedBox(height: 18),
                    MediaModeToggle(
                      sermon: isVideo
                          ? _sermon.copyWith(audioUrl: _audioTwin()?.audioUrl)
                          : _sermon,
                      activeMode: _mode,
                      onSelect: (mode) => unawaited(_switchMode(mode)),
                    ),
                    const SizedBox(height: 22),
                    if (isVideo)
                      _buildVideoTransport()
                    else
                      _buildAudioTransport(),
                    const SizedBox(height: 26),
                    Container(
                      padding: const EdgeInsets.only(top: 18),
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(color: context.kc.divider),
                        ),
                      ),
                      child: PlayerActions(
                        sermon: _sermon,
                        timeline: _videoNoteBinding(),
                        asVideo: isVideo,
                        positionOf: _sharePosition,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoSurface() {
    final Widget player;
    if (kIsWeb) {
      // Keyed on the start position: a note-anchor seek bumps
      // _webStartSeconds, and the fresh key rebuilds the iframe at that
      // moment — the embed has no JS bridge to seek in place.
      player = YoutubeWebEmbed(
        key: ValueKey('yt-web-${_sermon.videoId}-$_webStartSeconds'),
        videoId: _sermon.videoId!,
        startSeconds: _webStartSeconds,
      );
    } else if (_youtubeController != null) {
      player = YoutubePlayer(
        key: ValueKey('yt-${_sermon.videoId}'),
        controller: _youtubeController!,
      );
    } else {
      // debugDisableVideoEngine: chrome renders, no engine runs.
      player = const ColoredBox(color: Colors.black);
    }
    // The embed is a NATIVE platform view (WebView). Android composites those
    // outside the Flutter layer, so neither ClipRRect nor
    // Clip.antiAliasWithSaveLayer rounds it - verified on device, the corners
    // stayed hard, which is what made the video read as "slapped on" beside
    // the rounded artwork (tester feedback).
    //
    // So the rounding is painted ON TOP instead: four corner slivers in the
    // page colour (the Scaffold's kc.bg), over the video. Flat, like
    // _buildArtwork: no glow under the frame.
    final pageColor = context.kc.bg;
    return Stack(
      children: [
        AspectRatio(aspectRatio: 16 / 9, child: player),
        // Never steal taps from the player controls underneath.
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _VideoCornerMask(
                radius: AppRadius.card,
                color: pageColor,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Audio transport: the existing just_audio streams — no extra polling.
  Widget _buildAudioTransport() {
    final position = ref.watch(positionProvider).valueOrNull ?? Duration.zero;
    final duration = ref.watch(durationProvider).valueOrNull ?? Duration.zero;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PlaybackErrorBanner(sermonId: _sermon.id),
        SeekBar(
          position: position,
          duration: duration,
          onSeek: _audio.seek,
          pins: _notePins(),
        ),
        const SizedBox(height: 18),
        const PlayerControls(),
      ],
    );
  }

  Widget _buildVideoTransport() {
    final problem = _videoProblem;
    final banner = problem == null
        ? null
        : _VideoErrorBanner(
            problem: problem,
            onListen: _audioTwin() == null
                ? null
                : () => unawaited(_switchMode(MediaMode.audio)),
            onOpenYouTube: () => unawaited(_openInYouTube()),
          );
    final pins = _notePins();
    MediaPlayerScreen.debugLastVideoPins = pins;
    final controller = _youtubeController;
    if (controller == null) {
      // Web iframe (and the test seam) have no JS bridge; the embed's native
      // YouTube controls are the transport there.
      return banner ?? const SizedBox.shrink();
    }
    final queue = _videoQueue;
    final repeatOn = ref.watch(repeatOneProvider).valueOrNull ?? false;
    final speed = ref.watch(playbackSpeedProvider).valueOrNull ?? 1.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ?banner,
        _VideoTransport(
          controller: controller,
          queue: queue,
          speed: speed,
          repeatOn: repeatOn,
          pins: pins,
          onSetSpeed: (value) {
            unawaited(controller.setPlaybackRate(value));
            // One persisted rate for both engines.
            unawaited(_audio.setSpeed(value));
          },
          onToggleRepeat: () => unawaited(_audio.setRepeatOne(!repeatOn)),
          onRestart: _restartVideo,
          onOpen: _openInVideoMode,
        ),
      ],
    );
  }

  Widget _buildHeader() {
    final series = (_sermon.series ?? _sermon.category ?? 'Now playing')
        .toUpperCase();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
      child: Row(
        children: [
          Semantics(
            button: true,
            label: 'Close player',
            excludeSemantics: true,
            child: _iconButton(
              Icons.keyboard_arrow_down_rounded,
              28,
              () => Navigator.of(context).pop(),
            ),
          ),
          Expanded(
            child: Text(
              series,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.ui(
                size: 10,
                weight: FontWeight.w600,
                letterSpacing: 1.0,
                color: context.kc.muted,
              ),
            ),
          ),
          // Share lives in the actions row below (Notes · Playlist · Share).
          // This header copy was the duplicate testers flagged (KA-013); the
          // spacer keeps the series label optically centred.
          const SizedBox(width: 44, height: 44),
        ],
      ),
    );
  }

  Widget _iconButton(IconData icon, double size, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 44,
        height: 44,
        child: Icon(icon, color: context.kc.onBg, size: size),
      ),
    );
  }

  Widget _buildArtwork() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: AspectRatio(
        aspectRatio: 1,
        child: ArtworkImage(
          url: _sermon.artworkUrl,
          gradientIndex: _sermon.artworkColor ?? 0,
          radius: AppRadius.card,
        ),
      ),
    );
  }

  Widget _buildInfoRow() {
    final speaker = _sermon.speaker;
    final extra = _sermon.category ?? _sermon.series;
    final subtitle = (extra != null && extra.isNotEmpty && extra != speaker)
        ? '$speaker · $extra'
        : speaker;

    // No extra inset: the title lines up with the mode toggle and seek bar
    // below it (it used to sit 24 px further in than everything else).
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _sermon.title,
                style: AppTypography.display(
                  size: 22,
                  weight: FontWeight.w700,
                  height: 1.08,
                  color: context.kc.onBg,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 5),
                Text(
                  subtitle,
                  style: AppTypography.ui(size: 13.5, color: context.kc.muted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 12),
        LikeButton(sermon: _sermon),
      ],
    );
  }
}

// ── Video error ───────────────────────────────────────────────────────────────

/// Why the video will not play, with the two ways forward: hear the same
/// message instead, or watch it in the YouTube app.
class _VideoErrorBanner extends StatelessWidget {
  const _VideoErrorBanner({
    required this.problem,
    required this.onOpenYouTube,
    this.onListen,
  });

  final _VideoProblem problem;
  final VoidCallback onOpenYouTube;
  final VoidCallback? onListen;

  String get _message => switch (problem) {
    _VideoProblem.notEmbeddable =>
      'This video can\u2019t be played inside the app.',
    _VideoProblem.unavailable => 'This video is no longer on YouTube.',
    _VideoProblem.failed => 'This video couldn\u2019t be played.',
    _VideoProblem.stalled => 'This video is taking too long to start.',
  };

  @override
  Widget build(BuildContext context) {
    final buttonStyle = TextButton.styleFrom(
      foregroundColor: AppColors.secondary,
      minimumSize: const Size(64, 40),
      padding: const EdgeInsets.symmetric(horizontal: 12),
    );
    final labelStyle = AppTypography.ui(
      size: 13,
      weight: FontWeight.w700,
      color: AppColors.secondary,
    );
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 4),
      decoration: BoxDecoration(
        color: AppColors.errorContainer,
        borderRadius: BorderRadius.circular(AppRadius.tile),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 20,
                color: AppColors.error,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _message,
                  style: AppTypography.ui(
                    size: 12.5,
                    height: 1.35,
                    color: AppColors.onSurface,
                  ),
                ),
              ),
            ],
          ),
          Wrap(
            alignment: WrapAlignment.end,
            children: [
              if (onListen != null)
                TextButton(
                  onPressed: onListen,
                  style: buttonStyle,
                  child: Text('Listen instead', style: labelStyle),
                ),
              TextButton(
                onPressed: onOpenYouTube,
                style: buttonStyle,
                child: Text('Open in YouTube', style: labelStyle),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Video transport ───────────────────────────────────────────────────────────

/// Seek bar + transport row bound to the YouTube engine.
///
/// Position comes from the controller's own [YoutubePlayerController
/// .videoStateStream] — the package's existing update channel, mirroring how
/// audio leans on just_audio's streams; no polling timer is added.
class _VideoTransport extends StatelessWidget {
  const _VideoTransport({
    required this.controller,
    required this.queue,
    required this.speed,
    required this.repeatOn,
    required this.pins,
    required this.onSetSpeed,
    required this.onToggleRepeat,
    required this.onRestart,
    required this.onOpen,
  });

  final YoutubePlayerController controller;
  final PlaybackQueue queue;
  final double speed;
  final bool repeatOn;

  /// Note pins, already on the video timeline.
  final List<Duration> pins;
  final ValueChanged<double> onSetSpeed;
  final VoidCallback onToggleRepeat;
  final VoidCallback onRestart;
  final ValueChanged<Sermon> onOpen;

  void _seek(Duration target) {
    unawaited(
      controller.seekTo(
        seconds: target.inMilliseconds / 1000,
        allowSeekAhead: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<YoutubePlayerValue>(
      stream: controller.stream,
      initialData: controller.value,
      builder: (context, valueSnapshot) {
        final value = valueSnapshot.data ?? controller.value;
        final state = value.playerState;
        final duration = value.metaData.duration;

        return StreamBuilder<YoutubeVideoState>(
          stream: controller.videoStateStream,
          builder: (context, stateSnapshot) {
            final position = stateSnapshot.data?.position ?? Duration.zero;
            final skips = queueSkips(
              queue: queue,
              position: position,
              onRestart: onRestart,
              onPrevious: () => onOpen(queue.previous!),
              onNext: () => onOpen(queue.next!),
            );
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SeekBar(
                  position: position,
                  duration: duration,
                  onSeek: _seek,
                  pins: pins,
                ),
                const SizedBox(height: 18),
                PlayerControls(
                  transport: TransportBinding(
                    isPlaying: state == PlayerState.playing,
                    // unStarted is NOT buffering: an embed that never starts
                    // is the watchdog's job, not an endless spinner.
                    isBuffering: state == PlayerState.buffering,
                    speed: speed,
                    repeatOn: repeatOn,
                    onPlay: controller.playVideo,
                    onPause: controller.pauseVideo,
                    onSetSpeed: onSetSpeed,
                    onToggleRepeat: onToggleRepeat,
                    onPrevious: skips.previous,
                    onNext: skips.next,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

/// Paints the four corner slivers of a rounded rectangle in [color].
///
/// Exists because Android platform views (the YouTube WebView) ignore Flutter
/// clips: the only reliable way to round the video is to draw over its corners
/// in the colour sitting behind it.
class _VideoCornerMask extends CustomPainter {
  const _VideoCornerMask({required this.radius, required this.color});

  final double radius;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rounded = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    final corners = Path.combine(
      PathOperation.difference,
      Path()..addRect(rect),
      Path()..addRRect(rounded),
    );
    canvas.drawPath(
      corners,
      Paint()
        ..color = color
        ..isAntiAlias = true,
    );
  }

  @override
  bool shouldRepaint(_VideoCornerMask old) =>
      old.radius != radius || old.color != color;
}
