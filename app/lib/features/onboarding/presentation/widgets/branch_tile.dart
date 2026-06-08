import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kharis_app/core/theme/app_colors.dart';

class BranchTile extends StatelessWidget {
  const BranchTile({
    super.key,
    required this.name,
    required this.location,
    required this.isSelected,
    required this.onTap,
  });

  final String name;
  final String location;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.orange : Colors.transparent,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.location_on,
              color: AppColors.orange,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name,
                    style: GoogleFonts.mavenPro(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    location,
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      color: AppColors.textBody,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle_rounded,
                color: AppColors.orange,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}
