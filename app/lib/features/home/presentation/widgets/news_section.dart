import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';

class _NewsItem {
  const _NewsItem({
    required this.title,
    required this.date,
    required this.gradientColors,
  });

  final String title;
  final String date;
  final List<Color> gradientColors;
}

const _kNewsItems = [
  _NewsItem(
    title: '21 Days Prayer & Fasting',
    date: '1st - 21st June 2026',
    gradientColors: [Color(0xFF1A0A3B), Color(0xFF6B34FA)],
  ),
  _NewsItem(
    title: 'Kharis Phase 2 Conference',
    date: 'Coming September 2026',
    gradientColors: [Color(0xFF2A0A1A), Color(0xFFFD7F20)],
  ),
  _NewsItem(
    title: 'Youth Camp Registration Open',
    date: 'July 2026',
    gradientColors: [Color(0xFF0A2A1A), Color(0xFF059669)],
  ),
];

class NewsSection extends ConsumerWidget {
  const NewsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Section header ───────────────────────────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'News & Updates',
              style: GoogleFonts.mavenPro(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              'See All',
              style: GoogleFonts.dmSans(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.orange,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),

        // ── Horizontal scroll ────────────────────────────────────────────────
        SizedBox(
          height: 280,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.zero,
            itemCount: _kNewsItems.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.md),
            itemBuilder: (context, index) {
              final item = _kNewsItems[index];
              return _NewsCard(
                title: item.title,
                date: item.date,
                gradientColors: item.gradientColors,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _NewsCard extends StatelessWidget {
  const _NewsCard({
    required this.title,
    required this.date,
    required this.gradientColors,
  });

  final String title;
  final String date;
  final List<Color> gradientColors;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Image area with gradient overlay ────────────────────────────────
          ClipRRect(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppRadius.card),
            ),
            child: SizedBox(
              height: 200,
              width: 280,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Placeholder "image" — brand gradient background
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: gradientColors,
                      ),
                    ),
                  ),
                  // Overlay: transparent → surfaceDark (fades bottom of image)
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, AppColors.surfaceDark],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Title + date ─────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.mavenPro(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  date,
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: AppColors.textBody,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
