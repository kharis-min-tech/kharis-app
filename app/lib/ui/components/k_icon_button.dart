import 'package:flutter/material.dart';

import '../../theme/kharis_theme.dart';
import 'k_icon.dart';

enum KIconButtonVariant {
  /// Icon only, no fill.
  plain,

  /// Icon on a surface2 fill.
  filled,
}

/// An icon-only button: 40 visible inside a 44 hit area. [label] is what
/// screen readers announce, so it is required.
class KIconButton extends StatelessWidget {
  const KIconButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.variant = KIconButtonVariant.plain,
    this.color,
  });

  /// One of the [KIcons] paths.
  final String icon;

  /// Announced by screen readers, for example "Search".
  final String label;

  /// Null disables the button.
  final VoidCallback? onPressed;
  final KIconButtonVariant variant;

  /// Defaults to the theme's text colour.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final filled = variant == KIconButtonVariant.filled;

    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: label,
      onTap: onPressed,
      excludeSemantics: true,
      child: Opacity(
        opacity: onPressed == null ? KRatio.disabled : 1,
        // The outer detector makes the whole 44 box tappable; inside the
        // visible button the InkWell takes the tap, so it fires once.
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onPressed,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: KSize.touchMin,
              minHeight: KSize.touchMin,
            ),
            child: Center(
              widthFactor: 1,
              heightFactor: 1,
              child: Material(
                type: filled ? MaterialType.canvas : MaterialType.transparency,
                color: filled ? k.surface2 : null,
                clipBehavior: Clip.antiAlias,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(
                    Radius.circular(KRadius.button),
                  ),
                ),
                child: InkWell(
                  onTap: onPressed,
                  child: SizedBox.square(
                    dimension: KSize.chip,
                    child: Center(child: KIcon(icon, color: color ?? k.text)),
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
