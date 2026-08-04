import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/features/player/presentation/media_mode.dart';
import 'package:kharis_app/features/player/presentation/playback_launcher.dart';
import 'package:kharis_app/features/player/presentation/widgets/media_mode_toggle.dart';
import 'package:kharis_app/features/player/presentation/widgets/playback_error_banner.dart';
import 'package:kharis_app/features/player/presentation/widgets/player_actions.dart';
import 'package:kharis_app/features/player/presentation/widgets/player_controls.dart';
import 'package:kharis_app/features/player/presentation/widgets/seek_bar.dart';
import 'package:kharis_app/features/player/presentation/widgets/youtube_web_embed.dart';
import 'package:kharis_app/shared/models/sermon.dart';
import 'package:kharis_app/shared/providers/audio_provider.dart';
import 'package:kharis_app/shared/widgets/artwork_image.dart';

export 'package:kharis_app/features/player/presentation/media_mode.dart';

/// Ambient wash shared by the player screens, settling into the page background
/// at the bottom so they belong to whichever theme is active. Dark mode keeps
/// the deep purple→ink gradient from the design handoff; light mode uses a soft
/// lavender that fades into the warm page background.
List<Color> playerAmbientColors(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? [const Color(0xFF3A1D6E), const Color(0xFF1A0F33), context.kc.bg]
        : [const Color(0xFFE6DEF8), const Color(0xFFF2ECF9), context.kc.bg];

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
class MediaPlayerScreen extends ConsumerStatefulWidget {
  const MediaPlayerScreen({super.key, required this.sermon, this.mode});

  final Sermon sermon;

  /// The medium to open. Null derives it from the sermon via
  /// [resolveInitialMode]; audio wins when both media exist.
  final MediaMode? mode;

  /// Skips creating the real YouTube engine (and its wakelock) so widget tests
  /// can pump the video layout without platform views.
  @visibleForTesting
  static bool debugDisableVideoEngine = false;

  @override
  ConsumerState<MediaPlayerScreen> createState() => _MediaPlayerScreenState();
}

class _MediaPlayerScreenState extends ConsumerState<MediaPlayerScreen> {
  late MediaMode _mode;
  YoutubePlayerController? _youtubeController;
  StreamSubscription<YoutubePlayerValue>? _videoValueSub;
  bool _wakelockOn = false;
  bool _liked = false;

  /// Position handed to the web iframe embed, which takes it as a URL
  /// parameter rather than a controller call.
  int _webStartSeconds = 0;

  @override
  void initState() {
    super.initState();
    _mode = resolveInitialMode(widget.sermon, widget.mode);
    if (_mode == MediaMode.video) {
      final service = ref.read(audioPlayerServiceProvider);
      final handoff = service.currentSermon?.id == widget.sermon.id
          ? service.position
          : Duration.zero;
      // Video owns playback now: release the audio source and session
      // entirely so nothing competes in the background. The stop saves the
      // resume position, so the message picks up cleanly if audio returns.
      unawaited(service.stop());
      _startVideoEngine(startAt: handoff);
    } else {
      _attachOrStartAudio();
    }
  }

  @override
  void dispose() {
    // Audio deliberately keeps playing on close — the mini player takes over.
    _disposeVideoEngine();
    super.dispose();
  }

  // ── Engine management ──────────────────────────────────────────────────────

  /// Starts audio, unless the service already holds this message healthy —
  /// opened from the mini player, or pushed right after [startPlayback] kicked
  /// the load off — in which case the screen just attaches to it.
  void _attachOrStartAudio() {
    final service = ref.read(audioPlayerServiceProvider);
    if (service.currentSermon?.id == widget.sermon.id &&
        service.failure == null) {
      return;
    }
    unawaited(startAudioPlayback(ref, widget.sermon));
  }

  void _startVideoEngine({required Duration startAt}) {
    if (kIsWeb) {
      // Web renders a direct iframe embed (YoutubeWebEmbed) instead of
      // youtube_player_iframe, whose platform view fails silently in release
      // builds.
      _webStartSeconds = startAt.inSeconds;
      return;
    }
    if (MediaPlayerScreen.debugDisableVideoEngine) return;
    final controller = YoutubePlayerController.fromVideoId(
      videoId: widget.sermon.videoId!,
      autoPlay: true,
      startSeconds: startAt > Duration.zero ? startAt.inSeconds.toDouble() : null,
      params: const YoutubePlayerParams(
        showControls: true,
        showFullscreenButton: true,
        // Inline, not the OS fullscreen player: the shared transport row and
        // the Audio|Video toggle must stay reachable while video plays.
        playsInline: true,
      ),
    );
    _youtubeController = controller;
    // youtube_player_iframe holds no wakelock of its own; keep the screen
    // awake only while video is actually rolling so audio can still sleep.
    _videoValueSub = controller.stream.listen(_syncWakelock);
  }

  void _disposeVideoEngine() {
    unawaited(_videoValueSub?.cancel());
    _videoValueSub = null;
    final controller = _youtubeController;
    _youtubeController = null;
    if (controller != null) unawaited(controller.close());
    if (_wakelockOn) {
      _wakelockOn = false;
      unawaited(WakelockPlus.disable());
    }
  }

  void _syncWakelock(YoutubePlayerValue value) {
    final active = value.playerState == PlayerState.playing ||
        value.playerState == PlayerState.buffering;
    if (active == _wakelockOn) return;
    _wakelockOn = active;
    unawaited(WakelockPlus.toggle(enable: active));
  }

  Future<Duration> _videoPosition() async {
    final controller = _youtubeController;
    if (controller == null) return Duration.zero;
    try {
      final seconds = await controller.currentTime;
      return Duration(milliseconds: (seconds * 1000).round());
    } catch (_) {
      // Bridge gone (already closed / never loaded): hand over from zero and
      // let the audio engine restore its own saved position.
      return Duration.zero;
    }
  }

  /// Switches engines in place, handing the playback position across.
  /// The same message backs both media, so the timelines map 1:1.
  Future<void> _switchMode(MediaMode target) async {
    if (target == _mode) return;
    final service = ref.read(audioPlayerServiceProvider);

    if (target == MediaMode.video) {
      if (!widget.sermon.hasVideo) return;
      final handoff = service.currentSermon?.id == widget.sermon.id
          ? service.position
          : Duration.zero;
      // Full stop, not pause: the video session must not fight a live audio
      // source. The saved position also covers a later resume from a list.
      unawaited(service.stop());
      _startVideoEngine(startAt: handoff);
      setState(() => _mode = MediaMode.video);
      return;
    }

    if (!widget.sermon.hasAudio) return;
    final handoff = await _videoPosition();
    // Dispose, don't pause: an iframe kept alive under an audio session is
    // exactly the battery drain this screen exists to avoid.
    _disposeVideoEngine();
    if (!mounted) return;
    setState(() => _mode = MediaMode.audio);
    await startAudioPlayback(ref, widget.sermon);
    if (!mounted || handoff == Duration.zero) return;
    await service.seek(handoff);
  }

  // ── Layout ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isVideo = _mode == MediaMode.video;
    return Scaffold(
      body: DecoratedBox(
        decoration: _gradient,
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      isVideo ? _buildVideoSurface() : _buildArtwork(),
                      const SizedBox(height: 24),
                      _buildInfoRow(),
                      const SizedBox(height: 18),
                      MediaModeToggle(
                        sermon: widget.sermon,
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
                        child: PlayerActions(sermon: widget.sermon),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  BoxDecoration get _gradient => BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: playerAmbientColors(context),
          stops: const [0.0, 0.44, 1.0],
        ),
      );

  Widget _buildVideoSurface() {
    final Widget player;
    if (kIsWeb) {
      player = YoutubeWebEmbed(
        videoId: widget.sermon.videoId!,
        startSeconds: _webStartSeconds,
      );
    } else if (_youtubeController != null) {
      player = YoutubePlayer(controller: _youtubeController!);
    } else {
      // debugDisableVideoEngine: chrome renders, no engine runs.
      player = const ColoredBox(color: Colors.black);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: AspectRatio(aspectRatio: 16 / 9, child: player),
    );
  }

  /// Audio transport: the existing just_audio streams — no extra polling.
  Widget _buildAudioTransport() {
    final position = ref.watch(positionProvider).valueOrNull ?? Duration.zero;
    final duration = ref.watch(durationProvider).valueOrNull ?? Duration.zero;
    final service = ref.read(audioPlayerServiceProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PlaybackErrorBanner(sermonId: widget.sermon.id),
        SeekBar(
          position: position,
          duration: duration,
          onSeek: service.seek,
        ),
        const SizedBox(height: 18),
        const PlayerControls(),
      ],
    );
  }

  Widget _buildVideoTransport() {
    final controller = _youtubeController;
    if (controller == null) {
      // Web iframe (and the test seam) have no JS bridge; the embed's native
      // YouTube controls are the transport there.
      return const SizedBox.shrink();
    }
    return _VideoTransport(controller: controller);
  }

  Widget _buildHeader() {
    final series =
        (widget.sermon.series ?? widget.sermon.category ?? 'Now playing')
            .toUpperCase();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
      child: Row(
        children: [
          _iconButton(
            Icons.keyboard_arrow_down_rounded,
            28,
            () => Navigator.of(context).pop(),
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
          _iconButton(
            Icons.ios_share_rounded,
            20,
            () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Share link copied'),
                behavior: SnackBarBehavior.floating,
                duration: Duration(milliseconds: 1700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _iconButton(IconData icon, double size, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 40,
        height: 40,
        child: Icon(icon, color: context.kc.onBg, size: size),
      ),
    );
  }

  Widget _buildArtwork() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: AspectRatio(
        aspectRatio: 1,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.card),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.5),
                blurRadius: 60,
                offset: const Offset(0, 28),
                spreadRadius: -20,
              ),
            ],
          ),
          child: ArtworkImage(
            url: widget.sermon.artworkUrl,
            gradientIndex: widget.sermon.artworkColor ?? 0,
            radius: AppRadius.card,
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow() {
    final speaker = widget.sermon.speaker;
    final extra = widget.sermon.category ?? widget.sermon.series;
    final subtitle = (extra != null && extra.isNotEmpty && extra != speaker)
        ? '$speaker · $extra'
        : speaker;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.sermon.title,
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
                    style: AppTypography.ui(
                      size: 13.5,
                      color: context.kc.muted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Semantics(
            button: true,
            label: _liked ? 'Unlike' : 'Like',
            child: GestureDetector(
              onTap: () => setState(() => _liked = !_liked),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.only(top: 2, left: 6),
                child: Icon(
                  _liked
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: context.kc.accentInk,
                  size: 24,
                ),
              ),
            ),
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
  const _VideoTransport({required this.controller});

  final YoutubePlayerController controller;

  void _seek(Duration target) {
    unawaited(controller.seekTo(
      seconds: target.inMilliseconds / 1000,
      allowSeekAhead: true,
    ));
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
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SeekBar(
                  position: position,
                  duration: duration,
                  onSeek: _seek,
                ),
                const SizedBox(height: 18),
                PlayerControls(
                  transport: TransportBinding(
                    isPlaying: state == PlayerState.playing,
                    isBuffering: state == PlayerState.buffering ||
                        state == PlayerState.unStarted,
                    position: position,
                    duration: duration,
                    onPlay: controller.playVideo,
                    onPause: controller.pauseVideo,
                    onSeek: _seek,
                    onSetSpeed: controller.setPlaybackRate,
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
