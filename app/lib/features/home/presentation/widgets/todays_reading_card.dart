import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kharis_app/core/theme/theme.dart';

class TodaysReadingCard extends StatelessWidget {
  const TodaysReadingCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: AppRadius.cardBorder,
        border: Border(
          left: BorderSide(color: AppColors.orange, width: 4),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  "TODAY'S READING",
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.orange,
                    letterSpacing: 0.8,
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.menu_book_rounded,
                  size: 16,
                  color: AppColors.orange,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Revelation 7',
              style: GoogleFonts.mavenPro(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '"After this I looked, and there before me was a great multitude that no one could count, from every nation..."',
              style: GoogleFonts.dmSans(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: AppColors.textBody,
                fontStyle: FontStyle.italic,
                height: 1.5,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: AppSpacing.md),
            GestureDetector(
              onTap: () {},
              child: Text(
                'Read full passage →',
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.orange,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
