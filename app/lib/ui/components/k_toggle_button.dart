import 'package:flutter/material.dart';

import '../../theme/kharis_theme.dart';
import 'k_icon.dart';

/// An on/off action such as "Remind me" or "Follow". 36 visible inside a 44
/// hit area. On: primaryTint fill, and the icon (and optionally the label)
/// changes too, so the state never rests on colour alone.
class KToggleButton extends StatelessWidget {
  const KToggleButton({
    super.key,
    required this.label,
    required this.selected,
    required this.onChanged,
    this.icon,
    this.selectedIcon = KIcons.check,
    this.selectedLabel,
    this.semanticLabel,
  });

  final String label;
  final bool selected;

  /// Called with the new value. Null disables the button.
  final ValueChanged<bool>? onChanged;

  /// One of the [KIcons] paths, shown while off.
  final String? icon;

  /// Shown while on.
  final String selectedIcon;

  /// Shown while on, for example "Reminder on". Defaults to [label].
  final String? selectedLabel;

  /// Replaces the label for screen readers, for example
  /// "Remind me about Midweek Service".
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final fg = selected ? k.primaryText : k.text;
    final text = selected ? selectedLabel ?? label : label;
    final onTap = onChanged == null ? null : () => onChanged!(!selected);

    return Semantics(
      button: true,
      toggled: selected,
      enabled: onChanged != null,
      label: semanticLabel ?? text,
      onTap: onTap,
      excludeSemantics: true,
      child: Opacity(
        opacity: onChanged == null ? KRatio.disabled : 1,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: KSize.touchMin),
            child: Center(
              widthFactor: 1,
              heightFactor: 1,
              child: Material(
                type: selected
                    ? MaterialType.canvas
                    : MaterialType.transparency,
                color: selected ? k.primaryTint : null,
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  borderRadius: const BorderRadius.all(
                    Radius.circular(KRadius.chip),
                  ),
                  side: selected
                      ? BorderSide.none
                      : BorderSide(color: k.line, width: KSize.outline),
                ),
                child: InkWell(
                  onTap: onTap,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: KSize.toggle),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: KSpace.xl,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (icon != null) ...[
                            KIcon(
                              selected ? selectedIcon : icon!,
                              size: KSize.iconXs,
                              color: fg,
                            ),
                            const SizedBox(width: KSpace.sm),
                          ],
                          Flexible(
                            child: Text(
                              text,
                              style: KharisText.itemTitle.copyWith(color: fg),
                            ),
                          ),
                        ],
                      ),
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
