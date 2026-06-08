import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/providers/sermon_provider.dart';
import '../widgets/daily_prayer_card.dart';
import '../widgets/greeting_section.dart';
import '../widgets/hero_card.dart';
import '../widgets/latest_sermons_section.dart';
import '../widgets/quick_actions_grid.dart';
import '../widgets/todays_reading_card.dart';
import '../widgets/upcoming_events_section.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.surfaceDark,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.orange,
          onRefresh: () async {
            ref.invalidate(sermonsProvider);
            ref.invalidate(upcomingEventsProvider(null));
            ref.invalidate(dailyContentProvider);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.xl,
            ),
            child: const Column(
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
                TodaysReadingCard(),
                SizedBox(height: AppSpacing.xxl),
                UpcomingEventsSection(),
                SizedBox(height: AppSpacing.xxl),
                DailyPrayerCard(),
                SizedBox(height: AppSpacing.xl),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
