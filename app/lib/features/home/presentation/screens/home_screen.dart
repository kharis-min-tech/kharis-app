import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/shared/providers/sermon_provider.dart';
import '../widgets/todays_reading_card.dart';
import '../widgets/latest_message_card.dart';
import '../widgets/news_section.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.surfaceDark,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.accent,
          onRefresh: () async {
            ref.invalidate(sermonsProvider);
            ref.invalidate(dailyContentProvider);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Dove logo header - centered, ~40px
                Padding(
                  padding: const EdgeInsets.only(top: 24, bottom: 20),
                  child: Center(
                    child: Image.asset(
                      'assets/figma/dove_logo.png',
                      height: 44,
                      color: Colors.white,
                    ),
                  ),
                ),
                // Today's reading pill
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  child: TodaysReadingCard(),
                ),
                const SizedBox(height: AppSpacing.lg),
                // Latest Message section
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  child: LatestMessageCard(),
                ),
                const SizedBox(height: AppSpacing.xxl),
                // News & Updates
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  child: NewsSection(),
                ),
                const SizedBox(height: AppSpacing.xxxl),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

