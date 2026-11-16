import 'package:flutter/material.dart';

import '../../theme/kharis_theme.dart';
import 'k_icon.dart';

/// A text action such as "History" or "See all", in primaryText.
class KTextLink extends StatelessWidget {
  const KTextLink({
    super.key,
    required this.label,
    required this.onTap,
    this.showChevron = false,
    this.semanticLabel,
  });

  final String label;

  /// Null disables the link.
  final VoidCallback? onTap;

  /// Adds a trailing chevron for links that open another screen.
  final bool showChevron;

  /// Replaces [label] for screen readers when the label alone is unclear,
  /// for example "Listening history" for "History".
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final k = context.k;

    return Semantics(
      button: true,
      enabled: onTap != null,
      label: semanticLabel ?? label,
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: const BorderRadius.all(Radius.circular(KRadius.button)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: KSize.touchMin,
              minHeight: KSize.touchMin,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    label,
                    style: KharisText.link.copyWith(color: k.primaryText),
                  ),
                ),
                if (showChevron) ...[
                  const SizedBox(width: KSpace.xxs),
                  KIcon(
                    KIcons.chevronRight,
                    size: KSize.iconXs,
                    color: k.primaryText,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
