import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kharis_app/features/home/presentation/widgets/next_service_card.dart';
import 'package:kharis_app/features/home/presentation/widgets/latest_announcement_card.dart';
import 'package:kharis_app/features/home/presentation/widgets/home_bible_row.dart';
import 'package:kharis_app/shared/widgets/reveal_on_scroll.dart';
import 'package:kharis_app/core/constants/app_assets.dart';
import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/shared/models/campus_config.dart';
import 'package:kharis_app/shared/providers/auth_provider.dart';
import 'package:kharis_app/shared/providers/campus_config_provider.dart';
import 'package:kharis_app/shared/providers/sermon_provider.dart';
import 'package:kharis_app/shared/widgets/branch_picker_sheet.dart';
import 'package:kharis_app/shared/providers/branch_provider.dart';
import 'package:kharis_app/shared/providers/notification_feed_provider.dart';
import '../widgets/continue_listening_card.dart';
import '../widgets/giving_shortcut_card.dart';
import '../widgets/live_now_card.dart';
import '../widgets/daily_message_card.dart';
import '../widgets/profile_completion_card.dart';
import '../widgets/home_hero.dart';
import '../widgets/latest_messages_row.dart';
import '../widgets/upcoming_events_strip.dart';

/// Space under a full-width Home block.
const EdgeInsets _blockPadding = EdgeInsets.fromLTRB(20, 0, 20, 24);

/// Home tab: the full-bleed hero ([HomeHero]) with the logo and bell
/// floating over it, then the blocks Content Studio chose for the member's
/// campus ([effectiveHomeLayoutProvider]), in that order. Without hero
/// slides the greeting header leads instead.
///
/// Conditional blocks (profile nudge, live, announcements, continue
/// listening, campus) render nothing, padding included, when they have
/// nothing to show.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _scroll = ScrollController();

  /// The hero's media still lies under the status bar.
  bool _heroUnderStatusBar = true;

  /// Some of the hero's media is still on screen.
  bool _heroInView = true;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    final media = homeHeroMediaHeight(MediaQuery.sizeOf(context));
    final offset = _scroll.offset;
    final under = offset < media - MediaQuery.paddingOf(context).top;
    final inView = offset < media;
    if (under != _heroUnderStatusBar || inView != _heroInView) {
      setState(() {
        _heroUnderStatusBar = under;
        _heroInView = inView;
      });
    }
  }

  /// Pull-to-refresh reloads everything Home shows and holds the spinner
  /// until it has all answered: today's reading and message, the campus
  /// announcements and events, and the branch settings
  /// (branches with services and giving, and the live stream) behind the
  /// layout and the campus card.
  Future<void> _refresh() {
    ref
      ..invalidate(dailyContentProvider)
      ..invalidate(dailyMessageProvider);
    return Future.wait<void>([
      settleRefresh(ref.refresh(dailyContentProvider.future)),
      settleRefresh(ref.refresh(dailyMessageProvider.future)),
      refreshCampusContent(ref),
      refreshCampusConfig(ref),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final sections = ref.watch(effectiveHomeLayoutProvider).visible;
    // Light status-bar icons over the hero's dark wall; the theme's own
    // once it has scrolled away.
    final lightIcons =
        _heroUnderStatusBar || Theme.of(context).brightness == Brightness.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: lightIcons
            ? Brightness.light
            : Brightness.dark,
        statusBarBrightness: lightIcons ? Brightness.dark : Brightness.light,
      ),
      child: Scaffold(
        body: Stack(
          children: [
            RefreshIndicator(
              color: context.kc.accentInk,
              backgroundColor: context.kc.surface,
              edgeOffset: MediaQuery.of(context).padding.top,
              onRefresh: _refresh,
              // Sections below the first screen rise into view once each.
              child: RevealScope(
                scroll: _scroll,
                child: CustomScrollView(
                  controller: _scroll,
                  slivers: [
                    // Full-bleed from the very top, under the status bar.
                    SliverToBoxAdapter(
                      child: HomeHero(
                        key: const Key('home-hero'),
                        inView: _heroInView,
                        scroll: _scroll,
                        topBar: const _HeroTopBar(),
                      ),
                    ),
                    // The greeting straight under the hero's faded bottom:
                    // who and which Branch (tap to change), then the content.
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(20, 4, 20, 20),
                        child: _Greeting(),
                      ),
                    ),

                    // The Studio's blocks in its order; the newest messages
                    // follow Today's reading (or lead when the Studio hides it).
                    if (!sections.contains(HomeSectionId.reading))
                      const SliverToBoxAdapter(
                        child: RevealOnScroll(child: _LatestMessagesBlock()),
                      ),
                    for (final id in sections) ...[
                      SliverToBoxAdapter(
                        key: ValueKey('home-section-${id.name}'),
                        child: RevealOnScroll(child: _HomeSection(id)),
                      ),
                      if (id == HomeSectionId.reading)
                        const SliverToBoxAdapter(
                          child: RevealOnScroll(child: _LatestMessagesBlock()),
                        ),
                    ],

                    // Bottom safe area: 150 clears mini player + tab bar
                    const SliverToBoxAdapter(child: SizedBox(height: 150)),
                  ],
                ),
              ),
            ),
            // Solid backing behind the status bar once the hero has left it,
            // so the list never shows through under the clock.
            if (!_heroUnderStatusBar)
              Positioned(
                key: const Key('home-status-bar-backing'),
                top: 0,
                left: 0,
                right: 0,
                height: MediaQuery.paddingOf(context).top,
                child: ColoredBox(color: context.kc.bg),
              ),
          ],
        ),
      ),
    );
  }
}

