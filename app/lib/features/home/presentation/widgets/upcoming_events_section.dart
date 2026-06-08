import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kharis_app/core/theme/theme.dart';
import 'event_card.dart';

class UpcomingEventsSection extends StatelessWidget {
  const UpcomingEventsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Upcoming Events',
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
        EventCard(
          day: '14',
          month: 'Jun',
          title: 'Healing School – Summer Session',
          location: 'Healing School Campus, Lagos',
          time: '9:00 AM – 5:00 PM WAT',
          onTap: () {},
        ),
        const SizedBox(height: AppSpacing.md),
        EventCard(
          day: '21',
          month: 'Jun',
          title: 'Your LoveWorld Praise-A-Thon',
          location: 'LoveWorld Networks, Broadcast',
          time: '7:00 PM WAT',
          onTap: () {},
        ),
      ],
    );
  }
}
