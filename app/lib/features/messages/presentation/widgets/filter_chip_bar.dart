import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:kharis_app/core/theme/theme.dart';

/// A horizontally scrollable row of filter chips.
///
/// The active chip has an orange border, orange text, and a 10 % orange
/// background fill. Inactive chips use [AppColors.surfaceSubtle] background
/// and [AppColors.textBody] text.
class FilterChipBar extends StatelessWidget {
  const FilterChipBar({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
  });

  final List<String> labels;
  final int selectedIndex;
  final void Function(int index) onSelected;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        padding: padding,
        scrollDirection: Axis.horizontal,
        itemCount: labels.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final active = i == selectedIndex;
          return _FilterChip(
            label: labels[i],
            active: active,
            onTap: () => onSelected(i),
          );
        },
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
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
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
        decoration: BoxDecoration(
          color: active
              ? AppColors.accent.withValues(alpha: 0.10)
              : AppColors.surfaceSubtle,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: active
              ? Border.all(color: AppColors.accent, width: 1.5)
              : Border.all(color: Colors.transparent, width: 1.5),
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.dmSans(
              fontSize: 13,
              fontWeight: active ? FontWeight.w600 : FontWeight.w400,
              color: active ? AppColors.accent : AppColors.textBody,
              height: 1.0,
            ),
          ),
        ),
      ),
    );
  }
}
