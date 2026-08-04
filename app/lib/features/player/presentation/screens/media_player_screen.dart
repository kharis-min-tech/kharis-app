import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/features/player/presentation/widgets/youtube_web_embed.dart';
import 'package:kharis_app/features/player/presentation/playback_launcher.dart';
import 'package:kharis_app/features/player/presentation/widgets/playback_error_banner.dart';
import 'package:kharis_app/features/player/presentation/widgets/player_actions.dart';
import 'package:kharis_app/features/player/presentation/widgets/player_controls.dart';
import 'package:kharis_app/features/player/presentation/widgets/seek_bar.dart';
import 'package:kharis_app/shared/models/sermon.dart';
import 'package:kharis_app/shared/providers/audio_provider.dart';
import 'package:kharis_app/shared/widgets/artwork_image.dart';

/// Ambient wash shared by the player screens, settling into the page background
/// at the bottom so they belong to whichever theme is active. Dark mode keeps
/// the deep purple→ink gradient from the design handoff; light mode uses a soft
/// lavender that fades into the warm page background.
List<Color> playerAmbientColors(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? [const Color(0xFF3A1D6E), const Color(0xFF1A0F33), context.kc.bg]
        : [const Color(0xFFE6DEF8), const Color(0xFFF2ECF9), context.kc.bg];

/// Which medium [MediaPlayerScreen] presents.
enum MediaMode { audio, video }

/// Unified media player for audio and YouTube video content. Audio playback
/// mirrors the full Now Playing screen (ambient wash, gold transport, waveform
/// scrubber); video hosts the YouTube player under the same chrome.
class MediaPlayerScreen extends ConsumerStatefulWidget {
  const MediaPlayerScreen({super.key, required this.sermon, this.mode});

  final Sermon sermon;

  /// The medium to open. Null derives it from the sermon, and audio always
  /// wins: most sermons carry both an mp3 and a YouTube link, and a member who
  /// asked for a message must never be handed a video instead. Pass
  /// [MediaMode.video] to open the video deliberately.
  final MediaMode? mode;

  @override
  ConsumerState<MediaPlayerScreen> createState() => _MediaPlayerScreenState();
}

class _MediaPlayerScreenState extends ConsumerState<MediaPlayerScreen> {
  YoutubePlayerController? _youtubeController;
  bool _liked = false;

  /// Resolved once, in [initState], so the screen can never flip medium under
  /// the member mid-session.
  late final bool _isVideo = _resolveMode() == MediaMode.video;

  MediaMode _resolveMode() {
    final requested = widget.mode;
    if (requested == MediaMode.video && widget.sermon.hasVideo) {
      return MediaMode.video;
    }
    if (requested == MediaMode.audio && widget.sermon.hasAudio) {
      return MediaMode.audio;
    }
    // No usable request: play what the sermon actually has, audio first.
    return widget.sermon.hasAudio ? MediaMode.audio : MediaMode.video;
  }

  @override
  void initState() {
    super.initState();
    if (_isVideo) {
      // Only one audio source at a time: pause any playing sermon audio so it
      // does not clash with the YouTube player.
      ref.read(audioPlayerServiceProvider).pause();
      // On web we render a direct iframe embed (YoutubeWebEmbed) instead of
      // youtube_player_iframe, whose platform view fails silently in
      // release builds. Only create the controller on mobile/desktop.
      if (!kIsWeb) {
        _youtubeController = YoutubePlayerController.fromVideoId(
          videoId: widget.sermon.videoId!,
          autoPlay: true,
          params: const YoutubePlayerParams(
            showControls: true,
            showFullscreenButton: true,
            playsInline: false,
          ),
        );
      }
    } else {
      // Start audio playback; a failed load surfaces in the banner below.
      startPlayback(ref, widget.sermon);
    }
  }

  @override
  void dispose() {
    _youtubeController?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isVideo ? _buildVideoPlayer() : _buildAudioPlayer(),
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

  Widget _buildVideoPlayer() {
    return DecoratedBox(
      decoration: _gradient,
      child: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: kIsWeb
                      ? YoutubeWebEmbed(videoId: widget.sermon.videoId!)
                      : YoutubePlayer(controller: _youtubeController!),
                ),
              ),
            ),
            _buildInfoRow(),
            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }

  Widget _buildAudioPlayer() {
    final position = ref.watch(positionProvider).valueOrNull ?? Duration.zero;
    final duration = ref.watch(durationProvider).valueOrNull ?? Duration.zero;
    final service = ref.read(audioPlayerServiceProvider);

    return DecoratedBox(
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
                    _buildArtwork(),
                    const SizedBox(height: 24),
                    _buildInfoRow(),
                    const SizedBox(height: 22),
                    PlaybackErrorBanner(sermonId: widget.sermon.id),
                    SeekBar(
                      position: position,
                      duration: duration,
                      onSeek: (d) => service.seek(d),
                    ),
                    const SizedBox(height: 18),
                    const PlayerControls(),
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
    );
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
