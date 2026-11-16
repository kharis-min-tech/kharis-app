import 'package:flutter/material.dart';

import '../../theme/kharis_theme.dart';

/// Base card: surface fill, 1px border, card radius, and a soft shadow in
/// light mode only (elevation level 1). Every card in the app builds on this.
class KCard extends StatelessWidget {
  const KCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(KSpace.x3),
    this.onTap,
    this.semanticLabel,
  });

  final Widget child;

  /// Default 16. Use `EdgeInsets.all(KSpace.xxl)` (14) for compact cards.
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  /// Read as one item by screen readers when set.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    const radius = BorderRadius.all(Radius.circular(KRadius.card));

    Widget content = Padding(padding: padding, child: child);
    if (onTap != null) {
      content = Material(
        type: MaterialType.transparency,
        child: InkWell(onTap: onTap, borderRadius: radius, child: content),
      );
    }

    final card = DecoratedBox(
      decoration: BoxDecoration(
        color: k.surface,
        borderRadius: radius,
        border: Border.all(color: k.border),
        boxShadow: context.isDarkTheme ? KShadow.cardDark : KShadow.cardLight,
      ),
      child: ClipRRect(borderRadius: radius, child: content),
    );

    if (semanticLabel == null) return card;
    return Semantics(
      container: true,
      button: onTap != null,
      label: semanticLabel,
      excludeSemantics: true,
      child: card,
    );
  }
}
