import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:kharis_app/features/feedback/presentation/review_prompt_listener.dart';
import 'package:kharis_app/shared/providers/audio_provider.dart';
import 'package:kharis_app/features/player/presentation/widgets/mini_player.dart';
import 'package:kharis_app/shared/providers/auth_provider.dart';
import 'package:kharis_app/shared/providers/branch_provider.dart';
import 'package:kharis_app/shared/providers/cache_provider.dart';
import 'package:kharis_app/shared/models/sermon.dart';
import 'package:kharis_app/shared/providers/sermon_provider.dart';
import 'package:kharis_app/shared/widgets/branch_picker_sheet.dart';
import 'package:kharis_app/ui/components/components.dart';

/// The shell around the four tabs: Home, Messages, Bible, More.
///
/// Uses [StatefulNavigationShell] from [StatefulShellRoute.indexedStack] so
/// every branch gets its own navigator and state is preserved between tab
/// switches. The floating nav, with the mini player above it while a message
/// is loaded, sits in a [Stack] over the page ([DashboardNavFrame]); pages
/// pad their own scrolling content with `KSize.contentBottomPad`. Pages
/// pushed above the shell keep the same nav through [WithTabNav].
class DashboardShell extends ConsumerStatefulWidget {
  const DashboardShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<DashboardShell> createState() => _DashboardShellState();
}

/// The tabs in nav order; index i opens `kTabPaths[i]`.
const List<KNavItem> kDashboardTabs = [
  KNavItem(label: 'Home', icon: KIcons.home),
  KNavItem(label: 'Messages', icon: KIcons.messages),
  KNavItem(label: 'Bible', icon: KIcons.bible),
  KNavItem(label: 'More', icon: KIcons.more),
];

/// Above this width the nav and mini player are centred at
/// [KSize.maxContentWidth].
const double _wideLayout = 600;

/// Whether this launch has already offered the branch picker. Lives in the
/// app's [ProviderScope], so it resets on the next launch and not when the
/// shell is rebuilt (sign-in, deep links).
final branchPromptShownProvider = StateProvider<bool>((ref) => false);

/// How many modal sheets are open on the navigators watched by a
/// [SheetObserver]. The shell hides the nav and mini player while it is
/// above zero.
final openSheetsProvider = Provider<ValueNotifier<int>>((ref) {
  final open = ValueNotifier<int>(0);
  ref.onDispose(open.dispose);
  return open;
});

/// The tab shell while it is mounted, so a page pushed above it can show the
/// nav with the tab the member came from ([WithTabNav]).
class ActiveTabShell {
  StatefulNavigationShell? shell;
}

final activeTabShellProvider = Provider<ActiveTabShell>(
  (ref) => ActiveTabShell(),
);

/// Opens tab [index] from the nav and remembers it for the next launch.
///
/// With the tab shell underneath ([shell]) it switches branch the way the
/// shell does: the tab already highlighted returns to its root, another tab
/// comes back as the member left it, and pages pushed above the shell close
/// either way. Without a shell (a deep link opened the page on its own) it
/// goes to the tab's root.
void openDashboardTab(
  WidgetRef ref,
  GoRouter? router,
  StatefulNavigationShell? shell,
  int index,
) {
  if (shell != null) {
    shell.goBranch(index, initialLocation: index == shell.currentIndex);
  } else {
    router?.go(kTabPaths[index]);
  }
  ref.read(cacheServiceProvider).cachePreference(kLastTabKey, kTabPaths[index]);
}

/// Counts modal bottom sheets (and dialogs: a sheet under Reduce Motion is
/// one) as they open and close on one navigator.
/// A navigator observer serves a single navigator: create one per navigator
/// (the root and each tab branch), all sharing [openSheetsProvider]'s count.
class SheetObserver extends NavigatorObserver {
  SheetObserver(this._open);

  final ValueNotifier<int> _open;

  void _changed(Route<dynamic>? route, int by) {
    // With Reduce Motion on, a sheet opens as a dialog route.
    if (route is ModalBottomSheetRoute || route is RawDialogRoute) {
      _open.value += by;
    }
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _changed(route, 1);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _changed(route, -1);

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _changed(route, -1);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _changed(oldRoute, -1);
    _changed(newRoute, 1);
  }
}

class _DashboardShellState extends ConsumerState<DashboardShell> {
  late final ActiveTabShell _active;

