import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/features/player/presentation/screens/media_player_screen.dart';
import 'package:kharis_app/shared/models/sermon.dart';
import 'package:kharis_app/shared/providers/sermon_provider.dart';

/// Hero card: "Latest from Kharis" YouTube video in dark purple 16:9 card.
/// When live, shows a "LIVE" pill instead of the "Latest" badge.
class LatestMessageCard extends ConsumerWidget {
  const LatestMessageCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final videosAsync = ref.watch(videosProvider);
    final liveAsync = ref.watch(liveStatusProvider);

    final isLive = liveAsync.valueOrNull?.isLive == true;
    final liveStatus = liveAsync.valueOrNull;

    return videosAsync.when(
      loading: () => const _HeroSkeleton(),
      error: (_, _) => const _HeroSkeleton(),
      data: (videos) {
        if (videos.isEmpty) return const _HeroSkeleton();
        final video = videos.first;
        return _VideoHeroCard(
          video: video,
          isLive: isLive,
          liveTitle: liveStatus?.title,
          liveVideoId: liveStatus?.videoId,
        );
      },
    );
  }
}

class _VideoHeroCard extends StatelessWidget {
  const _VideoHeroCard({
    required this.video,
    required this.isLive,
    this.liveTitle,
    this.liveVideoId,
  });

  final Sermon video;
  final bool isLive;
  final String? liveTitle;
  final String? liveVideoId;

  void _onTap(BuildContext context) {
    final targetSermon = isLive && liveVideoId != null
        ? Sermon(
            id: 'live',
            title: liveTitle ?? 'Live Stream',
            speaker: 'Kharis Church',
            audioUrl: '',
            videoId: liveVideoId,
            source: 'youtube',
          )
        : video;

    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) => MediaPlayerScreen(sermon: targetSermon),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = isLive ? (liveTitle ?? 'Live Stream') : video.title;
    final speaker = video.speaker;
    final duration = video.duration != null ? video.formattedDuration : '';
    final speakerDuration = duration.isNotEmpty
        ? '$speaker  \u00b7  $duration'
        : speaker;

    // Real YouTube thumbnail (maxres, falling back to hq) fills the frame.
    final vid = isLive ? liveVideoId : video.videoId;
    final thumbUrl = (vid != null && vid.isNotEmpty)
        ? 'https://img.youtube.com/vi/$vid/maxresdefault.jpg'
        : video.artworkUrl;
    final fallbackThumb = (vid != null && vid.isNotEmpty)
        ? 'https://img.youtube.com/vi/$vid/hqdefault.jpg'
        : null;

    return GestureDetector(
      onTap: () => _onTap(context),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0x14000000), width: 1),
            boxShadow: const [
              BoxShadow(
                color: Color(0x44000000),
                blurRadius: 24,
                offset: Offset(0, 8),
              ),
            ],
            gradient: const LinearGradient(
              begin: Alignment(-.8, -1),
              end: Alignment(.6, 1),
              colors: [Color(0xFF4A1D8F), Color(0xFF23104A), Color(0xFF0C0A12)],
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Real video thumbnail, cover-fit to the 16:9 frame.
              if (thumbUrl != null)
                Positioned.fill(
                  child: Image.network(
                    thumbUrl,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                    errorBuilder: (_, _, _) => fallbackThumb != null
                        ? Image.network(
                            fallbackThumb,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const SizedBox.shrink(),
                          )
                        : const SizedBox.shrink(),
                  ),
                ),

              // Veil so the play button and text stay legible over the image.
              Positioned.fill(
                child: ColoredBox(color: Colors.black.withValues(alpha: 0.16)),
              ),

              // Bottom scrim
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: 130,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: .82),
                      ],
                    ),
                  ),
                ),
              ),

              // "Latest" or "LIVE" badge top-left
              Positioned(
                top: 14,
                left: 14,
                child: isLive
                    ? _LivePill()
                    : Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.accentPink,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: Text(
                          'Latest',
                          style: AppTypography.labelMd.copyWith(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 0.4,
                            height: 1,
                          ),
                        ),
                      ),
              ),

              // Center play button
              Center(
                child: Container(
                  width: 62,
                  height: 62,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: Color(0xFF32363D),
                    size: 32,
                  ),
                ),
              ),

              // Bottom text
              Positioned(
                bottom: 14,
                left: 16,
                right: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (video.series != null && video.series!.isNotEmpty) ...[
                      Text(
                        video.series!.toUpperCase(),
                        style: AppTypography.labelMd.copyWith(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                          letterSpacing: 1.1,
                          height: 1,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 5),
                    ],
                    Text(
                      title,
                      style: AppTypography.titleMd.copyWith(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.18,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 5),
                    Text(
                      speakerDuration,
                      style: AppTypography.labelMd.copyWith(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFFC9C2CE),
                        letterSpacing: 0,
                        height: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pulsing "LIVE" badge shown when a stream is active.
class _LivePill extends StatefulWidget {
  @override
  State<_LivePill> createState() => _LivePillState();
}

class _LivePillState extends State<_LivePill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _fade = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.redAccent,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FadeTransition(
            opacity: _fade,
            child: Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 5),
          Text(
            'LIVE',
            style: AppTypography.labelMd.copyWith(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: 1.0,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroSkeleton extends StatelessWidget {
  const _HeroSkeleton();

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF4A1D8F), Color(0xFF0C0A12)],
          ),
        ),
        child: const Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Color(0x55FFFFFF),
            ),
          ),
        ),
      ),
    );
  }
}
