import 'package:flutter/material.dart';

import '../../theme/kharis_theme.dart';
import 'k_card.dart';
import 'k_icon.dart';

/// A list row: at least 56 tall, with an optional 40 leading thumbnail or
/// icon tile ([KThumbnail], [KIconTile]), a one-line title, a meta line and a
/// trailing chevron or action. Read as one item.
class KListRow extends StatelessWidget {
  const KListRow({
    super.key,
    required this.title,
    this.meta,
    this.leading,
    this.trailing,
    this.showChevron = false,
    this.onTap,
  });

  final String title;
  final String? meta;

  /// Usually a [KThumbnail] or a [KIconTile].
  final Widget? leading;

  /// A value, badge or action at the end of the row.
  final Widget? trailing;

  /// Adds a chevron for rows that open another screen.
  final bool showChevron;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final k = context.k;

    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: KSize.listRow),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: KSpace.x3,
          vertical: KSpace.md,
        ),
        child: Row(
          children: [
            if (leading != null) ...[
              leading!,
              const SizedBox(width: KSpace.xl),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: KharisText.itemTitle.copyWith(color: k.text),
                  ),
                  if (meta != null)
                    Text(
                      meta!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: KharisText.meta.copyWith(color: k.muted),
                    ),
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: KSpace.md),
              trailing!,
            ],
            if (showChevron) ...[
              const SizedBox(width: KSpace.md),
              KIcon(KIcons.chevronRight, size: KSize.iconSm, color: k.muted),
            ],
          ],
        ),
      ),
    );

    return MergeSemantics(
      child: Semantics(
        button: onTap != null,
        child: onTap == null ? row : InkWell(onTap: onTap, child: row),
      ),
    );
  }
}

/// A card holding list rows, divided by a 1px line.
class KListGroup extends StatelessWidget {
  const KListGroup({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final line = BorderSide(color: context.k.line);

    return KCard(
      padding: EdgeInsets.zero,
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < children.length; i++)
              if (i == 0)
                children[i]
              else
                DecoratedBox(
                  position: DecorationPosition.foreground,
                  decoration: BoxDecoration(border: Border(top: line)),
                  child: children[i],
                ),
          ],
        ),
      ),
    );
  }
}
