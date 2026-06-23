import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/shared/providers/sermon_provider.dart';
import '../widgets/latest_message_card.dart';
import '../widgets/todays_reading_card.dart';
import '../widgets/news_section.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.surfaceDark,
      body: RefreshIndicator(
        color: AppColors.secondary,
        backgroundColor: const Color(0xFF1E1A2E),
        edgeOffset: MediaQuery.of(context).padding.top,
        onRefresh: () async {
          ref.invalidate(videosProvider);
          ref.invalidate(dailyContentProvider);
          ref.invalidate(newsProvider);
        },
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  MediaQuery.of(context).padding.top + 4,
                  20,
                  14,
                ),
                child: const _HomeHeader(),
              ),
            ),

            // Branch chip
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: _BranchChip(branchName: 'Kharis London'),
              ),
            ),

            // "Latest from Kharis" section header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Row(
                  children: [
                    Text(
                      'Latest from Kharis',
                      style: AppTypography.titleMd.copyWith(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: AppColors.heading,
                        letterSpacing: -0.18,
                        height: 1,
                      ),
                    ),
                    const Spacer(),
                    // YouTube badge
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.play_circle_outline_rounded,
                          size: 15,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'YouTube',
                          style: AppTypography.labelMd.copyWith(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textMuted,
                            letterSpacing: 0,
                            height: 1,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Video hero
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 28),
                child: LatestMessageCard(),
              ),
            ),

            // Today's Reading card
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 28),
                child: TodaysReadingCard(),
              ),
            ),

            // "Announcements" section header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                child: Row(
                  children: [
                    Text(
                      'Announcements',
                      style: AppTypography.titleMd.copyWith(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: AppColors.heading,
                        letterSpacing: -0.18,
                        height: 1,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => context.go('/calendar'),
                      child: Text(
                        'See all',
                        style: AppTypography.labelMd.copyWith(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMuted,
                          letterSpacing: 0,
                          height: 1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Announcements carousel (edge-to-edge with left pad)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(left: 20),
                child: AnnouncementsCarousel(),
              ),
            ),

            // Bottom safe area: 150 clears mini player + tab bar
            const SliverToBoxAdapter(child: SizedBox(height: 150)),
          ],
        ),
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _HomeHeader extends StatelessWidget {
  const _HomeHeader();

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Avatar
        Container(
          width: 38,
          height: 38,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment(-0.6, -1),
              end: Alignment(0.6, 1),
              colors: [Color(0xFF7C3AED), Color(0xFFD7029A)],
            ),
          ),
          child: Center(
            child: Text(
              'D',
              style: AppTypography.titleMd.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                height: 1,
              ),
            ),
          ),
        ),

        const SizedBox(width: 11),

        // Greeting text
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _greeting(),
                style: AppTypography.labelMd.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textMuted,
                  letterSpacing: 0,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                'Welcome back',
                style: AppTypography.bodySm.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.heading,
                  letterSpacing: 0,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),

        // Search button
        GestureDetector(
          onTap: () => context.push('/home/browse'),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: .06),
            ),
            child: const Icon(
              Icons.search_rounded,
              color: Color(0xFFCFC8D4),
              size: 20,
            ),
          ),
        ),

        const SizedBox(width: 8),

        // Bell button with pink notification dot
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: .06),
              ),
              child: const Icon(
                Icons.notifications_outlined,
                color: Color(0xFFCFC8D4),
                size: 20,
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: AppColors.accentPink,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.surfaceDark,
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Branch chip ───────────────────────────────────────────────────────────────

class _BranchChip extends StatelessWidget {
  const _BranchChip({required this.branchName});

  final String branchName;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0x1AE9C349),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(
          color: const Color(0x38E9C349),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.location_on_rounded,
            size: 13,
            color: AppColors.secondary,
          ),
          const SizedBox(width: 5),
          Text(
            branchName,
            style: AppTypography.labelMd.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.secondary,
              letterSpacing: 0,
              height: 1,
            ),
          ),
          const SizedBox(width: 4),
          const Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 14,
            color: AppColors.secondary,
          ),
        ],
      ),
    );
  }
}
