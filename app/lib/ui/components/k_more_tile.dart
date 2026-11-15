import 'package:flutter/material.dart';

import '../../theme/kharis_theme.dart';
import 'k_icon.dart';
import 'k_layout.dart';

/// A shortcut tile on More: an icon, a title and one line saying what is
/// behind it ("12 saved"). Read as one button.
class KMoreTile extends StatelessWidget {
  const KMoreTile({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.meta,
  });

  /// One of the [KIcons] paths.
  final String icon;
  final String title;

  /// A count or a fact. Leave null while it is not known.
  final String? meta;
  final VoidCallback onTap;

  static const double _minHeight = 96;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    const radius = BorderRadius.all(Radius.circular(KRadius.tile));

    return Semantics(
      container: true,
      button: true,
      label: meta == null ? title : '$title, $meta',
      onTap: onTap,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: k.surface,
          borderRadius: radius,
          border: Border.all(color: k.border),
          boxShadow: context.isDarkTheme ? KShadow.cardDark : KShadow.cardLight,
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: onTap,
              borderRadius: radius,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: _minHeight),
                child: Padding(
                  padding: const EdgeInsets.all(KSpace.xxl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      KIcon(icon, color: k.primaryText),
                      const SizedBox(height: KSpace.xxl),
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: KharisText.title.copyWith(color: k.text),
                      ),
                      if (meta != null) ...[
                        const SizedBox(height: KSpace.xxs),
                        Text(
                          meta!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: KharisText.meta.copyWith(color: k.muted),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Lays [KMoreTile]s out two to a row, each pair the same height. At large
/// text sizes the tiles stack one to a row so titles keep their width.
class KMoreTileGrid extends StatelessWidget {
  const KMoreTileGrid({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (kIsLargeText(context)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (i, child) in children.indexed) ...[
            if (i > 0) const SizedBox(height: KSpace.lg),
            child,
          ],
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < children.length; i += 2) ...[
          if (i > 0) const SizedBox(height: KSpace.lg),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: children[i]),
                const SizedBox(width: KSpace.lg),
                Expanded(
                  child: i + 1 < children.length
                      ? children[i + 1]
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
