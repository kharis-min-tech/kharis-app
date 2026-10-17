import 'package:flutter/material.dart';
import 'package:kharis_app/core/theme/theme.dart';

/// A branch row: the branch name and region, and a gold **HQ** badge for the
/// headquarters (warm tint). Tapping the row selects and proceeds. No photo:
/// most branches share one placeholder image in the Content Studio, so a
/// thumbnail only repeated the same picture down the list.
class BranchTile extends StatelessWidget {
  const BranchTile({
    super.key,
    required this.name,
    required this.region,
    required this.onTap,
    this.isHq = false,
  });

  final String name;
  final String region;
  final VoidCallback onTap;
  final bool isHq;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            // The cream HQ tint is a light-surface colour; on dark surfaces it
            // swallowed the white name text, so dark mode keeps the card
            // surface and lets the gold stroke mark HQ.
            color: isHq && Theme.of(context).brightness == Brightness.light
                ? AppColors.hqTint
                : context.kc.surface,
            borderRadius: AppRadius.cardBorder,
            border: isHq
                ? Border.all(color: AppColors.hqStroke.withValues(alpha: 0.5))
                : null,
            boxShadow: isHq ? null : AppShadows.card,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: AppTypography.ui(
                        size: 16,
                        weight: FontWeight.w700,
                      ).copyWith(color: context.kc.onBg),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      region,
                      style: AppTypography.ui(
                        size: 13,
                      ).copyWith(color: context.kc.muted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (isHq) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: context.kc.accent,
                    borderRadius: AppRadius.pillBorder,
                  ),
                  child: Text(
                    'HQ',
                    style: AppTypography.ui(
                      size: 11,
                      weight: FontWeight.w800,
                    ).copyWith(color: context.kc.onAccent, letterSpacing: 0.5),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
