import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../theme/kharis_theme.dart';
import 'k_badge.dart';
import 'k_layout.dart';
import 'k_progress_bar.dart';
import 'k_thumbnail.dart';

/// One message in a list: artwork, title, a meta line ("Speaker · 12 Oct
/// 2026"), the passage it is preached from as a badge, and its length (or
/// any other short fact, such as a file size) at the end.
///
/// [progress] adds the listening bar under the text. [onMore] is the row's
/// second action (add to a collection, notes): a long press opens it, and
/// screen readers get it as a named action.
///
/// Put rows in a [KListGroup], or a [KSliverListGroup] for a long list.
class KMessageRow extends StatelessWidget {
  const KMessageRow({
    super.key,
    required this.title,
    this.meta,
    this.badge,
    this.trailingLabel,
    this.trailing,
    this.image,
    this.progress,
    this.progressLabel,
    this.onTap,
    this.onMore,
    this.moreLabel = 'More options',
  });

  final String title;
  final String? meta;

  /// For example "Mark 11".
  final String? badge;

  /// For example "48 min".
  final String? trailingLabel;

  /// A control after [trailingLabel], such as a remove button.
  final Widget? trailing;

  /// Null shows the surface2 placeholder.
  final ImageProvider? image;

  /// How much of the message has been heard, from 0 to 1.
  final double? progress;

  /// What screen readers call the bar, for example "Listened".
  final String? progressLabel;

  final VoidCallback? onTap;
  final VoidCallback? onMore;
  final String moreLabel;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final large = kIsLargeText(context);
    final length = trailingLabel == null
        ? null
        : Text(
            trailingLabel!,
            maxLines: 1,
            style: KharisText.caption.copyWith(
              color: k.muted,
              fontWeight: FontWeight.w700,
            ),
          );

    final row = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: KSpace.xl,
        vertical: KSpace.lg,
      ),
      child: Row(
        children: [
          KThumbnail(image: image, size: KSize.artwork),
          const SizedBox(width: KSpace.xl),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: large ? 2 : 1,
                  overflow: TextOverflow.ellipsis,
                  style: KharisText.itemTitle.copyWith(color: k.text),
                ),
                if (meta != null) ...[
                  const SizedBox(height: KSpace.xxs),
                  Text(
                    meta!,
                    maxLines: large ? 2 : 1,
                    overflow: TextOverflow.ellipsis,
                    style: KharisText.caption.copyWith(color: k.muted),
                  ),
                ],
                if (badge != null) ...[
                  const SizedBox(height: KSpace.xs),
                  KBadge(badge!, variant: KBadgeVariant.newItem),
                ],
                // At large text the length drops under the words, so the
                // title keeps the width.
                if (large && length != null) ...[
                  const SizedBox(height: KSpace.xs),
                  length,
                ],
                if (progress != null) ...[
                  const SizedBox(height: KSpace.md),
                  KProgressBar(value: progress!, semanticLabel: progressLabel),
                ],
              ],
            ),
          ),
          if (!large && length != null) ...[
            const SizedBox(width: KSpace.xl),
            length,
          ],
          if (trailing != null) ...[
            const SizedBox(width: KSpace.md),
            trailing!,
          ],
        ],
      ),
    );

    return MergeSemantics(
      child: Semantics(
        button: onTap != null,
        customSemanticsActions: onMore == null
            ? null
            : {CustomSemanticsAction(label: moreLabel): onMore!},
        child: onTap == null && onMore == null
            ? row
            : InkWell(onTap: onTap, onLongPress: onMore, child: row),
      ),
    );
  }
}

/// The card of a [KListGroup] as a sliver, building its rows as they scroll
/// into view: for lists that can run to hundreds of messages.
class KSliverListGroup extends StatelessWidget {
  const KSliverListGroup({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
  });

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final line = BorderSide(color: k.line);
    const corner = Radius.circular(KRadius.card);

    return DecoratedSliver(
      decoration: BoxDecoration(
        color: k.surface,
        borderRadius: const BorderRadius.all(corner),
        border: Border.all(color: k.border),
        boxShadow: context.isDarkTheme ? KShadow.cardDark : KShadow.cardLight,
      ),
      sliver: SliverList.builder(
        itemCount: itemCount,
        itemBuilder: (context, i) => Material(
          // Ink is drawn here, above the card's fill, and kept inside its
          // corners.
          type: MaterialType.transparency,
          clipBehavior: Clip.antiAlias,
          borderRadius: BorderRadius.vertical(
            top: i == 0 ? corner : Radius.zero,
            bottom: i == itemCount - 1 ? corner : Radius.zero,
          ),
          child: i == 0
              ? itemBuilder(context, i)
              : DecoratedBox(
                  position: DecorationPosition.foreground,
                  decoration: BoxDecoration(border: Border(top: line)),
                  child: itemBuilder(context, i),
                ),
        ),
      ),
    );
  }
}
