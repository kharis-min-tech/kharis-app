import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kharis_app/features/player/presentation/playback_launcher.dart';
import 'package:kharis_app/shared/providers/sermon_provider.dart';
import 'package:kharis_app/ui/components/components.dart';

/// The Daily Message the Studio picked for today: a compact row with the
/// message's artwork, title, speaker and the Studio's note; a tap plays it.
/// Renders nothing, [padding] included, on a day without one or until its
/// message is found.
class DailyMessageCard extends ConsumerWidget {
  const DailyMessageCard({super.key, this.padding = EdgeInsets.zero});

  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final message = ref.watch(dailyMessageProvider).valueOrNull;
    if (message == null) return const SizedBox.shrink();
    final sermon = ref.watch(sermonByIdProvider(message.sermonId)).valueOrNull;
    if (sermon == null) return const SizedBox.shrink();
    final k = context.k;
    final speaker = sermon.speaker.trim();
    final note = message.note.trim();
    final artwork = sermon.artworkUrl?.trim();

    return Padding(
      padding: padding,
      child: KCard(
        key: const Key('home-daily-message'),
        padding: const EdgeInsets.all(KSpace.xl),
        semanticLabel: 'Daily message: ${sermon.title}. Play',
        onTap: () => unawaited(startPlayback(context, ref, sermon)),
        child: Row(
          children: [
            KThumbnail(
              size: KSize.artwork,
              image: artwork == null || artwork.isEmpty
                  ? null
                  : CachedNetworkImageProvider(artwork),
            ),
            const SizedBox(width: KSpace.xl),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const KOverline('Daily message'),
                  const SizedBox(height: KSpace.xs),
                  Text(
                    sermon.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: KharisText.itemTitle.copyWith(color: k.text),
                  ),
                  if (speaker.isNotEmpty)
                    Text(
                      speaker,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: KharisText.caption.copyWith(color: k.muted),
                    ),
                  if (note.isNotEmpty) ...[
                    const SizedBox(height: KSpace.xs),
                    Text(
                      note,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: KharisText.meta.copyWith(color: k.muted),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: KSpace.md),
            KIcon(KIcons.playCircle, color: k.muted),
          ],
        ),
      ),
    );
  }
}
