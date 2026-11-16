import 'package:flutter/material.dart';

import '../../theme/kharis_theme.dart';
import 'k_icon.dart';

/// One of the two verse highlight colours as a 44 square: the colour, with
/// its number on it so it is never told apart by colour alone. With [onTap]
/// it is a button; [selected] swaps the number for a check and outlines it.
class KHighlightSwatch extends StatelessWidget {
  const KHighlightSwatch({
    super.key,
    required this.colour,
    this.selected = false,
    this.onTap,
  }) : assert(colour == 1 || colour == 2, 'There are two highlight colours.');

  /// 1 or 2: the theme's `verseHighlight1` or `verseHighlight2`.
  final int colour;
  final bool selected;

  /// Null shows the swatch as a label, not a button.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    const radius = BorderRadius.all(Radius.circular(KRadius.tile));
    final tint = colour == 1 ? k.verseHighlight1 : k.verseHighlight2;

    final swatch = DecoratedBox(
      decoration: BoxDecoration(
        // The highlight is translucent, so lay it over the surface.
        color: Color.alphaBlend(tint, k.surface),
        borderRadius: radius,
        border: selected
            ? Border.all(color: k.text, width: KSize.outline)
            : Border.all(color: k.border),
      ),
      child: SizedBox.square(
        dimension: KSize.touchMin,
        child: Center(
          child: selected
              ? KIcon(KIcons.check, size: KSize.iconSm, color: k.text)
              : Text(
                  '$colour',
                  style: KharisText.itemTitle.copyWith(color: k.text),
                ),
        ),
      ),
    );

    return Semantics(
      container: true,
      button: onTap != null,
      selected: onTap == null ? null : selected,
      label: 'Colour $colour',
      onTap: onTap,
      excludeSemantics: true,
      child: onTap == null
          ? swatch
          : Material(
              type: MaterialType.transparency,
              child: InkWell(onTap: onTap, borderRadius: radius, child: swatch),
            ),
    );
  }
}
