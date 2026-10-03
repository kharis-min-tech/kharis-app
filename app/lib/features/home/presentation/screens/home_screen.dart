import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kharis_app/core/constants/app_assets.dart';
import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/shared/providers/auth_provider.dart';
import 'package:kharis_app/shared/providers/sermon_provider.dart';
import 'package:kharis_app/shared/providers/notification_feed_provider.dart';
import '../widgets/continue_listening_card.dart';
import '../widgets/latest_message_card.dart';
import '../widgets/todays_reading_card.dart';
import '../widgets/campus_card.dart';
import '../widgets/profile_completion_card.dart';
import '../widgets/news_section.dart';
import '../widgets/upcoming_events_strip.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  /// Pull-to-refresh reloads everything Home shows and holds the spinner
  /// until it has all answered: the sermon library and hero video, today's
  /// reading, and the campus announcements and events.
  Future<void> _refresh(WidgetRef ref) {
    ref.invalidate(dailyContentProvider);
    return Future.wait<void>([
      settleRefresh(ref.read(sermonLibraryProvider.notifier).refresh()),
      settleRefresh(ref.refresh(videosProvider.future)),
      settleRefresh(ref.refresh(dailyContentProvider.future)),
      refreshCampusContent(ref),
    ]);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: RefreshIndicator(
        color: context.kc.accentInk,
        backgroundColor: context.kc.surface,
        edgeOffset: MediaQuery.of(context).padding.top,
        onRefresh: () => _refresh(ref),
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

            // Pick up where you left off. Collapses to nothing (padding
            // included) when there is nothing to resume.
            const SliverToBoxAdapter(
              child: ContinueListeningCard(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 20),
              ),
            ),

            // Today's reading leads the page: it is one of the key reasons
            // members open the app daily (product ask, 19 Aug — KA-009).
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: TodaysReadingCard(),
              ),
            ),

            // Featured hero sermon
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 28),
                child: LatestMessageCard(),
              ),
            ),

            // Your campus: venue + service times for the member's branch.
            // Owns its own padding so it collapses to zero height when the
            // member has no branch or the branch has no venue details.
            // Post-signup nudge: collapses once birthday + phone are set.
            const SliverToBoxAdapter(child: ProfileCompletionCard()),

            const SliverToBoxAdapter(child: CampusCard()),

            // "Announcements" section header
            SliverToBoxAdapter(
              child: _SectionHeader(
                title: 'Announcements',
                actionKey: const Key('home-announcements-see-all'),
                // The full announcements list, pushed so Back returns here.
                // (It used to jump to the Events tab, which is not where
                // announcements live.)
                onSeeAll: () => context.push('/announcements'),
              ),
            ),

            // Announcements carousel (edge-to-edge with left pad)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(left: 20, bottom: 28),
                child: AnnouncementsCarousel(),
              ),
            ),

            // "Upcoming events" for the member's campus.
            SliverToBoxAdapter(
              child: _SectionHeader(
                title: 'Upcoming events',
                actionKey: const Key('home-events-see-all'),
                // Events is a tab: switch to it rather than stacking it.
                onSeeAll: () => context.go('/calendar'),
              ),
            ),
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(left: 20),
                child: UpcomingEventsStrip(),
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

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.onSeeAll,
    this.actionKey,
  });

  final String title;
  final VoidCallback onSeeAll;
  final Key? actionKey;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 8, 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: AppTypography.display(
                size: 19,
                weight: FontWeight.w700,
              ).copyWith(color: context.kc.onBg, height: 1),
            ),
          ),
          TextButton(
            key: actionKey,
            onPressed: onSeeAll,
            style: TextButton.styleFrom(foregroundColor: context.kc.muted),
            child: Text(
              'See all',
              style: AppTypography.ui(
                size: 12.5,
                weight: FontWeight.w600,
              ).copyWith(color: context.kc.muted, height: 1),
            ),
          ),
        ],
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
                ).copyWith(color: context.kc.muted, height: 1.1),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                name,
                style: AppTypography.display(
                  size: 22,
                  weight: FontWeight.w700,
                ).copyWith(color: context.kc.onBg, height: 1.15),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),

        // Bell button with pink notification dot. Same route as a push tap,
        // so Back behaves identically however the feed was reached.
        GestureDetector(
          key: const Key('home-bell'),
          onTap: () => context.push('/notifications'),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: context.kc.surface,
                  boxShadow: AppShadows.card,
                ),
                child: Icon(
                  Icons.notifications_none_rounded,
                  color: context.kc.onBg,
                  size: 21,
                ),
              ),
              // KA-023: the dot only lights when the feed actually holds
              // something the member hasn't dismissed.
              if (ref.watch(hasPendingNotificationsProvider))
                Positioned(
                  key: const Key('home-bell-unread-dot'),
                  top: 2,
                  right: 2,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: AppColors.accentPink,
                      shape: BoxShape.circle,
                      border: Border.all(color: context.kc.surface, width: 1.5),
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
