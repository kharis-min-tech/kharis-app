import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kharis_app/features/player/data/playback_history.dart';
import 'package:kharis_app/features/player/presentation/playback_launcher.dart';
import 'package:kharis_app/shared/models/sermon.dart';
import 'package:kharis_app/shared/providers/sermon_provider.dart';
import 'package:kharis_app/ui/components/components.dart';

/// "Live" on Home: shown only while the Studio's live stream is on, with
/// the stream's picture and title; Watch (or a tap anywhere) opens it in
/// the video player. Renders nothing, [padding] included, otherwise.
class LiveNowCard extends ConsumerWidget {
  const LiveNowCard({super.key, this.padding = EdgeInsets.zero});

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
        : 'Live stream';

    void open() => unawaited(
      startPlayback(
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
      ),
    );

    final k = context.k;
    return Padding(
      padding: padding,
      child: KCard(
        key: const Key('home-live-now'),
        padding: const EdgeInsets.all(KSpace.xl),
        onTap: open,
        child: Row(
          children: [
            KThumbnail(
              size: KSize.artwork,
              image: CachedNetworkImageProvider(
                'https://img.youtube.com/vi/$videoId/hqdefault.jpg',
              ),
            ),
            const SizedBox(width: KSpace.xl),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const KBadge('Live now', variant: KBadgeVariant.live),
                  const SizedBox(height: KSpace.sm),
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: KharisText.itemTitle.copyWith(color: k.text),
                  ),
                ],
              ),
            ),
            const SizedBox(width: KSpace.md),
            KButton(
              key: const Key('home-live-watch'),
              label: 'Watch',
              variant: KButtonVariant.tonal,
              onPressed: open,
            ),
          ],
        ),
      ),
    );
  }
}
