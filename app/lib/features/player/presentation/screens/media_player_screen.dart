import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import 'package:kharis_app/core/theme/app_colors.dart';
import 'package:kharis_app/core/theme/app_radius.dart';
import 'package:kharis_app/core/theme/app_typography.dart';
import 'package:kharis_app/features/player/presentation/widgets/youtube_web_embed.dart';
import 'package:kharis_app/features/player/presentation/widgets/player_actions.dart';
import 'package:kharis_app/features/player/presentation/widgets/player_controls.dart';
import 'package:kharis_app/features/player/presentation/widgets/seek_bar.dart';
import 'package:kharis_app/shared/models/sermon.dart';
import 'package:kharis_app/shared/providers/audio_provider.dart';
import 'package:kharis_app/shared/widgets/artwork_image.dart';

/// Unified media player for audio and YouTube video content — dark
/// design-handoff (v3). Audio playback mirrors the full Now Playing screen
/// (purple→ink wash, gold transport, waveform scrubber); video hosts the
/// YouTube player under the same dark chrome.
class MediaPlayerScreen extends ConsumerStatefulWidget {
  const MediaPlayerScreen({super.key, required this.sermon});

  final Sermon sermon;

  @override
  ConsumerState<MediaPlayerScreen> createState() => _MediaPlayerScreenState();
}

class _MediaPlayerScreenState extends ConsumerState<MediaPlayerScreen> {
  YoutubePlayerController? _youtubeController;
  bool _liked = false;

  bool get _isVideo => widget.sermon.isYouTubeVideo;

  @override
  void initState() {
    super.initState();
    if (_isVideo && widget.sermon.videoId != null) {
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
      // Start audio playback
      ref.read(audioPlayerServiceProvider).play(widget.sermon);
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
      backgroundColor: AppColors.ink,
      body: _isVideo ? _buildVideoPlayer() : _buildAudioPlayer(),
    );
  }

  BoxDecoration get _gradient => const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF3A1D6E), Color(0xFF1A0F33), AppColors.ink],
          stops: [0.0, 0.44, 1.0],
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
                      decoration: const BoxDecoration(
                        border: Border(top: BorderSide(color: Color(0x17FFFFFF))),
                      ),
                      child: const PlayerActions(),
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
                color: AppColors.darkMuted2,
              ),
            ),
          ),
          _iconButton(
            Icons.ios_share_rounded,
            20,
            () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Share link copied'),
                backgroundColor: AppColors.darkSurface,
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
        child: Icon(icon, color: Colors.white, size: size),
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
                    color: Colors.white,
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
                      color: AppColors.darkMuted2,
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
                  color: AppColors.gold,
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
