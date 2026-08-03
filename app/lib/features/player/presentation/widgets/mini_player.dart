import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/shared/providers/audio_provider.dart';
import 'package:kharis_app/shared/widgets/artwork_image.dart';

/// Persistent mini player shown above the tab bar when a sermon is loaded.
///
/// A 58-px `context.kc.surface` bar (radius [AppRadius.tile], lifted by
/// [AppShadows.miniPlayer]) with the artwork thumbnail, title/speaker, and a
/// play/pause button, plus a gold progress line pinned to the bottom edge.
/// Tapping the body pushes `/player`; the play/pause button is isolated.
/// Hidden entirely when [currentSermonProvider] is null.
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
        height: 58,
        margin: const EdgeInsets.fromLTRB(10, 0, 10, 6),
        decoration: BoxDecoration(
          color: context.kc.surface,
          borderRadius: BorderRadius.circular(AppRadius.tile),
          boxShadow: AppShadows.miniPlayer,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.tile),
          child: Stack(
            children: [
              // Content row: tap navigates to the full player.
              GestureDetector(
                onTap: () => context.push('/player'),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 6, 8),
                  child: Row(
                    children: [
                      // Album artwork.
                      SizedBox(
                        width: 42,
                        height: 42,
                        child: ArtworkImage(
                          url: sermon.artworkUrl,
                          gradientIndex: sermon.artworkColor ?? 0,
                          radius: 9,
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Title and speaker.
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              sermon.title,
                              style: AppTypography.ui(
                                size: 12.5,
                                weight: FontWeight.w600,
                                height: 1.25,
                                color: context.kc.onBg,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              sermon.speaker,
                              style: AppTypography.ui(
                                size: 11,
                                height: 1.25,
                                color: context.kc.muted,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),

                      // Play / pause icon button (does not navigate).
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
                              color: context.kc.onBg,
                              size: 26,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Gold progress line pinned to the bottom edge.
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _ProgressLine(progress: progress),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Progress line (height 3, gold fill) ──────────────────────────────────────

class _ProgressLine extends StatelessWidget {
  const _ProgressLine({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 3,
      child: Stack(
        children: [
          Container(
            width: double.infinity,
            height: 3,
            color: context.kc.divider,
          ),
          FractionallySizedBox(
            widthFactor: progress.clamp(0.0, 1.0),
            alignment: Alignment.centerLeft,
            child: Container(
              height: 3,
              color: context.kc.accent,
            ),
          ),
        ],
      ),
    );
  }
}
