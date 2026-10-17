import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/features/player/presentation/playback_launcher.dart';
import 'package:kharis_app/shared/providers/sermon_provider.dart';

/// Today's Daily Message from the Content Studio: the sermon it names, with
/// the Studio's note beneath. One tap plays it.
///
/// Renders nothing (not even [padding]) when there is no message for today
/// or the app cannot find its sermon, so a host can place it
/// unconditionally.
class DailyMessageCard extends ConsumerWidget {
  const DailyMessageCard({super.key, this.padding = EdgeInsets.zero});

  /// Space around the card, applied only when it shows.
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final message = ref.watch(dailyMessageProvider).valueOrNull;
    if (message == null) return const SizedBox.shrink();
    final sermon = ref.watch(sermonByIdProvider(message.sermonId)).valueOrNull;
    if (sermon == null) return const SizedBox.shrink();
    final kc = context.kc;
    final speaker = sermon.speaker.trim();

    return Padding(
      padding: padding,
      child: Semantics(
        button: true,
        label: 'Daily message: ${sermon.title}. Play',
        excludeSemantics: true,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: AppRadius.cardBorder,
            boxShadow: AppShadows.card,
          ),
          child: Material(
            key: const Key('home-daily-message'),
            color: kc.surface,
            borderRadius: AppRadius.cardBorder,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => unawaited(startPlayback(context, ref, sermon)),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DAILY MESSAGE',
                      style: AppTypography.ui(
                        size: 10.5,
                        weight: FontWeight.w800,
                        letterSpacing: 1.1,
                      ).copyWith(color: kc.muted, height: 1),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                sermon.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.display(
                                  size: 18,
                                  weight: FontWeight.w700,
                                ).copyWith(color: kc.onBg, height: 1.2),
                              ),
                              if (speaker.isNotEmpty) ...[
                                const SizedBox(height: 3),
                                Text(
                                  speaker,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.ui(
                                    size: 13,
                                  ).copyWith(color: kc.muted, height: 1.3),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          Icons.play_circle_outline_rounded,
                          color: kc.onChip,
                          size: 28,
                        ),
                      ],
                    ),
                    if (message.note.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        message.note,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.ui(
                          size: 14,
                        ).copyWith(color: kc.muted, height: 1.45),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