  @override
  void initState() {
    super.initState();
    _active = ref.read(activeTabShellProvider)..shell = widget.navigationShell;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _restoreMiniPlayer();
      _promptBranchOnce();
      // Rating/feedback prompts are scheduled by ReviewPromptListener (end
      // of a listen), never on launch.
    });
  }

  @override
  void didUpdateWidget(DashboardShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    _active.shell = widget.navigationShell;
  }

  @override
  void dispose() {
    // A replacement shell may already have registered itself.
    if (identical(_active.shell, widget.navigationShell)) _active.shell = null;
    super.dispose();
  }

  /// While the member has not chosen a branch, offer the picker once per
  /// launch. Dismissable: Home meanwhile shows [homeBranchProvider]'s
  /// branch, and the chip keeps saying "Choose your branch".
  void _promptBranchOnce() {
    if (ref.read(branchPromptShownProvider)) return;
    // Decide once the branch has resolved, so a member whose profile has yet
    // to answer is not asked by mistake. A reload (the branch just picked in
    // onboarding, or the anonymous session landing) carries the value from
    // before it as a stale "no branch", so it waits for the fresh one too.
    // Closed with the shell if it never resolves.
    ProviderSubscription<AsyncValue<String?>>? sub;
    var resolved = false;
    sub = ref.listenManual<AsyncValue<String?>>(currentBranchProvider, (
      _,
      next,
    ) {
      if (resolved || next.isLoading) return;
      resolved = true;
      // Null while this fires immediately; closed just below instead.
      sub?.close();
      if (!mounted || next.valueOrNull != null) return;
      if (ref.read(branchPromptShownProvider)) return;
      ref.read(branchPromptShownProvider.notifier).state = true;
      unawaited(pickActiveBranch(context, ref));
    }, fireImmediately: true);
    if (resolved) sub.close();
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

  /// Whether the Give screen is the route on top.
  bool _giving() {
    final stack = GoRouter.of(
      context,
    ).routerDelegate.currentConfiguration.matches;
    return stack.isNotEmpty &&
        Uri.parse(stack.last.matchedLocation).path == '/give';
  }

  @override
  Widget build(BuildContext context) {
    final shell = widget.navigationShell;
    return ReviewPromptListener(
      // Never interrupt a member mid-gift.
      canInterrupt: () => !_giving(),
      child: DashboardNavFrame(
        currentIndex: shell.currentIndex,
        onTap: (index) =>
            openDashboardTab(ref, GoRouter.of(context), shell, index),
        child: shell,
      ),
    );
  }
}

/// A page pushed above the tab shell, with the shell's nav over it.
///
/// The tab the member came from stays highlighted (Home when a deep link
/// opened the page with no tab underneath). Tapping another tab goes there;
/// tapping the highlighted one returns to its root. Back and swipe-back
/// still leave just this page.
class WithTabNav extends ConsumerWidget {
  const WithTabNav({
    super.key,
    this.showMiniPlayer = true,
    required this.child,
  });

  /// False where the mini player would crowd the page (Give, KA-001).
  final bool showMiniPlayer;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = GoRouter.maybeOf(context);
    final overShell =
        router?.routerDelegate.currentConfiguration.matches.any(
          (m) => m is ShellRouteMatch,
        ) ??
        false;
    final shell = overShell ? ref.read(activeTabShellProvider).shell : null;
    return DashboardNavFrame(
      currentIndex: shell?.currentIndex ?? 0,
      showMiniPlayer: showMiniPlayer,
      onTap: (index) {
        // A page pushed straight onto the navigator, without a route of its
        // own, stays above the shell when the router moves: close it first.
        Navigator.of(context).popUntil((route) => route.settings is Page);
        openDashboardTab(ref, router, shell, index);
      },
      child: child,
    );
  }
}

/// [child] with the floating nav over it, and the mini player above the nav
/// while a message is loaded (unless [showMiniPlayer] is false). Both step
/// out of the way while a sheet is open or the keyboard is up.
class DashboardNavFrame extends ConsumerStatefulWidget {
  const DashboardNavFrame({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.showMiniPlayer = true,
    required this.child,
  });

  /// The highlighted tab, an index into [kDashboardTabs].
  final int currentIndex;
  final ValueChanged<int> onTap;
  final bool showMiniPlayer;
  final Widget child;

  @override
  ConsumerState<DashboardNavFrame> createState() => _DashboardNavFrameState();
}

class _DashboardNavFrameState extends ConsumerState<DashboardNavFrame> {
  late final ValueNotifier<int> _openSheets;

  @override
  void initState() {
    super.initState();
    _openSheets = ref.read(openSheetsProvider)..addListener(_onSheetsChanged);
  }

  @override
  void dispose() {
    _openSheets.removeListener(_onSheetsChanged);
    super.dispose();
  }

  /// A navigator can report a route change while the tree is building;
  /// rebuild after that frame instead of during it.
  void _onSheetsChanged() {
    void rebuild() {
      if (mounted) setState(() {});
    }

    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) => rebuild());
    } else {
      rebuild();
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentSermon = ref.watch(currentSermonProvider);
    // Out of the way while a sheet is open or the member is typing.
    final hidden =
        _openSheets.value > 0 || MediaQuery.viewInsetsOf(context).bottom > 0;
    final wide = MediaQuery.sizeOf(context).width > _wideLayout;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: widget.child),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Visibility(
              visible: !hidden,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: wide ? KSize.maxContentWidth : double.infinity,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (widget.showMiniPlayer && currentSermon != null)
                        const Padding(
                          padding: EdgeInsets.fromLTRB(
                            KSize.navInsetX,
                            0,
                            KSize.navInsetX,
                            KSpace.md,
                          ),
                          child: MiniPlayer(),
                        ),
                      KFloatingNav(
                        key: const Key('dashboard-nav'),
                        items: kDashboardTabs,
                        currentIndex: widget.currentIndex,
                        onTap: widget.onTap,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
