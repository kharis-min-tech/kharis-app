import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kharis_app/shared/models/campus_config.dart';
import 'package:kharis_app/shared/providers/campus_config_provider.dart';
import 'package:kharis_app/shared/providers/moments_provider.dart';
import 'package:kharis_app/shared/providers/notification_feed_provider.dart';
import 'package:kharis_app/shared/providers/sermon_provider.dart';
import 'package:kharis_app/ui/components/components.dart';

import '../widgets/daily_message_card.dart';
import '../widgets/home_branch_news.dart';
import '../widgets/home_continue_listening.dart';
import '../widgets/home_give_card.dart';
import '../widgets/home_hero.dart';
import '../widgets/home_moments.dart';
import '../widgets/home_stats_strip.dart';
import '../widgets/home_this_week.dart';
import '../widgets/live_now_card.dart';

/// How far the stats strip rides up over the bottom of the hero.
const double _stripOverlap = KSpace.section + KSpace.lg;

const EdgeInsets _gutter = EdgeInsets.symmetric(horizontal: KSpace.gutter);

/// Home tab, top to bottom: the "New from Sunday" hero on ink (greeting,
/// branch switcher, bell, avatar, the newest message), the stats strip over
/// its bottom edge (today's reading and the two streaks), the live stream
/// and the Daily Message when there is one, the branch's news and this
/// week's events, Continue listening, Moments and the Give card.
///
/// The order is fixed. A block the branch's Studio layout switches off
/// stays off (the Give card always shows: Home is the way into giving);
/// blocks with nothing to show render nothing, spacing included.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _scroll = ScrollController();
  final _heroKey = GlobalKey();

  /// The hero's ink still lies under the status bar.
  bool _heroUnderStatusBar = true;

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
    final hero = _heroKey.currentContext?.size?.height;
    if (hero == null) return;
    final under =
        _scroll.offset <
        hero - _stripOverlap - MediaQuery.paddingOf(context).top;
    if (under != _heroUnderStatusBar) {
      setState(() => _heroUnderStatusBar = under);
    }
  }

  /// Pull-to-refresh reloads everything Home shows and holds the spinner
  /// until it has all answered: today's reading and message, the branch's
  /// announcements and events, Moments, and the branch settings (branches
  /// with their services, and the live stream).
  Future<void> _refresh() {
    ref
      ..invalidate(dailyContentProvider)
      ..invalidate(dailyMessageProvider);
    return Future.wait<void>([
      settleRefresh(ref.refresh(dailyContentProvider.future)),
      settleRefresh(ref.refresh(dailyMessageProvider.future)),
      settleRefresh(ref.refresh(momentsProvider.future)),
      refreshCampusContent(ref),
      refreshCampusConfig(ref),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    // The branch's own Studio layout can switch a block off; one it does
    // not mention shows.
    final sections = ref.watch(currentCampusProvider)?.home?.sections;
    bool shows(HomeSectionId id) =>
        sections == null || !sections.any((s) => s.id == id && !s.enabled);

    final hasNews =
        shows(HomeSectionId.announcements) &&
        (ref.watch(campusNewsProvider).valueOrNull?.isNotEmpty ?? false);
    final showEvents = shows(HomeSectionId.events);

    // Light status-bar icons over the hero's ink; the theme's own once it
    // has scrolled away.
    final lightIcons = _heroUnderStatusBar || context.isDarkTheme;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: lightIcons
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: k.bg,
        body: Stack(
          children: [
            RefreshIndicator(
              color: k.primaryText,
              backgroundColor: k.surface,
              edgeOffset: MediaQuery.paddingOf(context).top,
              onRefresh: _refresh,
              child: CustomScrollView(
                controller: _scroll,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  // Full-bleed from the very top, under the status bar.
                  SliverToBoxAdapter(
                    child: HomeHero(
                      key: _heroKey,
                      bottomInset: _stripOverlap,
                    ),
                  ),
                  SliverToBoxAdapter(
                    // Everything under the hero rides up with the strip.
                    child: Transform.translate(
                      offset: const Offset(0, -_stripOverlap),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxWidth: KSize.maxContentWidth,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: KSpace.x3,
                                ),
                                child: HomeStatsStrip(
                                  key: const Key('home-stats'),
                                  showReading: shows(HomeSectionId.reading),
                                ),
                              ),
                              if (shows(HomeSectionId.live))
                                const LiveNowCard(
                                  padding: EdgeInsets.fromLTRB(
                                    KSpace.gutter,
                                    KSpace.x3,
                                    KSpace.gutter,
                                    0,
                                  ),
                                ),
                              if (shows(HomeSectionId.reading))
                                const DailyMessageCard(
                                  padding: EdgeInsets.fromLTRB(
                                    KSpace.gutter,
                                    KSpace.x3,
                                    KSpace.gutter,
                                    0,
                                  ),
                                ),
                              if (hasNews || showEvents) ...[
                                const SizedBox(height: KSpace.sectionTop),
                                const Padding(
                                  padding: _gutter,
                                  child: _BranchHeader(),
                                ),
                                if (hasNews) ...[
                                  const SizedBox(height: KSpace.xl),
                                  const HomeBranchNews(),
                                ],
                                if (showEvents) ...[
                                  const SizedBox(height: KSpace.x3),
                                  const Padding(
                                    padding: _gutter,
                                    child: HomeThisWeek(),
                                  ),
                                ],
                              ],
                              if (shows(HomeSectionId.continueListening))
                                const HomeContinueListening(
                                  padding: EdgeInsets.fromLTRB(
                                    KSpace.gutter,
                                    KSpace.sectionTop,
                                    KSpace.gutter,
                                    0,
                                  ),
                                ),
                              const HomeMoments(
                                padding: EdgeInsets.only(
                                  top: KSpace.sectionTop,
                                ),
                              ),
                              const Padding(
                                padding: EdgeInsets.fromLTRB(
                                  KSpace.gutter,
                                  KSpace.sectionTop,
                                  KSpace.gutter,
                                  0,
                                ),
                                child: HomeGiveCard(),
                              ),
                              // Clears the mini player and the floating
                              // nav, less the ride up over the hero.
                              const SizedBox(
                                height: KSize.contentBottomPad - _stripOverlap,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Solid backing behind the status bar once the hero has left
            // it, so the page never shows through under the clock.
            if (!_heroUnderStatusBar)
              Positioned(
                key: const Key('home-status-bar-backing'),
                top: 0,
                left: 0,
                right: 0,
                height: MediaQuery.paddingOf(context).top,
                child: ColoredBox(color: k.bg),
              ),
          ],
        ),
      ),
    );
  }
}

/// The branch's name over "Your branch · news and what's on": the heading
/// for its announcements and this week's events.
class _BranchHeader extends ConsumerWidget {
  const _BranchHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final k = context.k;
    final branch = ref.watch(homeBranchProvider).valueOrNull;

    return Column(
      key: const Key('home-branch-header'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          header: true,
          child: Text(
            branch ?? 'Your branch',
            style: KharisText.section.copyWith(color: k.text),
          ),
        ),
        const SizedBox(height: KSpace.xxs),
        Text(
          branch == null
              ? 'News and what\u2019s on'
              : 'Your branch \u00b7 news and what\u2019s on',
          style: KharisText.meta.copyWith(color: k.muted),
        ),
      ],
    );
  }
}
