import 'package:flutter/material.dart';

import '../../theme/kharis_theme.dart';
import 'k_icon.dart';

/// A round primary button holding one icon: play in a listening card, send
/// in the composer. Not in the barrel: screens reach it through the
/// components that own it.
class KCircleButton extends StatelessWidget {
  const KCircleButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.size = KSize.chip,
    this.iconSize = KSize.iconSm,
  });

  /// One of the [KIcons] paths.
  final String icon;

  /// Announced by screen readers.
  final String label;

  /// Null disables the button.
  final VoidCallback? onPressed;

  /// Visible diameter. The hit area is never smaller than 44.
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final k = context.k;

    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: label,
      onTap: onPressed,
      excludeSemantics: true,
      child: Opacity(
        opacity: onPressed == null ? KRatio.disabled : 1,
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
                color: k.primary,
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: onPressed,
                  customBorder: const CircleBorder(),
                  child: SizedBox.square(
                    dimension: size,
                    child: Center(
                      child: KIcon(icon, size: iconSize, color: k.onPrimary),
                    ),
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
