import 'package:flutter/material.dart';

import 'package:kharis_app/core/theme/theme.dart';

/// Horizontal row of sort/filter pills.
///
/// Active pill: gold bg + gold ink. Inactive: muted surface + muted text.
class SortPillBar extends StatelessWidget {
  const SortPillBar({
    super.key,
    required this.labels,
    required this.activeIndex,
    required this.onSelected,
    this.padding = const EdgeInsets.symmetric(horizontal: 20),
  });

  final List<String> labels;
  final int activeIndex;
  final void Function(int index) onSelected;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < labels.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            _SortPill(
              label: labels[i],
              active: i == activeIndex,
              onTap: () => onSelected(i),
            ),
          ],
        ],
      ),
    );
  }
}

class _SortPill extends StatelessWidget {
  const _SortPill({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: active ? context.kc.accent : context.kc.surfaceMuted,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Text(
          label,
          style: AppTypography.ui(
            size: 13,
            weight: FontWeight.w600,
            color: active ? context.kc.onAccent : context.kc.muted,
          ),
        ),
      ),
    );
  }
}
