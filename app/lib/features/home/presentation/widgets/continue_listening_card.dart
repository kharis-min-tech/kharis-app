import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/features/player/data/playback_history.dart';
import 'package:kharis_app/features/player/presentation/playback_launcher.dart';
import 'package:kharis_app/shared/providers/audio_provider.dart';
import 'package:kharis_app/shared/widgets/artwork_image.dart';

/// The most recently played message that was started and not finished, or
/// null. Re-evaluated on every playback transition so a pause, a finish or a
/// new play updates the card.
final continueListeningProvider = Provider.autoDispose<UnfinishedPlay?>((ref) {
  ref.watch(playerStateProvider);
  return ref.watch(playbackHistoryProvider).lastUnfinished();
});

/// "Continue listening": the last unfinished message with how far the member
/// got, and one tap to pick it up where they left off (audio or video,
/// whichever it carries; the player restores the shared resume point).
///
/// Renders nothing (not even [padding]) when there is nothing to continue,
/// so a host can place it unconditionally.
class ContinueListeningCard extends ConsumerWidget {
  const ContinueListeningCard({super.key, this.padding = EdgeInsets.zero});

  /// Space around the card, applied only when it shows.
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unfinished = ref.watch(continueListeningProvider);
    if (unfinished == null) return const SizedBox.shrink();
    final sermon = unfinished.sermon;

    // While this message is the one loaded, follow the live engine.
    final isCurrent = ref.watch(currentSermonProvider)?.id == sermon.id;
    final livePosition = isCurrent
        ? ref.watch(positionProvider).valueOrNull
        : null;
    final liveDuration = isCurrent
        ? ref.watch(durationProvider).valueOrNull
        : null;
    final position = livePosition != null && livePosition > Duration.zero
        ? livePosition
        : unfinished.position;
    final duration = liveDuration ?? unfinished.duration;
    final total = duration?.inMilliseconds ?? 0;
    final progress = total > 0
        ? (position.inMilliseconds / total).clamp(0.0, 1.0)
        : null;
    final caption = total > 0
        ? remainingLabel(duration! - position)
        : 'Paused at ${_clock(position)}';

    void resume() => unawaited(startPlayback(context, ref, sermon));

    return Padding(
      padding: padding,
      child: Semantics(
        button: true,
        label: 'Continue listening: ${sermon.title}, $caption',
        excludeSemantics: true,
        child: Material(
          color: context.kc.surface,
          borderRadius: BorderRadius.circular(AppRadius.card),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: resume,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  SizedBox(
                    width: 56,
                    height: 56,
                    child: ArtworkImage(
                      url: sermon.artworkUrl,
                      gradientIndex: sermon.artworkColor ?? 0,
                      radius: AppRadius.tile,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'CONTINUE LISTENING',
                          style: AppTypography.ui(
                            size: 10,
                            weight: FontWeight.w700,
                            letterSpacing: 1.0,
                            color: context.kc.accentInk,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          sermon.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.ui(
                            size: 14.5,
                            weight: FontWeight.w700,
                            color: context.kc.onBg,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (progress != null) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 4,
                              color: context.kc.accent,
                              backgroundColor: context.kc.divider,
                            ),
                          ),
                          const SizedBox(height: 6),
                        ],
                        Text(
                          caption,
                          style: AppTypography.ui(
                            size: 11.5,
                            color: context.kc.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: context.kc.accent,
                    ),
                    child: Icon(
                      Icons.play_arrow_rounded,
                      color: context.kc.onAccent,
                      size: 26,
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

  /// "12 min left", "1 hr 5 min left", "Less than a minute left".
  static String remainingLabel(Duration remaining) {
    final minutes = (remaining.inSeconds / 60).ceil();
    if (minutes <= 1) return 'Less than a minute left';
    if (minutes < 60) return '$minutes min left';
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    return rest == 0 ? '$hours hr left' : '$hours hr $rest min left';
  }

  static String _clock(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(h > 0 ? 2 : 1, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }
}
