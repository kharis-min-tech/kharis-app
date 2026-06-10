import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/shared/providers/sermon_provider.dart';
import '../widgets/todays_reading_card.dart';
import '../widgets/latest_message_card.dart';
import '../widgets/latest_sermons_section.dart';
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
                // LIVE entry point — routes to /live; sits above Latest Message
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  child: _LivePill(),
                ),
                const SizedBox(height: AppSpacing.md),
                // Latest Message section
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  child: LatestMessageCard(),
                ),
                const SizedBox(height: AppSpacing.xxl),
                // Continue Listening
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  child: LatestSermonsSection(),
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

/// Small accent pill that navigates to the live stream screen.
/// Displayed in the Latest Message area of [HomeScreen].
class _LivePill extends StatelessWidget {
  const _LivePill();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/live'),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.red.withValues(alpha: 0.45),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              'LIVE',
              style: GoogleFonts.dmSans(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.red,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
