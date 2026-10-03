import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/features/player/presentation/playback_launcher.dart';
import 'package:kharis_app/shared/models/sermon.dart';
import 'package:kharis_app/shared/providers/sermon_provider.dart';

/// Pale lavender series eyebrow drawn over the hero artwork. Invariant, like
/// the white title beside it: the artwork and its scrim do not follow the theme,
/// so the text on top of them must not either.
const Color _heroEyebrow = Color(0xFFE6DDFF);

/// Featured hero sermon card. Shows the latest message artwork with a
/// LIVE/Latest state pill, gold EQ mark, and a gold "Watch full" CTA.
///
/// The message is the newest YouTube upload, played as its API audio twin
/// when the archive has one: the player then offers Audio alongside Video,
/// and the speaker comes from the archive rather than a guess.
class LatestMessageCard extends ConsumerWidget {
  const LatestMessageCard({super.key});

  /// How many of the newest uploads may be skipped in favour of one that has
  /// an audio twin. Small, so a fresh service is never buried.
  static const int _twinLookahead = 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final videosAsync = ref.watch(videosProvider);
    final liveAsync = ref.watch(liveStatusProvider);

    final isLive = liveAsync.valueOrNull?.isLive == true;
    final liveStatus = liveAsync.valueOrNull;

    final videos = videosAsync.valueOrNull;
    if (videos == null || videos.isEmpty) {
      if (videosAsync.isLoading) return const _HeroSkeleton();
      return _HeroError(onRetry: () => ref.invalidate(videosProvider));
    }
    final twins = ref.watch(audioTwinByVideoIdProvider);
    final video = videos
        .take(_twinLookahead)
        .firstWhere(
          (v) => twins.containsKey(v.videoId),
          orElse: () => videos.first,
        );
    return _VideoHeroCard(
      sermon: withAudioTwin(video, twins),
      isLive: isLive,
      liveTitle: liveStatus?.title,
      liveVideoId: liveStatus?.videoId,
    );
  }
}

class _VideoHeroCard extends ConsumerWidget {
  const _VideoHeroCard({
    required this.sermon,
    required this.isLive,
    this.liveTitle,
    this.liveVideoId,
  });

  /// The hero message: its audio twin when one exists, else the upload.
  final Sermon sermon;
  final bool isLive;
  final String? liveTitle;
  final String? liveVideoId;

  void _onTap(BuildContext context, WidgetRef ref) {
    final target = isLive && liveVideoId != null
        ? Sermon(
            id: 'live',
            title: liveTitle ?? 'Live Stream',
            speaker: 'Kharis Church',
            audioUrl: '',
            videoId: liveVideoId,
            source: 'youtube',
          )
        : sermon;
    // The hero is the video feed: open in video, with Audio a tap away when
    // the message has a twin.
    startPlayback(context, ref, target, mode: MediaMode.video);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final video = sermon;
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
      onTap: () => _onTap(context, ref),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Container(
          decoration: BoxDecoration(
            // Solid brand fill under the thumbnail; shows while it loads.
            color: AppColors.primaryDeep,
            borderRadius: BorderRadius.circular(AppRadius.card),
            boxShadow: AppShadows.card,
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

              // Veil so text stays legible over the image.
              Positioned.fill(
                child: ColoredBox(color: Colors.black.withValues(alpha: 0.16)),
              ),

              // Bottom scrim
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: 140,
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

              // Gold EQ mark top-right
              const Positioned(
                top: 14,
                right: 14,
                child: Icon(
                  Icons.graphic_eq,
                  color: AppColors.secondary,
                  size: 22,
                ),
              ),

              // Bottom content: title + "Watch full" CTA
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
                          color: _heroEyebrow,
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
                      style: AppTypography.display(
                        size: 19,
                        weight: FontWeight.w700,
                      ).copyWith(color: Colors.white, height: 1.15),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        // Watch full (gold CTA)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            color: context.kc.accent,
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.play_arrow_rounded,
                                color: context.kc.onAccent,
                                size: 17,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                'Watch full',
                                style:
                                    AppTypography.ui(
                                      size: 13,
                                      weight: FontWeight.w800,
                                    ).copyWith(
                                      color: context.kc.onAccent,
                                      height: 1,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Speaker · duration
                        Expanded(
                          child: Text(
                            speakerDuration,
                            style:
                                AppTypography.ui(
                                  size: 12,
                                  weight: FontWeight.w500,
                                ).copyWith(
                                  color: Colors.white.withValues(alpha: .78),
                                  height: 1,
                                ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ],
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
          color: AppColors.primaryDeep,
          borderRadius: BorderRadius.circular(AppRadius.card),
          boxShadow: AppShadows.card,
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

/// Shown when the video feed failed or came back empty, instead of a
/// skeleton that never resolves.
class _HeroError extends StatelessWidget {
  const _HeroError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.primaryDeep,
          borderRadius: BorderRadius.circular(AppRadius.card),
          boxShadow: AppShadows.card,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.wifi_off_rounded,
              color: Color(0xCCFFFFFF),
              size: 28,
            ),
            const SizedBox(height: 10),
            Text(
              'The latest message could not be loaded.',
              textAlign: TextAlign.center,
              style: AppTypography.bodyLg.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
