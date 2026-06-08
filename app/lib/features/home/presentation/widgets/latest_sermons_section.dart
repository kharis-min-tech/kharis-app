import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kharis_app/core/theme/theme.dart';
import 'sermon_card.dart';

class _SermonData {
  final String title;
  final String speaker;
  final List<Color> gradient;

  const _SermonData({
    required this.title,
    required this.speaker,
    required this.gradient,
  });
}

const _sermons = [
  _SermonData(
    title: 'The Power of Consecration',
    speaker: 'Pastor Chris Oyakhilome',
    gradient: [Color(0xFF1A0A3B), Color(0xFF6B34FA)],
  ),
  _SermonData(
    title: 'Walking in Divine Health',
    speaker: 'Pastor Anita Oyakhilome',
    gradient: [Color(0xFF1A2A0A), Color(0xFF22C55E)],
  ),
  _SermonData(
    title: 'Faith That Moves Mountains',
    speaker: 'Pastor Chris Oyakhilome',
    gradient: [Color(0xFF3B1A0A), Color(0xFFFD7F20)],
  ),
  _SermonData(
    title: 'Living in the Spirit',
    speaker: 'Pastor Tom Amenkhienan',
    gradient: [Color(0xFF0A1A3B), Color(0xFF3B82F6)],
  ),
];

class LatestSermonsSection extends StatelessWidget {
  const LatestSermonsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Row(
          children: [
            Text(
              'Latest Sermons',
              style: GoogleFonts.mavenPro(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: () {},
              child: Text(
                'See All',
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.orange,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        // Horizontal scroll
        SizedBox(
          height: 210,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.zero,
            itemCount: _sermons.length,
            separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.md),
            itemBuilder: (context, index) {
              final sermon = _sermons[index];
              return SermonCard(
                title: sermon.title,
                speaker: sermon.speaker,
                gradientColors: sermon.gradient,
              );
            },
          ),
        ),
      ],
    );
  }
}
