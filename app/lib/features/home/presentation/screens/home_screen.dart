import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../widgets/daily_prayer_card.dart';
import '../widgets/greeting_section.dart';
import '../widgets/hero_card.dart';
import '../widgets/latest_sermons_section.dart';
import '../widgets/quick_actions_grid.dart';
import '../widgets/upcoming_events_section.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.surfaceDark,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.xl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GreetingSection(),
              SizedBox(height: AppSpacing.xl),
              HeroCard(),
              SizedBox(height: AppSpacing.xxl),
              QuickActionsGrid(),
              SizedBox(height: AppSpacing.xxl),
              LatestSermonsSection(),
              SizedBox(height: AppSpacing.xxl),
              UpcomingEventsSection(),
              SizedBox(height: AppSpacing.xxl),
              DailyPrayerCard(),
              SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }
}