/// The Announcements heading and carousel; the whole block, heading
/// included, collapses once the Studio has answered with nothing to show.
class _AnnouncementsBlock extends ConsumerWidget {
  const _AnnouncementsBlock();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The heading only with something under it: the latest announcement.
    final items = ref.watch(campusNewsProvider).valueOrNull;
    if (items == null || items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeader(
          eyebrow: 'News',
          title: 'Announcements',
          actionKey: const Key('home-announcements-see-all'),
          // The full announcements list, pushed so Back returns here.
          onSeeAll: () => context.push('/announcements'),
        ),
        // The newest one; See all lists the rest.
        const LatestAnnouncementCard(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 28),
        ),
      ],
    );
  }
}

/// The newest messages under their heading; collapses, heading included,
/// until there are messages.
class _LatestMessagesBlock extends ConsumerWidget {
  const _LatestMessagesBlock();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The row leads with the message in progress, so it shows with either.
    if (ref.watch(latestSermonsProvider).isEmpty &&
        ref.watch(continueListeningProvider) == null) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeader(
          eyebrow: 'Teachings',
          title: 'Latest messages',
          actionKey: const Key('home-messages-see-all'),
          // Messages is a tab: switch to it rather than stacking it.
          onSeeAll: () => context.go('/messages'),
        ),
        const Padding(
          padding: EdgeInsets.only(bottom: 28),
          child: LatestMessagesRow(),
        ),
      ],
    );
  }
}

/// Upcoming events: the heading and strip, or nothing when Home's branch
/// has no events beyond its weekly services.
class _EventsBlock extends ConsumerWidget {
  const _EventsBlock();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(homeUpcomingEventsProvider).valueOrNull;
    if (events != null && events.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeader(
          eyebrow: 'What\u2019s on',
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
      // The Bible as one row, then the Daily Message when the Studio has
      // one for today.
      HomeSectionId.reading => const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HomeBibleRow(padding: _blockPadding),
          DailyMessageCard(padding: _blockPadding),
        ],
      ),
      HomeSectionId.announcements => const _AnnouncementsBlock(),
      // Hidden, heading included, when nothing is coming up.
      HomeSectionId.events => const _EventsBlock(),
      // The branch's next service (flyer, times, venue, contact); the full
      // timetable is one tap away on the Branch page.
      HomeSectionId.campus => const NextServiceCard(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 28),
      ),
      // Leads the Latest messages row instead (no second copy here).
      HomeSectionId.continueListening => const SizedBox.shrink(),
      HomeSectionId.giving => const Padding(
        padding: _blockPadding,
        child: GivingShortcutCard(),
      ),
    };
  }
}

