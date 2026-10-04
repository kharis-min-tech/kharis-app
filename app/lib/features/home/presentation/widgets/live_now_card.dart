import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/features/player/data/playback_history.dart';
import 'package:kharis_app/features/player/presentation/playback_launcher.dart';
import 'package:kharis_app/shared/models/sermon.dart';
import 'package:kharis_app/shared/providers/sermon_provider.dart';

/// Home's "Live now" block: shown only while `config/live` says a service is
/// streaming and names the stream, so a tap always opens it. Opens the
/// unified player in video mode on the live stream.
///
/// Renders nothing (not even [padding]) otherwise, so Home can place it
/// unconditionally.
class LiveNowCard extends ConsumerWidget {
  const LiveNowCard({super.key, this.padding = EdgeInsets.zero});

  /// Space around the card, applied only when it shows.
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final live = ref.watch(liveStatusProvider).valueOrNull;
    final videoId = live?.videoId?.trim();
    if (live == null || !live.isLive || videoId == null || videoId.isEmpty) {
      return const SizedBox.shrink();
    }
    final title = live.title?.trim().isNotEmpty == true
        ? live.title!.trim()
        : 'Live Stream';

    void open() => startPlayback(
      context,
      ref,
      Sermon(
        id: PlaybackHistory.liveSermonId,
        title: title,
        speaker: 'Kharis Church',
        audioUrl: '',
        videoId: videoId,
        source: 'youtube',
      ),
      mode: MediaMode.video,
    );

    final kc = context.kc;
    return Padding(
      padding: padding,
      child: Semantics(
        button: true,
        label: 'Live now: $title. Watch',
        excludeSemantics: true,
        child: Material(
          key: const Key('home-live-now'),
          color: kc.surface,
          borderRadius: AppRadius.cardBorder,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: open,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    child: SizedBox(
                      width: 104,
                      height: 58,
                      child: ColoredBox(
                        color: AppColors.primaryDeep,
                        child: Image.network(
                          'https://img.youtube.com/vi/$videoId/hqdefault.jpg',
                          fit: BoxFit.cover,
                          gaplessPlayback: true,
                          errorBuilder: (_, _, _) => const Icon(
                            Icons.live_tv_rounded,
                            color: AppColors.onPrimary,
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const _LiveBadge(),
                        const SizedBox(height: 6),
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.ui(
                            size: 14.5,
                            weight: FontWeight.w700,
                          ).copyWith(color: kc.onBg, height: 1.25),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: kc.accent,
                      borderRadius: AppRadius.pillBorder,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.play_arrow_rounded,
                          size: 16,
                          color: kc.onAccent,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Watch',
                          style: AppTypography.ui(
                            size: 13,
                            weight: FontWeight.w800,
                          ).copyWith(color: kc.onAccent, height: 1),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "LIVE NOW" badge with a slow pulse on its dot; still when the platform
/// asks for reduced motion. Ink on the pink live colour keeps 4.5:1.
class _LiveBadge extends StatefulWidget {
  const _LiveBadge();

  @override
  State<_LiveBadge> createState() => _LiveBadgeState();
}

class _LiveBadgeState extends State<_LiveBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _ctrl
        ..stop()
        ..value = 1;
    } else if (!_ctrl.isAnimating) {
      _ctrl.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.accentPink,
        borderRadius: AppRadius.pillBorder,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FadeTransition(
            opacity: Tween<double>(
              begin: 0.45,
              end: 1,
            ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut)),
            child: Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: AppColors.ink,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 5),
          Text(
            'LIVE NOW',
            style: AppTypography.ui(
              size: 10.5,
              weight: FontWeight.w800,
              letterSpacing: 0.9,
            ).copyWith(color: AppColors.ink, height: 1),
          ),
        ],
      ),
    );
  }
}
