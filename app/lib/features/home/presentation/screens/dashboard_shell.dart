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
/// is loaded, sits in a [Stack] over the page; pages pad their own scrolling
/// content with `KSize.contentBottomPad`.
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

/// Counts modal bottom sheets as they open and close on one navigator.
/// A navigator observer serves a single navigator: create one per navigator
/// (the root and each tab branch), all sharing [openSheetsProvider]'s count.
class SheetObserver extends NavigatorObserver {
  SheetObserver(this._open);

  final ValueNotifier<int> _open;

  void _changed(Route<dynamic>? route, int by) {
    if (route is ModalBottomSheetRoute) _open.value += by;
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
  late final ValueNotifier<int> _openSheets;

  @override
  void initState() {
    super.initState();
    _openSheets = ref.read(openSheetsProvider)..addListener(_onSheetsChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _restoreMiniPlayer();
      _promptBranchOnce();
      // Rating/feedback prompts are scheduled by ReviewPromptListener (end
      // of a listen), never on launch.
    });
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

  void _onTap(int index) {
    // Tapping the active tab pops it to its root.
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
    ref
        .read(cacheServiceProvider)
        .cachePreference(kLastTabKey, kTabPaths[index]);
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
    final currentSermon = ref.watch(currentSermonProvider);
    // Out of the way while a sheet is open or the member is typing.
    final hidden =
        _openSheets.value > 0 || MediaQuery.viewInsetsOf(context).bottom > 0;
    final wide = MediaQuery.sizeOf(context).width > _wideLayout;

    return ReviewPromptListener(
      // Never interrupt a member mid-gift.
      canInterrupt: () => !_giving(),
      child: Scaffold(
        body: Stack(
          children: [
            Positioned.fill(child: widget.navigationShell),
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
                        if (currentSermon != null)
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
                          currentIndex: widget.navigationShell.currentIndex,
                          onTap: _onTap,
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
    );
  }
}
