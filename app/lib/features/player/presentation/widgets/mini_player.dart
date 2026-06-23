import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:kharis_app/core/theme/app_colors.dart';
import 'package:kharis_app/core/theme/app_radius.dart';
import 'package:kharis_app/core/theme/app_typography.dart';
import 'package:kharis_app/shared/providers/audio_provider.dart';
import 'package:kharis_app/shared/widgets/artwork_image.dart';

/// Persistent mini player shown above the tab bar when a sermon is loaded.
///
/// Layout (bottom up): 2-px progress line + content row (art | title/speaker
/// | play/pause icon). AppColors.surfaceDark card with a subtle border and
/// shadow. Tap the body to push /player; the play/pause button is isolated.
/// Hidden entirely when currentSermonProvider is null.
class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sermon = ref.watch(currentSermonProvider);
    if (sermon == null) return const SizedBox.shrink();

    final playerState = ref.watch(playerStateProvider).valueOrNull;
    final isPlaying = playerState?.playing ?? false;
    final position =
        ref.watch(positionProvider).valueOrNull ?? Duration.zero;
    final rawDuration =
        ref.watch(durationProvider).valueOrNull ?? Duration.zero;
    final service = ref.read(audioPlayerServiceProvider);

    final progress = rawDuration.inMilliseconds > 0
        ? (position.inMilliseconds / rawDuration.inMilliseconds)
            .clamp(0.0, 1.0)
        : 0.0;

    return Semantics(
      label: 'Now playing: ${sermon.title} by ${sermon.speaker}',
      child: Container(
        margin: const EdgeInsets.fromLTRB(10, 0, 10, 6),
        decoration: BoxDecoration(
          color: AppColors.surfaceDark,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.32),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Content row: tap navigates to full player
              GestureDetector(
                onTap: () => context.push('/player'),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                  child: Row(
                    children: [
                      // Album artwork
                      SizedBox(
                        width: 44,
                        height: 44,
                        child: ArtworkImage(
                          url: sermon.artworkUrl,
                          gradientIndex: sermon.artworkColor ?? 0,
                          radius: 8,
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Title and speaker
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              sermon.title,
                              style: AppTypography.bodySm.copyWith(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.heading,
                                height: 1.25,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              sermon.speaker,
                              style: AppTypography.bodySm.copyWith(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w400,
                                color: AppColors.onSurfaceVariant,
                                height: 1.25,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),

                      // Play / pause icon button (does not navigate)
                      Semantics(
                        button: true,
                        label: isPlaying ? 'Pause' : 'Play',
                        excludeSemantics: true,
                        child: GestureDetector(
                          onTap: () =>
                              isPlaying ? service.pause() : service.resume(),
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Icon(
                              isPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              color: AppColors.heading,
                              size: 28,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Progress line pinned to the bottom
              _ProgressLine(progress: progress),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Progress line (height 2, AppColors.heading fill) ─────────────────────────

class _ProgressLine extends StatelessWidget {
  const _ProgressLine({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 2,
      child: Stack(
        children: [
          // Track background
          Container(
            width: double.infinity,
            height: 2,
            color: Colors.white.withValues(alpha: 0.1),
          ),
          // Fill
          FractionallySizedBox(
            widthFactor: progress.clamp(0.0, 1.0),
            alignment: Alignment.centerLeft,
            child: Container(
              height: 2,
              color: AppColors.heading,
            ),
          ),
        ],
      ),
    );
  }
}
