import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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

/// A rounded panel under the player holding one discovery block (related
/// messages, Up next), so suggestions sit apart from playback.
class PlayerDiscoveryPanel extends StatelessWidget {
  const PlayerDiscoveryPanel({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        color: context.kc.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: child,
    );
  }
}

/// A discovery panel's heading.
class _PanelHeading extends StatelessWidget {
  const _PanelHeading(this.text, {this.action, this.onAction});

  final String text;

  /// A link at the right ("See all"), shown with [onAction].
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final action = this.action;
    return Row(
      children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Text(
              text,
              style: AppTypography.ui(
                size: 17,
                weight: FontWeight.w700,
                color: context.kc.onBg,
              ),
            ),
          ),
        ),
        if (action != null && onAction != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              foregroundColor: context.kc.accentInk,
              minimumSize: const Size(48, 40),
              padding: const EdgeInsets.only(left: 12),
            ),
            child: Text(
              action,
              style: AppTypography.ui(
                size: 13.5,
                weight: FontWeight.w700,
                color: context.kc.accentInk,
              ),
            ),
          ),
      ],
    );
  }
}

/// "About this message": when it was preached and how long it is, the
/// description (three lines, "See more" opens the rest), and the series as
/// a chip. Renders nothing when there is no description.
class AboutMessageCard extends StatefulWidget {
  const AboutMessageCard({super.key, required this.sermon, this.onSeries});

  final Sermon sermon;

  /// Opens the series (the chip); null hides the chip.
  final VoidCallback? onSeries;

  @override
  State<AboutMessageCard> createState() => _AboutMessageCardState();
}

class _AboutMessageCardState extends State<AboutMessageCard> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final kc = context.kc;
    final sermon = widget.sermon;
    final body = sermon.description?.trim() ?? '';
    final date = sermon.publishedAt;
    final length = sermon.duration;
    final meta = [
      if (date != null) DateFormat('EEEE \u00b7 d MMMM y').format(date),
      if (length != null && length > Duration.zero)
        length.inHours > 0
            ? '${length.inHours}h ${length.inMinutes.remainder(60)}m'
            : '${length.inMinutes} min',
    ].join(' \u00b7 ');
    final series = sermon.series?.trim() ?? '';
    return Padding(
      key: const Key('player-about'),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _PanelHeading('About this message'),
          if (meta.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(meta, style: AppTypography.ui(size: 13, color: kc.muted)),
          ],
          if (body.isNotEmpty) ...[
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => setState(() => _open = !_open),
              child: Text(
                body,
                maxLines: _open ? null : 3,
                overflow: _open ? null : TextOverflow.ellipsis,
                style: AppTypography.ui(size: 14, height: 1.45, color: kc.onBg),
              ),
            ),
            if (!_open && body.length > 140)
              TextButton(
                key: const Key('player-about-more'),
                onPressed: () => setState(() => _open = true),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(48, 36),
                ),
                child: Text(
                  'See more',
                  style: AppTypography.ui(
                    size: 13.5,
                    weight: FontWeight.w700,
                    color: kc.onBg,
                  ),
                ),
              ),
          ],
          if (series.isNotEmpty && widget.onSeries != null) ...[
            const SizedBox(height: 10),
            ActionChip(
              key: const Key('player-about-series'),
              label: Text(series),
              avatar: Icon(Icons.chevron_right_rounded, color: kc.onBg),
              onPressed: widget.onSeries,
              backgroundColor: kc.chipBg,
              side: BorderSide.none,
              shape: const StadiumBorder(),
              labelStyle: AppTypography.ui(
                size: 13,
                weight: FontWeight.w700,
                color: kc.onChip,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// One "Explore" tile: where it leads, over the message's artwork.
typedef ExploreTile = ({String id, String label, VoidCallback onTap});

/// "Explore": tall tiles, each opening Messages already filtered (more from
/// this series, from this speaker, on this topic).
class ExploreMessagesRow extends StatelessWidget {
  const ExploreMessagesRow({
    super.key,
    required this.sermon,
    required this.tiles,
  });

  /// Whose artwork the tiles carry.
  final Sermon sermon;
  final List<ExploreTile> tiles;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('player-explore'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: _PanelHeading('Explore'),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              for (final (i, tile) in tiles.indexed) ...[
                if (i > 0) const SizedBox(width: 10),
                _ExploreTileView(sermon: sermon, tile: tile),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ExploreTileView extends StatelessWidget {
  const _ExploreTileView({required this.sermon, required this.tile});

  final Sermon sermon;
  final ExploreTile tile;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: tile.label,
      excludeSemantics: true,
      child: GestureDetector(
        key: Key('player-explore-${tile.id}'),
        onTap: tile.onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.defaultRadius),
          child: SizedBox(
            width: 112,
            height: 152,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ArtworkImage(
                  url: sermon.artworkUrl,
                  gradientIndex: sermon.artworkColor ?? 0,
                  radius: 0,
                ),
                // A solid band (no gradient) keeps the words legible on any
                // artwork.
                Align(
                  alignment: Alignment.bottomLeft,
                  child: Container(
                    width: double.infinity,
                    color: Colors.black.withValues(alpha: 0.62),
                    padding: const EdgeInsets.fromLTRB(9, 7, 9, 9),
                    child: Text(
                      tile.label,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.ui(
                        size: 13,
                        weight: FontWeight.w700,
                        height: 1.2,
                        color: Colors.white,
                      ),
                    ),
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

/// "Up next": the message playback moves to next; tapping it skips there.
/// Sits inside a [PlayerDiscoveryPanel].
class UpNextCard extends StatelessWidget {
  const UpNextCard({super.key, required this.sermon, required this.onTap});

  final Sermon sermon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final kc = context.kc;
    final speaker = sermon.speaker.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: _PanelHeading('Up next'),
        ),
        const SizedBox(height: 10),
        Semantics(
          button: true,
          label: [
            'Up next',
            sermon.title,
            if (speaker.isNotEmpty) speaker,
          ].join(', '),
          hint: 'Plays now',
          excludeSemantics: true,
          child: InkWell(
            key: const Key('player-up-next'),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
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
      ],
    );
  }
}

/// "You might also like": a horizontal rail of artwork-led message cards. The
/// caller hides it when [sermons] is empty.
class RelatedMessagesRail extends StatelessWidget {
  const RelatedMessagesRail({
    super.key,
    required this.sermons,
    required this.onOpen,
    this.padding = EdgeInsets.zero,
    this.onSeeAll,
    this.title = 'You might also like',
  });

  /// The heading.
  final String title;

  final List<Sermon> sermons;
  final ValueChanged<Sermon> onOpen;

  /// "See all" at the heading's right; null hides it.
  final VoidCallback? onSeeAll;

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
          child: _PanelHeading(title, action: 'See all', onAction: onSeeAll),
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
