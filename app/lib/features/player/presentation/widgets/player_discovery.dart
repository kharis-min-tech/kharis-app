import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/features/player/data/related_messages.dart';
import 'package:kharis_app/shared/models/sermon.dart';
import 'package:kharis_app/shared/providers/sermon_provider.dart';
import 'package:kharis_app/shared/widgets/artwork_image.dart';

/// "More like this" for a message, from the loaded library only; empty while
/// the library loads. Cached per message so playback ticks never re-rank.
final relatedMessagesProvider = Provider.autoDispose
    .family<List<Sermon>, Sermon>((ref, sermon) {
      final library =
          ref.watch(sermonsProvider).valueOrNull ?? const <Sermon>[];
      return relatedMessages(sermon, library);
    });

/// The message playback moves to next, as a card: tapping it skips there.
class UpNextCard extends StatelessWidget {
  const UpNextCard({super.key, required this.sermon, required this.onTap});

  final Sermon sermon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final kc = context.kc;
    final speaker = sermon.speaker.trim();
    return Semantics(
      button: true,
      label: [
        'Up next',
        sermon.title,
        if (speaker.isNotEmpty) speaker,
      ].join(', '),
      hint: 'Plays now',
      excludeSemantics: true,
      child: Material(
        key: const Key('player-up-next'),
        color: kc.surface,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.cardBorder,
          side: BorderSide(color: kc.divider),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                SizedBox.square(
                  dimension: 64,
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
                        'UP NEXT',
                        style: AppTypography.ui(
                          size: 10.5,
                          weight: FontWeight.w800,
                          letterSpacing: 1.2,
                          color: kc.accentInk,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        sermon.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.display(
                          size: 16,
                          weight: FontWeight.w700,
                          height: 1.15,
                          color: kc.onBg,
                        ),
                      ),
                      if (speaker.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          speaker,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.ui(size: 13, color: kc.muted),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox.square(
                  dimension: 44,
                  child: Icon(
                    Icons.skip_next_rounded,
                    size: 28,
                    color: kc.onBg,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "More like this": a horizontal rail of artwork-led message cards. The
/// caller hides it when [sermons] is empty.
class RelatedMessagesRail extends StatelessWidget {
  const RelatedMessagesRail({
    super.key,
    required this.sermons,
    required this.onOpen,
    this.padding = EdgeInsets.zero,
  });

  final List<Sermon> sermons;
  final ValueChanged<Sermon> onOpen;

  /// Inset of the heading and the rail's ends; the rail itself scrolls edge
  /// to edge.
  final EdgeInsets padding;

  static const double cardWidth = 148;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('player-related'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.only(left: padding.left, right: padding.right),
          child: Semantics(
            header: true,
            child: Text(
              'More like this',
              style: AppTypography.display(
                size: 20,
                weight: FontWeight.w800,
                color: context.kc.onBg,
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.only(left: padding.left, right: padding.right),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (i, sermon) in sermons.indexed) ...[
                if (i > 0) const SizedBox(width: 14),
                _RelatedCard(sermon: sermon, onTap: () => onOpen(sermon)),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _RelatedCard extends StatelessWidget {
  const _RelatedCard({required this.sermon, required this.onTap});

  final Sermon sermon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final kc = context.kc;
    final speaker = sermon.speaker.trim();
    return Semantics(
      button: true,
      label: [sermon.title, if (speaker.isNotEmpty) speaker].join(', '),
      hint: 'Plays this message',
      excludeSemantics: true,
      child: SizedBox(
        width: RelatedMessagesRail.cardWidth,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.cardBorder,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox.square(
                dimension: RelatedMessagesRail.cardWidth,
                child: ArtworkImage(
                  url: sermon.artworkUrl,
                  gradientIndex: sermon.artworkColor ?? 0,
                  radius: AppRadius.card,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                sermon.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.display(
                  size: 15,
                  weight: FontWeight.w700,
                  height: 1.15,
                  color: kc.onBg,
                ),
              ),
              if (speaker.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  speaker,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.ui(size: 12.5, color: kc.muted),
                ),
              ],
              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
    );
  }
}
