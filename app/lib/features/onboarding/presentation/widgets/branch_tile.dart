import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:kharis_app/core/theme/theme.dart';

/// A branch row (design-handoff v3): a rounded city-landmark thumbnail, the
/// branch name and region, and a gold **HQ** badge for the headquarters (warm
/// tint). Tapping the row selects and proceeds.
class BranchTile extends StatelessWidget {
  const BranchTile({
    super.key,
    required this.name,
    required this.region,
    required this.gradientColors,
    required this.onTap,
    this.imageUrl,
    this.isHq = false,
  });

  final String name;
  final String region;
  final List<Color> gradientColors;
  final VoidCallback onTap;
  final String? imageUrl;
  final bool isHq;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isHq ? AppColors.hqTint : context.kc.surface,
          borderRadius: AppRadius.cardBorder,
          border: isHq
              ? Border.all(color: AppColors.hqStroke.withValues(alpha: 0.5))
              : null,
          boxShadow: isHq ? null : AppShadows.card,
        ),
        child: Row(
          children: [
            _Thumb(imageUrl: imageUrl, gradientColors: gradientColors),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: AppTypography.ui(size: 16, weight: FontWeight.w700)
                        .copyWith(color: context.kc.onBg),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    region,
                    style: AppTypography.ui(size: 13)
                        .copyWith(color: context.kc.muted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (isHq) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: context.kc.accent,
                  borderRadius: AppRadius.pillBorder,
                ),
                child: Text(
                  'HQ',
                  style: AppTypography.ui(size: 11, weight: FontWeight.w800)
                      .copyWith(color: context.kc.onAccent, letterSpacing: 0.5),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.imageUrl, required this.gradientColors});

  final String? imageUrl;
  final List<Color> gradientColors;

  @override
  Widget build(BuildContext context) {
    final gradient = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
      ),
    );
    return ClipRRect(
      borderRadius: AppRadius.tileBorder,
      child: SizedBox(
        width: 48,
        height: 48,
        child: (imageUrl == null || imageUrl!.isEmpty)
            ? gradient
            : imageUrl!.startsWith('assets/')
                ? Image.asset(
                    imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => gradient,
                  )
                : CachedNetworkImage(
                    imageUrl: imageUrl!,
                    fit: BoxFit.cover,
                    placeholder: (_, _) => gradient,
                    errorWidget: (_, _, _) => gradient,
                  ),
      ),
    );
  }
}
