import 'package:flutter/widgets.dart';

import '../../theme/kharis_theme.dart';
import 'k_icon.dart';

enum KBadgeVariant {
  /// A length on top of an image: inverse fill.
  duration,

  /// Happening now: highlight fill.
  live,

  /// New content: primaryTint fill.
  newItem,
}

/// A small label: 20 tall, xs corners, small text.
class KBadge extends StatelessWidget {
  const KBadge(
    this.label, {
    super.key,
    this.variant = KBadgeVariant.duration,
    this.icon,
  });

  final String label;
  final KBadgeVariant variant;

  /// One of the [KIcons] paths, shown before the label.
  final String? icon;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final (Color bg, Color fg) = switch (variant) {
      KBadgeVariant.duration => (
        k.inverse.withValues(alpha: KRatio.badgeScrim),
        k.onInverse,
      ),
      KBadgeVariant.live => (k.highlight, k.onHighlight),
      KBadgeVariant.newItem => (k.primaryTint, k.primaryText),
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.all(Radius.circular(KRadius.xs)),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: KSize.badge),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: KSpace.sm),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                KIcon(icon!, size: KSize.iconXs, color: fg),
                const SizedBox(width: KSpace.xs),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: KharisText.small.copyWith(color: fg),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
