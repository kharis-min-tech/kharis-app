import 'package:flutter/material.dart';

import 'package:kharis_app/core/theme/theme.dart';

/// The "which message" badge on a notebook entry.
class NoteAnchorChip extends StatelessWidget {
  const NoteAnchorChip({super.key, required this.title, this.maxWidth = 220});

  final String title;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final ink = context.kc.onChip;
    return Container(
      constraints: BoxConstraints(maxWidth: maxWidth),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: context.kc.chipBg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.headphones_outlined, size: 14, color: ink),
          const SizedBox(width: AppSpacing.xs),
          Flexible(
            child: Text(
              title,
              style: AppTypography.ui(
                size: 11,
                color: ink,
                weight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
