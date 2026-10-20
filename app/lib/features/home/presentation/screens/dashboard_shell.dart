import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/features/feedback/presentation/review_prompt_listener.dart';
import 'package:kharis_app/shared/providers/audio_provider.dart';
import 'package:kharis_app/features/player/presentation/widgets/mini_player.dart';
import 'package:kharis_app/shared/providers/branch_provider.dart';
import 'package:kharis_app/shared/providers/cache_provider.dart';
import 'package:kharis_app/shared/providers/onboarding_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kharis_app/shared/models/sermon.dart';
import 'package:kharis_app/shared/providers/sermon_provider.dart';

/// Bottom-nav shell wrapping all 5 dashboard tabs.
///
/// Uses [StatefulNavigationShell] from [StatefulShellRoute.indexedStack] so
/// every branch gets its own navigator and state is preserved between tab
/// switches. The tab bar follows the active theme: a `surface` bar with a
/// `divider` top hairline; the active tab is gold, inactive tabs are muted.
class DashboardShell extends ConsumerStatefulWidget {
  const DashboardShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<DashboardShell> createState() => _DashboardShellState();
}

/// Branch index of the Giving tab (see the tab row below and app_router.dart).
const _givingTabIndex = 2;

class _DashboardShellState extends ConsumerState<DashboardShell> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // Back from the background: the bar is where the member left the app's
    // navigation, never stranded off screen.
    _lifecycle = AppLifecycleListener(onResume: () => _setBarVisible(true));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _restoreMiniPlayer();
      _promptBranchOnce();
      // Rating/feedback prompts are scheduled by ReviewPromptListener (end
      // of a listen), never on launch.
    });
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  /// Accounts created before branch selection became part of onboarding (and
  /// guests from older builds) have no saved branch, so events default to the
  /// all-campus mush the testers flagged. Ask exactly once.
  Future<void> _promptBranchOnce() async {
    // A member who just chose a campus in onboarding (or chose "All
    // campuses") has already answered. Checked synchronously from local
    // prefs: the branch stream can still be empty a second later on a slow
    // device, which used to ask again right after onboarding.
    if (ref.read(onboardingRepositoryProvider).hasBranchChoice) return;
    // Let the branch stream emit before deciding.
    await Future<void>.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    final branch = ref.read(currentBranchProvider).valueOrNull;
    if (branch != null && branch.isNotEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('branch_prompt_shown') ?? false) return;
    await prefs.setBool('branch_prompt_shown', true);
    if (mounted) context.push('/branch-selection');
  }

  /// How long the restore waits for the catalogue to place the last-played
  /// id before settling for the playback-history snapshot.
  static const _restoreLookupTimeout = Duration(seconds: 4);

  /// Restores the minimised player with the last-played sermon (paused at its
  /// saved position) so the user picks up where they left off.
  ///
  /// Works before the archive has hydrated (fresh install, video ids, web
  /// fallback ids): the id is resolved through [sermonByIdProvider], bounded
  /// by [_restoreLookupTimeout], then through the snapshot the player wrote
  /// when the message last played.
  Future<void> _restoreMiniPlayer() async {
    final svc = ref.read(audioPlayerServiceProvider);
    if (svc.currentSermon != null) return;
    final recent = ref.read(cacheServiceProvider).getRecentlyPlayed();
    if (recent.isEmpty) return;
    final sermon = await _resolveRecent(recent.first);
    if (sermon == null || !mounted || svc.currentSermon != null) return;
    await svc.loadPaused(sermon);
  }

  Future<Sermon?> _resolveRecent(String id) async {
    final resolved = Completer<Sermon?>();
    ProviderSubscription<AsyncValue<Sermon?>>? subscription;
    try {
      subscription = ref.listenManual<AsyncValue<Sermon?>>(
        sermonByIdProvider(id),
        (_, next) {
          if (!next.isLoading && !resolved.isCompleted) {
            resolved.complete(next.valueOrNull);
          }
        },
        fireImmediately: true,
      );
    } catch (_) {
      // Catalogue unavailable: the snapshot below still restores.
    }
    Sermon? sermon;
    if (subscription != null) {
      sermon = await resolved.future.timeout(
        _restoreLookupTimeout,
        onTimeout: () => null,
      );
      subscription.close();
    }
    if (sermon != null || !mounted) return sermon;
    for (final snapshot in ref.read(playbackHistoryProvider).snapshots()) {
      if (snapshot.id == id) return snapshot;
    }
    return null;
  }

  void _onTap(int index) {
    _setBarVisible(true);
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
    ref.read(cacheServiceProvider).cachePreference('last_tab', index);
  }

  // ── Hide on scroll ──────────────────────────────────────────────────────────
  //
  // The tab bar (and the mini player docked on it) slides away while the
  // member scrolls a tab's list down and returns on any scroll up, at the
  // top of the list, on a tab tap or route change, when a screen pushed over
  // the shell (the full player, a detail screen) comes or goes, when
  // playback starts, and when the app resumes. It never needs an edge swipe
  // to come back: that is the system home gesture.

  bool _barVisible = true;

  /// Whether the shell's own route was on top at the last check; null before
  /// the first.
  bool? _shellOnTop;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Rebuilds whenever a route is pushed over the shell on the root
    // navigator, or popped off it. Either way the member comes back to a
    // visible bar: reset while covered, so it is already in place as the
    // screen above slides away.
    final onTop = ModalRoute.isCurrentOf(context);
    if (_shellOnTop != null && onTop != _shellOnTop) _barVisible = true;
    _shellOnTop = onTop;
  }

  @override
  void didUpdateWidget(DashboardShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    final before = oldWidget.navigationShell;
    final after = widget.navigationShell;
    if (before.currentIndex != after.currentIndex ||
        before.shellRouteContext.routerState.uri !=
            after.shellRouteContext.routerState.uri) {
      _barVisible = true;
    }
  }

  void _setBarVisible(bool visible) {
    if (visible != _barVisible) setState(() => _barVisible = visible);
  }

  /// Reads the active tab's primary (vertical, outermost) scroll view only;
  /// pagers and carousels inside it are ignored.
  bool _onTabScroll(ScrollNotification n) {
    final metrics = n.metrics;
    if (n.depth != 0 || metrics.axis != Axis.vertical) return false;
    if (n is UserScrollNotification) {
      // Fires as a drag starts, before the offset moves: the direction
      // decides, even at the top.
      switch (n.direction) {
        case ScrollDirection.reverse:
          if (metrics.maxScrollExtent > metrics.minScrollExtent) {
            _setBarVisible(false);
          }
        case ScrollDirection.forward:
          _setBarVisible(true);
        case ScrollDirection.idle:
          break;
      }
    } else if (metrics.pixels <= metrics.minScrollExtent ||
        (metrics.maxScrollExtent > metrics.minScrollExtent &&
            metrics.pixels >= metrics.maxScrollExtent)) {
      // Top or end of the page: nothing more to read in this direction, so
      // the tabs come back. iOS's bounce at the end did this by accident;
      // Android's clamping scroll has no bounce and left the bar hidden.
      _setBarVisible(true);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final currentSermon = ref.watch(currentSermonProvider);
    // A message starting (a new one, or playback resuming from anywhere)
    // shows the mini player along with the bar it docks on.
    ref
      ..listen<Sermon?>(currentSermonProvider, (before, now) {
        if (now != null && now.id != before?.id) _setBarVisible(true);
      })
      ..listen<bool>(
        playerStateProvider.select((s) => s.valueOrNull?.playing ?? false),
        (was, playing) {
          if (playing && !(was ?? false)) _setBarVisible(true);
        },
      );
    final safeBottom = MediaQuery.of(context).padding.bottom;
    // Screen-reader navigation keeps the bar put: a bar that moves out from
    // under the focus is worse than one that takes some room.
    final hidden = !_barVisible && !MediaQuery.accessibleNavigationOf(context);

    return ReviewPromptListener(
      // Never interrupt a member mid-gift.
      canInterrupt: () =>
          widget.navigationShell.currentIndex != _givingTabIndex,
      child: Scaffold(
        extendBody: true,
        body: NotificationListener<ScrollNotification>(
          onNotification: _onTabScroll,
          child: widget.navigationShell,
        ),
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Slides (a paint transform: no relayout) within its own clip;
            // the body shows through, and receives taps, where it was.
            ClipRect(
              child: AnimatedSlide(
                key: const Key('dashboard-bottom-bar'),
                offset: hidden ? const Offset(0, 1) : Offset.zero,
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // The bar docks on every tab except Giving: testers
                    // couldn't push it away there and it crowded the bank
                    // details mid-gift (KA-001). Audio keeps playing — only
                    // the bar hides; any other tab brings it back, and
                    // swipe-down still dismisses it outright.
                    if (currentSermon != null &&
                        widget.navigationShell.currentIndex != _givingTabIndex)
                      const MiniPlayer(),
                    Container(
                      decoration: BoxDecoration(
                        color: context.kc.surface,
                        border: Border(
                          top: BorderSide(color: context.kc.divider, width: 1),
                        ),
                      ),
                      padding: const EdgeInsets.fromLTRB(8, 10, 8, 12),
                      child: Row(
                        children: [
                          _TabItem(
                            icon: Icons.home_outlined,
                            activeIcon: Icons.home,
                            label: 'Home',
                            index: 0,
                            currentIndex: widget.navigationShell.currentIndex,
                            onTap: _onTap,
                          ),
                          _TabItem(
                            icon: Icons.play_circle_outline,
                            activeIcon: Icons.play_circle,
                            label: 'Messages',
                            index: 1,
                            currentIndex: widget.navigationShell.currentIndex,
                            onTap: _onTap,
                          ),
                          _TabItem(
                            icon: Icons.volunteer_activism_outlined,
                            activeIcon: Icons.volunteer_activism,
                            label: 'Giving',
                            index: 2,
                            currentIndex: widget.navigationShell.currentIndex,
                            onTap: _onTap,
                          ),
                          _TabItem(
                            icon: Icons.calendar_today_outlined,
                            activeIcon: Icons.calendar_today,
                            label: 'Events',
                            index: 3,
                            currentIndex: widget.navigationShell.currentIndex,
                            onTap: _onTap,
                          ),
                          _TabItem(
                            icon: Icons.more_horiz,
                            activeIcon: Icons.more_horiz,
                            label: 'More',
                            index: 4,
                            currentIndex: widget.navigationShell.currentIndex,
                            onTap: _onTap,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // The system gesture area stays padded on the bar's surface
            // whether or not the bar is showing.
            if (safeBottom > 0)
              ColoredBox(
                color: context.kc.surface,
                child: SizedBox(height: safeBottom, width: double.infinity),
              ),
          ],
        ),
      ),
    );
  }
}

/// Single tab item: icon 24 on a pill when active + label 11.5px.
/// Active color: `context.kc.accentInk` (gold).
/// Inactive color: `context.kc.muted`.
class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.index,
    required this.currentIndex,
    required this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int index;
  final int currentIndex;
  final void Function(int) onTap;

  @override
  Widget build(BuildContext context) {
    final isActive = index == currentIndex;
    final color = isActive ? context.kc.accentInk : context.kc.muted;

    final reduce = MediaQuery.disableAnimationsOf(context);

    // An equal share of the bar each, so labels never crowd; the active tab
    // sits on a soft pill (flat fill, no glow).
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(index),
        behavior: HitTestBehavior.opaque,
        child: Semantics(
          label: label,
          selected: isActive,
          button: true,
          excludeSemantics: true,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: reduce
                      ? Duration.zero
                      : const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  width: 58,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isActive ? context.kc.chipBg : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Icon(
                    isActive ? activeIcon : icon,
                    size: 24,
                    color: color,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.labelMd.copyWith(
                    fontSize: 11.5,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                    color: color,
                    letterSpacing: 0.1,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
