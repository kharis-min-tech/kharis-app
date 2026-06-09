import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kharis_app/core/theme/theme.dart';

class _NewsItem {
  const _NewsItem({
    required this.title,
    required this.source,
    required this.age,
    required this.type,
    required this.gradientColors,
  });

  final String title;
  final String source;
  final String age;
  final String type;
  final List<Color> gradientColors;
}

const _kNewsItems = [
  _NewsItem(
    title: 'Happy Mothers Day Rev Awo...',
    source: 'Kharis Church',
    age: '2 weeks ago',
    type: 'Announcement',
    gradientColors: [Color(0xFF8B0A50), Color(0xFFC0305A)],
  ),
  _NewsItem(
    title: '21 Days Prayer & Fasting',
    source: 'Kharis Church',
    age: '1 month ago',
    type: 'Event',
    gradientColors: [Color(0xFF1A0A3B), Color(0xFF6B34FA)],
  ),
  _NewsItem(
    title: 'Kharis Phase 2 Conference',
    source: 'Kharis Church',
    age: '2 months ago',
    type: 'Conference',
    gradientColors: [Color(0xFF2A0A1A), Color(0xFFDC3F9E)],
  ),
];

class NewsSection extends ConsumerWidget {
  const NewsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'News & Updates',
          style: GoogleFonts.mavenPro(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          height: 200,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.zero,
            itemCount: _kNewsItems.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.md),
            itemBuilder: (context, index) =>
                _NewsCard(item: _kNewsItems[index]),
          ),
        ),
      ],
    );
  }
}

class _NewsCard extends StatelessWidget {
  const _NewsCard({required this.item});

  final _NewsItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: item.gradientColors,
        ),
      ),
      child: Stack(
        children: [
          // Content at bottom
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(12),
                ),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.7),
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: GoogleFonts.mavenPro(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        item.source,
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        width: 3,
                        height: 3,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white54,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        item.age,
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      item.type,
                      style: GoogleFonts.dmSans(
                        fontSize: 10,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
