import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/models/sermon.dart';
import '../../../../shared/providers/audio_provider.dart';

/// Unified media player for audio and YouTube video content.
/// Design follows Spotify-like full-screen player from MOBBIN references.
class MediaPlayerScreen extends ConsumerStatefulWidget {
  const MediaPlayerScreen({super.key, required this.sermon});

  final Sermon sermon;

  @override
  ConsumerState<MediaPlayerScreen> createState() => _MediaPlayerScreenState();
}

class _MediaPlayerScreenState extends ConsumerState<MediaPlayerScreen> {
  YoutubePlayerController? _youtubeController;
  double _playbackSpeed = 1.0;

  bool get _isVideo => widget.sermon.isYouTubeVideo;

  @override
  void initState() {
    super.initState();
    if (_isVideo && widget.sermon.videoId != null) {
      _youtubeController = YoutubePlayerController.fromVideoId(
        videoId: widget.sermon.videoId!,
        autoPlay: true,
        params: const YoutubePlayerParams(
          showControls: true,
          showFullscreenButton: true,
          playsInline: false,
        ),
      );
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
      backgroundColor: AppColors.surfaceDark,
      body: _isVideo ? _buildVideoPlayer() : _buildAudioPlayer(),
    );
  }

  Widget _buildVideoPlayer() {
    return SafeArea(
      child: Column(
        children: [
          // Header with back button
          _buildHeader(),
          // Video player
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: YoutubePlayer(
                  controller: _youtubeController!,
                ),
              ),
            ),
          ),
          // Video info
          _buildMediaInfo(),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  Widget _buildAudioPlayer() {
    final position = ref.watch(positionProvider).valueOrNull ?? Duration.zero;
    final duration = ref.watch(durationProvider).valueOrNull ?? Duration.zero;
    final playerState = ref.watch(playerStateProvider).valueOrNull;
    final isPlaying = playerState?.playing ?? false;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Blurred artwork background
        if (widget.sermon.artworkUrl != null)
          ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
            child: Image.network(
              widget.sermon.artworkUrl!,
              fit: BoxFit.cover,
              color: Colors.black.withValues(alpha: 0.5),
              colorBlendMode: BlendMode.darken,
            ),
          ),
        // Dark overlay
        Container(color: Colors.black.withValues(alpha: 0.6)),
        // Content
        SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              const Spacer(),
              // Large artwork
              _buildArtwork(),
              const SizedBox(height: AppSpacing.xl),
              // Title and speaker
              _buildMediaInfo(),
              const Spacer(),
              // Seek bar
              _buildSeekBar(position, duration),
              const SizedBox(height: AppSpacing.lg),
              // Controls
              _buildAudioControls(isPlaying),
              const SizedBox(height: AppSpacing.md),
              // Speed selector
              _buildSpeedSelector(),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 32),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.share_outlined, color: Colors.white),
            onPressed: () {
              // TODO: Share functionality
            },
          ),
        ],
      ),
    );
  }

  Widget _buildArtwork() {
    return Container(
      width: 280,
      height: 280,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: widget.sermon.artworkUrl != null
          ? Image.network(
              widget.sermon.artworkUrl!,
              fit: BoxFit.cover,
            )
          : Container(
              color: AppColors.surfaceElevated,
              child: const Icon(Icons.music_note, size: 80, color: Colors.white54),
            ),
    );
  }

  Widget _buildMediaInfo() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Column(
        children: [
          Text(
            widget.sermon.title,
            style: GoogleFonts.mavenPro(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            widget.sermon.speaker,
            style: GoogleFonts.dmSans(
              fontSize: 16,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeekBar(Duration position, Duration duration) {
    final progress = duration.inMilliseconds > 0
        ? position.inMilliseconds / duration.inMilliseconds
        : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Column(
        children: [
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
              activeTrackColor: AppColors.accent,
              inactiveTrackColor: Colors.white24,
              thumbColor: Colors.white,
              overlayColor: AppColors.accent.withValues(alpha: 0.2),
            ),
            child: Slider(
              value: progress.clamp(0.0, 1.0),
              onChanged: (value) {
                final newPosition = Duration(
                  milliseconds: (value * duration.inMilliseconds).round(),
                );
                ref.read(audioPlayerServiceProvider).seek(newPosition);
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDuration(position),
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
                Text(
                  _formatDuration(duration),
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAudioControls(bool isPlaying) {
    final service = ref.read(audioPlayerServiceProvider);
    final position = ref.watch(positionProvider).valueOrNull ?? Duration.zero;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Skip back 15s
        IconButton(
          iconSize: 40,
          icon: const Icon(Icons.replay_10, color: Colors.white),
          onPressed: () {
            final newPos = position - const Duration(seconds: 15);
            service.seek(newPos < Duration.zero ? Duration.zero : newPos);
          },
        ),
        const SizedBox(width: AppSpacing.lg),
        // Play/Pause
        Container(
          width: 72,
          height: 72,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            iconSize: 36,
            icon: Icon(
              isPlaying ? Icons.pause : Icons.play_arrow,
              color: Colors.black,
            ),
            onPressed: () {
              if (isPlaying) {
                service.pause();
              } else {
                service.resume();
              }
            },
          ),
        ),
        const SizedBox(width: AppSpacing.lg),
        // Skip forward 15s
        IconButton(
          iconSize: 40,
          icon: const Icon(Icons.forward_10, color: Colors.white),
          onPressed: () {
            final duration = ref.read(durationProvider).valueOrNull ?? Duration.zero;
            final newPos = position + const Duration(seconds: 15);
            service.seek(newPos > duration ? duration : newPos);
          },
        ),
      ],
    );
  }

  Widget _buildSpeedSelector() {
    return GestureDetector(
      onTap: _cycleSpeed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white24),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          '${_playbackSpeed}x',
          style: GoogleFonts.dmSans(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  void _cycleSpeed() {
    const speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];
    final currentIndex = speeds.indexOf(_playbackSpeed);
    final nextIndex = (currentIndex + 1) % speeds.length;
    setState(() {
      _playbackSpeed = speeds[nextIndex];
    });
    ref.read(audioPlayerServiceProvider).setSpeed(_playbackSpeed);
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}