/// A Home section's heading, set as on the Kharis website: a violet
/// eyebrow ("TEACHINGS"), then the title with its last word in violet
/// ("Latest messages"), and See all at the right.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.eyebrow,
    required this.title,
    required this.onSeeAll,
    this.actionKey,
  });

  final String eyebrow;
  final String title;
  final VoidCallback onSeeAll;
  final Key? actionKey;

  @override
  Widget build(BuildContext context) {
    final kc = context.kc;
    final brand = AppColors.brandInk(Theme.of(context).brightness);
    final split = title.lastIndexOf(' ');
    final lead = split < 0 ? '' : title.substring(0, split + 1);
    final last = split < 0 ? title : title.substring(split + 1);
    final heading = AppTypography.display(
      size: 24,
      weight: FontWeight.w800,
    ).copyWith(color: kc.onBg, height: 1.1);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 12, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  eyebrow.toUpperCase(),
                  style: AppTypography.eyebrow(color: brand),
                ),
                const SizedBox(height: 8),
                Text.rich(
                  TextSpan(
                    style: heading,
                    children: [
                      TextSpan(text: lead),
                      TextSpan(
                        text: last,
                        style: TextStyle(color: brand),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            key: actionKey,
            onPressed: onSeeAll,
            style: TextButton.styleFrom(
              foregroundColor: kc.accentInk,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(48, 44),
            ),
            child: Text(
              'See all',
              style: AppTypography.ui(
                size: 13.5,
                weight: FontWeight.w700,
              ).copyWith(color: brand, height: 1),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

/// The header floating over the hero: the dove mark and the bell, each in
/// a round surface chip so they stay legible on any image without a scrim.
class _HeroTopBar extends StatelessWidget {
  const _HeroTopBar();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Padding(
          padding: const EdgeInsets.all(3),
          child: Container(
            key: const Key('home-hero-logo'),
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: context.kc.surface,
              boxShadow: AppShadows.card,
            ),
            child: Image.asset(
              AppAssets.dovePurple,
              width: 24,
              height: 24,
              filterQuality: FilterQuality.medium,
              semanticLabel: 'Kharis Church',
            ),
          ),
        ),
        const Spacer(),
        const _BellButton(),
      ],
    );
  }
}

/// The greeting (big line), with the member's name only when they have told
/// us one, then their Branch (small line) which opens the Branch picker.
class _Greeting extends ConsumerWidget {
  const _Greeting();

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  /// The account's real first name, or null for the placeholder names the
  /// auth layer gives guests and nameless sign-ins ("Guest", "Member").
  static String? _firstName(String? displayName) {
    final name = displayName?.trim() ?? '';
    if (name.isEmpty || name == 'Guest' || name == 'Member') return null;
    return name.split(RegExp(r'\s+')).first;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    final branch =
        ref.watch(currentBranchProvider).valueOrNull ??
        ((user?.branch?.isNotEmpty ?? false) ? user!.branch : null);
    final firstName = _firstName(user?.displayName);
    final greeting = firstName == null
        ? _greeting()
        : '${_greeting()}, $firstName';
    final kc = context.kc;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          greeting,
          style: AppTypography.display(
            size: 24,
            weight: FontWeight.w700,
          ).copyWith(color: kc.onBg, height: 1.15),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        // The member's Branch; tap to change it.
        Semantics(
          button: true,
          label: 'Branch: ${branch ?? 'none chosen'}. Change',
          excludeSemantics: true,
          child: InkWell(
            key: const Key('home-branch-change'),
            onTap: () => pickActiveBranch(context, ref),
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 36),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.location_on_rounded,
                    size: 15,
                    color: kc.accentInk,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      branch ?? 'Choose your branch',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.ui(
                        size: 13.5,
                        weight: FontWeight.w600,
                      ).copyWith(color: kc.muted, height: 1.1),
                    ),
                  ),
                  Icon(Icons.expand_more_rounded, size: 18, color: kc.muted),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Bell button with pink notification dot. Same route as a push tap, so
/// Back behaves identically however the feed was reached. The 48 px hit
/// area surrounds the 42 px visual circle.
class _BellButton extends ConsumerWidget {
  const _BellButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(hasPendingNotificationsProvider);
    return Semantics(
      button: true,
      label: pending ? 'Notifications, new items' : 'Notifications',
      child: GestureDetector(
        key: const Key('home-bell'),
        behavior: HitTestBehavior.opaque,
        onTap: () => context.push('/notifications'),
        child: Padding(
          padding: const EdgeInsets.all(3),
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
              if (pending)
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
      ),
    );
  }
}
