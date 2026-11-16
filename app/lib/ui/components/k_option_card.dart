import 'package:flutter/material.dart';

import '../../theme/kharis_theme.dart';
import 'k_icon.dart';
import 'k_thumbnail.dart';

/// The radio at the end of an option card or sort row. Selected: primary
/// fill with a check, so the state does not rest on colour alone.
class KRadioMark extends StatelessWidget {
  const KRadioMark({super.key, required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? k.primary : null,
        border: selected
            ? null
            : Border.all(color: k.muted, width: KSize.outline),
      ),
      child: SizedBox.square(
        dimension: KSize.radio,
        child: selected
            ? Center(
                child: KIcon(
                  KIcons.check,
                  size: KSize.radioMark,
                  color: k.onPrimary,
                ),
              )
            : null,
      ),
    );
  }
}

/// One choice in a single-select group (a giving fund, a Bible version).
/// Selected: primaryTint fill, primary outline and a checked radio.
class KOptionCard extends StatelessWidget {
  const KOptionCard({
    super.key,
    required this.title,
    required this.selected,
    required this.onTap,
    this.meta,
    this.icon,
  });

  final String title;
  final String? meta;
  final bool selected;
  final VoidCallback? onTap;

  /// One of the [KIcons] paths, shown in a leading tile.
  final String? icon;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    const radius = BorderRadius.all(Radius.circular(KRadius.card));

    return Semantics(
      container: true,
      button: true,
      inMutuallyExclusiveGroup: true,
      checked: selected,
      enabled: onTap != null,
      label: meta == null ? title : '$title, $meta',
      onTap: onTap,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          // The tint is translucent, so lay it over the card surface.
          color: selected
              ? Color.alphaBlend(k.primaryTint, k.surface)
              : k.surface,
          borderRadius: radius,
          border: Border.all(color: selected ? k.primary : k.border),
          boxShadow: context.isDarkTheme ? KShadow.cardDark : KShadow.cardLight,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            borderRadius: radius,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: KSize.listRow),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: KSpace.xxl,
                  vertical: KSpace.xl,
                ),
                child: Row(
                  children: [
                    if (icon != null) ...[
                      KIconTile(icon!, emphasized: selected),
                      const SizedBox(width: KSpace.xl),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            style: KharisText.title.copyWith(color: k.text),
                          ),
                          if (meta != null)
                            Text(
                              meta!,
                              style: KharisText.meta.copyWith(color: k.muted),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: KSpace.xl),
                    KRadioMark(selected: selected),
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
