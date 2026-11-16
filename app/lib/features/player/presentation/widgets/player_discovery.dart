import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kharis_app/features/player/data/related_messages.dart';
import 'package:kharis_app/shared/models/sermon.dart';
import 'package:kharis_app/shared/providers/sermon_provider.dart';
import 'package:kharis_app/shared/widgets/artwork_image.dart';
import 'package:kharis_app/ui/components/components.dart';

/// "More like this" for a message, from the loaded library only; empty while
/// the library loads. Cached per message so playback ticks never re-rank.
final relatedMessagesProvider = Provider.autoDispose
    .family<List<Sermon>, Sermon>((ref, sermon) {
      final library =
          ref.watch(sermonsProvider).valueOrNull ?? const <Sermon>[];
      return relatedMessages(sermon, library);
    });

/// A card under the player holding one discovery block (about, related
/// messages, Explore, Up next), so suggestions sit apart from playback.
class PlayerDiscoveryPanel extends StatelessWidget {
  const PlayerDiscoveryPanel({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: KSpace.gutter),
      child: KCard(
        padding: const EdgeInsets.symmetric(vertical: KSpace.x3),
        // Rows and links inside draw their ink on the card.
        child: Material(type: MaterialType.transparency, child: child),
      ),
    );
  }
}

/// A discovery panel's heading, inset like the rows beneath it.
class _PanelHeading extends StatelessWidget {
  const _PanelHeading(this.text, {this.action, this.onAction});

  final String text;

  /// A link at the right ("See all"), shown with [onAction].
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: KSpace.x3),
      child: KSectionHeader(
        title: text,
        actionLabel: onAction == null ? null : action,
        onAction: onAction,
      ),
    );
  }
}

/// The artwork of [sermon] as a list row's leading thumbnail.
class _RowArtwork extends StatelessWidget {
  const _RowArtwork(this.sermon);

  final Sermon sermon;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: KSize.thumb,
      child: ArtworkImage(
        url: sermon.artworkUrl,
        gradientIndex: sermon.artworkColor ?? 0,
        radius: KRadius.tile,
      ),
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
  /// Descriptions longer than this get "See more".
  static const int _longBody = 140;
  static const int _closedLines = 3;

  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
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
    return Column(
      key: const Key('player-about'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _PanelHeading('About this message'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: KSpace.x3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (meta.isNotEmpty)
                Text(meta, style: KharisText.meta.copyWith(color: k.muted)),
              if (body.isNotEmpty) ...[
                const SizedBox(height: KSpace.md),
                GestureDetector(
                  onTap: () => setState(() => _open = !_open),
                  child: Text(
                    body,
                    maxLines: _open ? null : _closedLines,
                    overflow: _open ? null : TextOverflow.ellipsis,
                    style: KharisText.body.copyWith(color: k.text),
                  ),
                ),
                if (!_open && body.length > _longBody)
                  KTextLink(
                    key: const Key('player-about-more'),
                    label: 'See more',
                    onTap: () => setState(() => _open = true),
                  ),
              ],
              if (series.isNotEmpty && widget.onSeries != null) ...[
                const SizedBox(height: KSpace.md),
                // A long series name scrolls rather than overflowing.
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: KChip(
                    key: const Key('player-about-series'),
                    label: series,
                    onTap: widget.onSeries,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// One "Explore" row: where it leads.
typedef ExploreTile = ({String id, String label, VoidCallback onTap});

/// "Explore": rows that each open Messages already filtered (more from this
/// series, from this speaker, on this topic).
class ExploreMessagesRow extends StatelessWidget {
  const ExploreMessagesRow({super.key, required this.tiles});

  final List<ExploreTile> tiles;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('player-explore'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _PanelHeading('Explore'),
        for (final tile in tiles)
          KListRow(
            key: Key('player-explore-${tile.id}'),
            title: tile.label,
            leading: const KIconTile(KIcons.collection),
            showChevron: true,
            onTap: tile.onTap,
          ),
      ],
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
    final speaker = sermon.speaker.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _PanelHeading('Up next'),
        Semantics(
          button: true,
          label: [
            'Up next',
            sermon.title,
            if (speaker.isNotEmpty) speaker,
          ].join(', '),
          hint: 'Plays now',
          onTap: onTap,
          excludeSemantics: true,
          child: KListRow(
            key: const Key('player-up-next'),
            title: sermon.title,
            meta: speaker.isEmpty ? null : speaker,
            leading: _RowArtwork(sermon),
            trailing: const KIcon(KIcons.play, size: KSize.iconSm),
            onTap: onTap,
          ),
        ),
      ],
    );
  }
}

/// "You might also like": the related messages as list rows. The caller
/// hides it when [sermons] is empty.
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

  /// Extra inset around the heading and the rows, on top of their own.
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const Key('player-related'),
      padding: EdgeInsets.only(left: padding.left, right: padding.right),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PanelHeading(title, action: 'See all', onAction: onSeeAll),
          for (final sermon in sermons) _relatedRow(sermon),
        ],
      ),
    );
  }

  Widget _relatedRow(Sermon sermon) {
    final speaker = sermon.speaker.trim();
    return Semantics(
      button: true,
      label: [sermon.title, if (speaker.isNotEmpty) speaker].join(', '),
      hint: 'Plays this message',
      onTap: () => onOpen(sermon),
      excludeSemantics: true,
      child: KListRow(
        title: sermon.title,
        meta: speaker.isEmpty ? null : speaker,
        leading: _RowArtwork(sermon),
        onTap: () => onOpen(sermon),
      ),
    );
  }
}
