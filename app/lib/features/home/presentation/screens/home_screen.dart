import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kharis_app/core/constants/app_assets.dart';
import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/shared/providers/auth_provider.dart';
import 'package:kharis_app/shared/providers/sermon_provider.dart';
import '../widgets/latest_message_card.dart';
import '../widgets/todays_reading_card.dart';
import '../widgets/campus_card.dart';
import '../widgets/news_section.dart';
import 'notifications_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.lightBg,
      body: RefreshIndicator(
        color: AppColors.secondary,
        backgroundColor: AppColors.cardWhite,
        edgeOffset: MediaQuery.of(context).padding.top,
        onRefresh: () async {
          ref.invalidate(videosProvider);
          ref.invalidate(dailyContentProvider);
          ref.invalidate(newsProvider);
        },
        child: CustomScrollView(
          slivers: [
            // Greeting header
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  MediaQuery.of(context).padding.top + 8,
                  20,
                  18,
                ),
                child: const _HomeHeader(),
              ),
            ),

            // Featured hero sermon
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: LatestMessageCard(),
              ),
            ),

            // Today's reading card
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 28),
                child: TodaysReadingCard(),
              ),
            ),

            // Your campus: venue + service times for the member's branch.
            // Owns its own padding so it collapses to zero height when the
            // member has no branch or the branch has no venue details.
            const SliverToBoxAdapter(child: CampusCard()),

            // "Announcements" section header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                child: Row(
                  children: [
                    Text(
                      'Announcements',
                      style: AppTypography.display(
                        size: 19,
                        weight: FontWeight.w700,
                      ).copyWith(color: AppColors.textPrimary, height: 1),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => context.go('/calendar'),
                      child: Text(
                        'See all',
                        style: AppTypography.ui(
                          size: 12,
                          weight: FontWeight.w600,
                        ).copyWith(color: AppColors.textMutedLight, height: 1),
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

class _HomeHeader extends ConsumerWidget {
  const _HomeHeader();

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    final branch = (user?.branch != null && user!.branch!.isNotEmpty)
        ? user.branch!
        : 'Kharis';
    final name = (user != null && user.displayName.isNotEmpty)
        ? user.displayName
        : 'Welcome';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Brand dove mark
        Image.asset(
          AppAssets.dovePurple,
          width: 34,
          height: 34,
          filterQuality: FilterQuality.medium,
        ),

        const SizedBox(width: 12),

        // Greeting + user name
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${_greeting()}, $branch',
                style: AppTypography.ui(
                  size: 12.5,
                  weight: FontWeight.w500,
                ).copyWith(color: AppColors.textMutedLight, height: 1.1),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                name,
                style: AppTypography.display(
                  size: 22,
                  weight: FontWeight.w700,
                ).copyWith(color: AppColors.textPrimary, height: 1.15),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),

        // Bell button with pink notification dot
        GestureDetector(
          onTap: () => Navigator.of(context, rootNavigator: true).push(
            MaterialPageRoute<void>(
              builder: (_) => const NotificationsScreen(),
            ),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.cardWhite,
                  boxShadow: AppShadows.card,
                ),
                child: const Icon(
                  Icons.notifications_none_rounded,
                  color: AppColors.textPrimary,
                  size: 21,
                ),
              ),
              Positioned(
                top: 2,
                right: 2,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppColors.accentPink,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.cardWhite,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
