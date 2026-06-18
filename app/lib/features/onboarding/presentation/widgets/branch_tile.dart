import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kharis_app/core/theme/app_colors.dart';

class BranchTile extends StatelessWidget {
  const BranchTile({
    super.key,
    required this.name,
    required this.subtitle,
    required this.gradientColors,
    required this.isSelected,
    required this.onTap,
  });

  final String name;
  final String subtitle;
  final List<Color> gradientColors;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0x991E1E1E), // rgba(30,30,30,0.6)
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? AppColors.secondary.withValues(alpha: 0.30)
                : Colors.white.withValues(alpha: 0.05),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // ── Gradient image placeholder ─────────────────────────────
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: gradientColors,
                ),
              ),
              child: const Icon(
                Icons.church_rounded,
                color: Colors.white54,
                size: 28,
              ),
            ),
            const SizedBox(width: 14),

            // ── Text ──────────────────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),

            // ── Selection indicator ───────────────────────────────────
            if (isSelected)
              const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.secondary,
                  size: 22,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
