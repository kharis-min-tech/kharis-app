import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/core/utils/media_url.dart';
import 'package:kharis_app/features/player/presentation/playback_launcher.dart';
import 'package:kharis_app/shared/models/sermon.dart';
import 'package:kharis_app/shared/providers/sermon_provider.dart';

/// How many of the newest messages Home shows; the Messages tab has the rest.
const int kHomeLatestMessagesCount = 8;

const double _kArtSize = 156;

/// Home's row of the newest messages: large square artwork, the title and
/// the speaker beneath, each starting playback on tap. Renders nothing until
/// there are messages to show.
class LatestMessagesRow extends ConsumerWidget {
  const LatestMessagesRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sermons = ref
        .watch(latestSermonsProvider)
        .take(kHomeLatestMessagesCount)
        .toList();
    if (sermons.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      key: const Key('home-latest-messages'),
      // Artwork plus two title lines and the speaker, at the member's text
      // size.
      height: _kArtSize + MediaQuery.textScalerOf(context).scale(66),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: sermons.length,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
        itemBuilder: (context, i) => _MessageTile(sermon: sermons[i]),
      ),
    );
  }
}

class _MessageTile extends ConsumerWidget {
  const _MessageTile({required this.sermon});

  final Sermon sermon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kc = context.kc;
    final url = usableMediaUrl(sermon.artworkUrl);
    final fallback = ColoredBox(
      color: kc.chipBg,
      child: Center(
        child: Icon(Icons.headphones_rounded, size: 36, color: kc.onChip),
      ),
    );
    return Semantics(
      button: true,
      label: '${sermon.title}, ${sermon.speaker}. Play',
      excludeSemantics: true,
      child: GestureDetector(
        key: Key('home-message-${sermon.id}'),
        behavior: HitTestBehavior.opaque,
        onTap: () => startPlayback(context, ref, sermon),
        child: SizedBox(
          width: _kArtSize,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox.square(
                  dimension: _kArtSize,
                  child: url == null
                      ? fallback
                      : CachedNetworkImage(
                          imageUrl: url,
                          fit: BoxFit.cover,
                          placeholder: (_, _) => ColoredBox(color: kc.chipBg),
                          errorWidget: (_, _, _) => fallback,
                        ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                sermon.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.ui(
                  size: 14,
                  weight: FontWeight.w700,
                ).copyWith(color: kc.onBg, height: 1.25),
              ),
              const SizedBox(height: 3),
              Text(
                sermon.speaker,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.ui(
                  size: 12,
                ).copyWith(color: kc.muted, height: 1.2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
