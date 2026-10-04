import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kharis_app/core/constants/app_assets.dart';
import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/shared/models/campus_config.dart';
import 'package:kharis_app/shared/providers/auth_provider.dart';
import 'package:kharis_app/shared/providers/campus_config_provider.dart';
import 'package:kharis_app/shared/providers/sermon_provider.dart';
import 'package:kharis_app/shared/providers/notification_feed_provider.dart';
import '../widgets/continue_listening_card.dart';
import '../widgets/giving_shortcut_card.dart';
import '../widgets/live_now_card.dart';
import '../widgets/todays_reading_card.dart';
import '../widgets/campus_card.dart';
import '../widgets/profile_completion_card.dart';
import '../widgets/news_section.dart';
import '../widgets/upcoming_events_strip.dart';

/// Space under a full-width Home block.
const EdgeInsets _blockPadding = EdgeInsets.fromLTRB(20, 0, 20, 24);

/// Home tab: the greeting header, then the blocks Content Studio chose for
/// the member's campus ([effectiveHomeLayoutProvider]), in that order.
///
/// Conditional blocks (profile nudge, live, continue listening, campus)
/// render nothing, padding included, when they have nothing to show.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  /// Pull-to-refresh reloads everything Home shows and holds the spinner
  /// until it has all answered: today's reading, the campus announcements and
  /// events, and the campus settings (branches, `config/home`,
  /// `config/giving`) behind the layout and the campus card.
  Future<void> _refresh(WidgetRef ref) {
    ref.invalidate(dailyContentProvider);
    return Future.wait<void>([
      settleRefresh(ref.refresh(dailyContentProvider.future)),
      refreshCampusContent(ref),
      refreshCampusConfig(ref),
    ]);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sections = ref.watch(effectiveHomeLayoutProvider).visible;
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

            for (final id in sections)
              SliverToBoxAdapter(
                key: ValueKey('home-section-${id.id}'),
                child: _HomeSection(id),
              ),

            // Bottom safe area: 150 clears mini player + tab bar
            const SliverToBoxAdapter(child: SizedBox(height: 150)),
          ],
        ),
      ),
    );
  }
}

/// One Home block by its Studio id.
class _HomeSection extends StatelessWidget {
  const _HomeSection(this.id);

  final HomeSectionId id;

  @override
  Widget build(BuildContext context) {
    return switch (id) {
      // Post-signup nudge: owns its padding and collapses once birthday +
      // phone are set.
      HomeSectionId.profileCompletion => const ProfileCompletionCard(),
      HomeSectionId.live => const LiveNowCard(padding: _blockPadding),
      HomeSectionId.reading => const Padding(
        padding: _blockPadding,
        child: TodaysReadingCard(),
      ),
      HomeSectionId.announcements => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionHeader(
            title: 'Announcements',
            actionKey: const Key('home-announcements-see-all'),
            // The full announcements list, pushed so Back returns here.
            onSeeAll: () => context.push('/announcements'),
          ),
          // Edge-to-edge carousel with a left pad.
          const Padding(
            padding: EdgeInsets.only(left: 20, bottom: 28),
            child: AnnouncementsCarousel(),
          ),
        ],
      ),
      HomeSectionId.events => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionHeader(
            title: 'Upcoming events',
            actionKey: const Key('home-events-see-all'),
            // Events is a tab: switch to it rather than stacking it.
            onSeeAll: () => context.go('/calendar'),
          ),
          const Padding(
            padding: EdgeInsets.only(left: 20, bottom: 28),
            child: UpcomingEventsStrip(),
          ),
        ],
      ),
      HomeSectionId.campus => const CampusCard(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 28),
      ),
      HomeSectionId.continueListening => const ContinueListeningCard(
        padding: _blockPadding,
      ),
      HomeSectionId.giving => const Padding(
        padding: _blockPadding,
        child: GivingShortcutCard(),
      ),
    };
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
