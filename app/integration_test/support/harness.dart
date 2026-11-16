import 'dart:async';

// Shared harness for the on-device journeys in integration_test/e2e_test.dart.
//
// Every journey is its own `testWidgets`, so one failing journey never stops
// the next. Each journey launches the real app ([KharisApp]) in a fresh
// [ProviderContainer] after resetting the device-side state it depends on,
// and reports one machine-readable line the runner turns into its summary:
//
//   KJOURNEY:<id>:PASS|FAIL|SKIP:<duration ms>:<reason or failures>
//   KSHOT:<id>-<name>   host screenshot (the frame is held ~2 s)
//   KCHECK:ok|FAIL:<id>:<what>   every soft assertion
//   KNOTE:<id>:<what>   data and harness notes (empty live data, stubs used)

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kharis_app/core/configs/app_startup.dart';
import 'package:kharis_app/core/services/app_router.dart';
import 'package:kharis_app/core/services/cache_service.dart';
import 'package:kharis_app/features/player/data/kharis_audio_handler.dart';
import 'package:kharis_app/main.dart';
import 'package:kharis_app/shared/providers/audio_provider.dart';
import 'package:kharis_app/shared/providers/cache_provider.dart';
import 'package:kharis_app/shared/providers/campus_config_provider.dart'
    show kDefaultHomeBranch;
import 'package:kharis_app/shared/providers/notification_provider.dart';
import 'package:kharis_app/shared/providers/onboarding_provider.dart';
import 'package:kharis_app/shared/providers/sermon_provider.dart';

import 'channels.dart';

// ── Run configuration (passed by scripts/run_e2e.sh) ─────────────────────────

/// Comma-separated journey ids to run; empty runs every journey.
const _journeysDefine = String.fromEnvironment('JOURNEYS');

/// Seed for the run's random choices (branch, book, message). The runner
/// passes the date (YYYYMMDD) so one day's runs repeat and the next day's
/// differ; it is logged so a failure can be replayed.
const int runSeed = int.fromEnvironment('E2E_SEED', defaultValue: 0);

/// `version:` line of pubspec.yaml, e.g. `1.0.0+1`.
const String pubspecVersion = String.fromEnvironment('PUBSPEC_VERSION');

bool journeySelected(String id) {
  final wanted = _journeysDefine
      .split(',')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toSet();
  return wanted.isEmpty || wanted.contains(id);
}

int get effectiveSeed {
  if (runSeed != 0) return runSeed;
  final now = DateTime.now();
  return now.year * 10000 + now.month * 100 + now.day;
}

// ── Pump helpers ─────────────────────────────────────────────────────────────

/// Real wall-clock pump: the app keeps animating and streaming, so
/// pumpAndSettle never settles.
Future<void> pumpFor(WidgetTester tester, Duration duration) async {
  final end = DateTime.now().add(duration);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Pumps until [condition] holds; false on timeout.
Future<bool> pumpUntil(
  WidgetTester tester,
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 30),
  Duration step = const Duration(milliseconds: 200),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(step);
    if (condition()) return true;
  }
  return condition();
}

/// Pumps until [finder] matches; throws (aborting the journey) on timeout.
Future<void> pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 45),
  String? reason,
}) async {
  final ok = await pumpUntil(
    tester,
    () => finder.evaluate().isNotEmpty,
    timeout: timeout,
  );
  if (!ok) {
    throw TestFailure(
      'Timed out after ${timeout.inSeconds}s waiting for $finder'
      '${reason == null ? '' : ' ($reason)'}',
    );
  }
}

/// Pumps until one of [finders] matches; returns the winner's index.
Future<int> pumpUntilAny(
  WidgetTester tester,
  List<Finder> finders, {
  Duration timeout = const Duration(seconds: 60),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 200));
    for (var i = 0; i < finders.length; i++) {
      if (finders[i].evaluate().isNotEmpty) return i;
    }
  }
  throw TestFailure('Timed out waiting for any of: $finders');
}

/// Drags [scrollable] by [step] until [finder] is built, then brings it on
/// screen.
Future<void> scrollUntilFound(
  WidgetTester tester,
  Finder finder, {
  required Finder scrollable,
  Offset step = const Offset(0, -200),
  Duration timeout = const Duration(seconds: 45),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 150));
    if (finder.evaluate().isNotEmpty) {
      try {
        await tester.ensureVisible(finder.first);
      } on FlutterError {
        // Sliver children can reject ensureVisible; the match stands.
      }
      await tester.pump(const Duration(milliseconds: 300));
      return;
    }
    if (scrollable.evaluate().isNotEmpty) {
      await tester.drag(scrollable.first, step, warnIfMissed: false);
    }
  }
  throw TestFailure('Timed out scrolling for $finder');
}

/// The app's four tabs: nav label to shell path.
const navTabs = <String, String>{
  'Home': '/home',
  'Messages': '/messages',
  'Bible': '/bible',
  'More': '/more',
};

/// The floating nav: on the tab shell and on every page pushed above it.
final Finder _floatingNav = find.byKey(const Key('dashboard-nav'));

GoRouter appRouter(WidgetTester tester) => ProviderScope.containerOf(
  tester.element(find.byType(MaterialApp)),
  listen: false,
).read(appRouterProvider);

/// Opens the tab labelled [label] (Home, Messages, Bible, More) by tapping
/// it in the floating nav on top (the tab shell's, or a pushed page's; the
/// highlighted tab returns to its root). When a sheet or the keyboard has
/// the nav out of reach, goes to the tab's path through the router instead.
/// Events and Give are not tabs: open them from their real entry points
/// (`openEvents` / `openGive` in actions.dart).
Future<void> tapNav(WidgetTester tester, String label) async {
  final path = navTabs[label];
  if (path == null) throw TestFailure('No tab is labelled "$label"');
  // The page on top paints last; a page underneath keeps its own nav.
  final tab = find
      .descendant(of: _floatingNav, matching: find.text(label))
      .hitTestable();
  if (tab.evaluate().isEmpty) {
    appRouter(tester).go(path);
  } else {
    await tester.tap(tab.last, warnIfMissed: false);
  }
  await pumpFor(tester, const Duration(milliseconds: 700));
}

/// Taps the first match of [finder] after scrolling it into view.
Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await ensureCentred(tester, finder.first);
  await tester.tap(finder.first, warnIfMissed: false);
}

/// Scrolls [finder] to about a third of the way down its scrollable.
/// `WidgetTester.ensureVisible` can leave it at the bottom edge, under the
/// bottom bar or mini player that float over the list on smaller screens,
/// and a tap there lands on the bar instead.
///
/// The scroll is animated and frames only advance when the test pumps, so
/// the animation is started, not awaited: awaiting it before pumping left
/// the journey waiting forever whenever [finder] actually had to move.
Future<void> ensureCentred(WidgetTester tester, Finder finder) async {
  unawaited(
    Scrollable.ensureVisible(
      tester.element(finder),
      alignment: 0.3,
      duration: const Duration(milliseconds: 200),
    ),
  );
  await pumpFor(tester, const Duration(milliseconds: 400));
}

/// The first vertical [Scrollable] under [of] (text fields and horizontal
/// rails have their own Scrollables).
Finder verticalScrollableIn(Finder of) => find
    .descendant(
      of: of,
      matching: find.byWidgetPredicate(
        (w) =>
            w is Scrollable &&
            axisDirectionToAxis(w.axisDirection) == Axis.vertical,
      ),
    )
    .first;

/// Every string currently painted.
List<String> paintedTexts({Finder? within}) => [
  for (final e
      in (within == null
              ? find.byType(RichText)
              : find.descendant(of: within, matching: find.byType(RichText)))
          .evaluate())
    (e.widget as RichText).text.toPlainText(),
];

/// The route on top of the app's root navigator (pages, sheets, dialogs).
Route<dynamic>? topRoute(WidgetTester tester) {
  Route<dynamic>? top;
  appRouter(tester).routerDelegate.navigatorKey.currentState?.popUntil((r) {
    top ??= r;
    return true;
  });
  return top;
}

/// Where the member is: the root navigator's top route (pages, sheets,
/// dialogs) plus the router location (routes inside the tab shell).
String _whereAmI(WidgetTester tester) =>
    '${identityHashCode(topRoute(tester))}|'
    '${appRouter(tester).routerDelegate.currentConfiguration.uri}';

/// Leaves the screen on top the way a member does, since the redesign has
/// no on-screen back buttons: a pushed page by the iOS edge swipe-back; a
/// sheet or dialog (or a page the swipe did not leave) by the system back,
/// as Android's back button does.
Future<void> goBack(WidgetTester tester) async {
  final before = _whereAmI(tester);
  if (topRoute(tester) is PageRoute) {
    final size = tester.view.physicalSize / tester.view.devicePixelRatio;
    final gesture = await tester.startGesture(Offset(4, size.height / 2));
    for (var i = 1; i <= 8; i++) {
      await gesture.moveTo(Offset(4 + size.width * 0.08 * i, size.height / 2));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await pumpFor(tester, const Duration(milliseconds: 800));
    if (_whereAmI(tester) != before) return;
  }
  await tester.binding.handlePopRoute();
  await pumpFor(tester, const Duration(milliseconds: 800));
}

// ── Process-wide bootstrap ───────────────────────────────────────────────────

late SharedPreferences _prefs;
late CacheService _cache;
late KharisAudioHandler _audioHandler;
bool _booted = false;

/// Mirrors lib/main.dart once per process: audio service, Firebase, Hive and
/// SharedPreferences cannot be initialised twice.
Future<void> bootstrapOnce() async {
  if (_booted) return;
  _booted = true;
  _audioHandler = await KharisAudioHandler.init();
  final results = await Future.wait([
    SharedPreferences.getInstance(),
    CacheService.init(),
    AppStartUp().setUp(),
  ]);
  _prefs = results[0] as SharedPreferences;
  _cache = results[1] as CacheService;
  debugPrint('KNOTE:run:seed=$effectiveSeed platform=$defaultTargetPlatform');
}

SharedPreferences get prefs => _prefs;
CacheService get cache => _cache;

// ── Journey bookkeeping ──────────────────────────────────────────────────────

class JourneySkip implements Exception {
  JourneySkip(this.reason);
  final String reason;
}

class Journey {
  Journey(this.id, this.tester);

  final String id;
  final WidgetTester tester;
  final List<String> failures = [];
  final List<String> notes = [];
  ProviderContainer? _container;
  int _shots = 0;

  ProviderContainer get c {
    final container = _container;
    if (container == null) throw StateError('app not launched');
    return container;
  }

  /// Soft assertion: records a failure and keeps going.
  bool check(bool ok, String what) {
    debugPrint('KCHECK:${ok ? 'ok' : 'FAIL'}:$id:$what');
    if (!ok) failures.add(what);
    return ok;
  }

  void note(String what) {
    debugPrint('KNOTE:$id:$what');
    notes.add(what);
  }

  /// Ends the journey as SKIP with [reason] (nothing left to assert).
  Never skip(String reason) => throw JourneySkip(reason);

  /// Host screenshot of the current frame.
  Future<void> shot(String name) async {
    _shots++;
    final file = '${_shots.toString().padLeft(2, '0')}-$name'.replaceAll(
      RegExp(r'[^A-Za-z0-9._-]'),
      '_',
    );
    debugPrint('KSHOT:$id/$file');
    await pumpFor(tester, const Duration(milliseconds: 1800));
  }

  /// Launches the app from a clean slate.
  ///
  /// SharedPreferences are cleared; with [onboarded] the onboarding answers
  /// are written as if the member had finished it ([branch] is a branch
  /// display name; null leaves no branch chosen, so the launch opens the
  /// branch picker). Playback history and the
  /// per-member Hive preferences are cleared so no earlier journey's message
  /// reappears in the mini player. The sermon archive and the Studio content
  /// cache are kept (they are refreshed from the network on every launch).
  Future<void> launch({
    bool onboarded = true,
    String role = 'visitor',
    String? branch = kDefaultHomeBranch,
    List<Override> overrides = const [],
    bool armPermissionGate = false,
  }) async {
    await unmount();
    await _prefs.clear();
    if (onboarded) {
      await _prefs.setBool('onboarding_completed', true);
      await _prefs.setString('onboarding_role', role);
      if (branch != null) await _prefs.setString('onboarding_branch', branch);
    }
    for (final key in const [
      'last_tab',
      'last_sort',
      'last_category',
      'playback_speed',
      'recently_played',
      'recent_sermon_snapshots',
    ]) {
      await Hive.box<dynamic>('preferences').delete(key);
    }
    await Hive.box<dynamic>('playback_positions').clear();
    resetChannelRecords();

    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(_prefs),
        audioHandlerProvider.overrideWithValue(_audioHandler),
        cacheServiceProvider.overrideWithValue(_cache),
        sermonArchiveCacheProvider.overrideWithValue(_cache),
        // FCM handlers registered by NotificationService.init() are never
        // cancelled, so a real init per launch would stack listeners from
        // disposed containers. Only the permission gate is armed, and only
        // for the journey that checks when the app asks.
        notificationInitProvider.overrideWith((ref) async {
          if (armPermissionGate) ref.read(notificationPermissionGateProvider);
        }),
        notificationTopicSyncProvider.overrideWith((ref) {}),
        ...overrides,
      ],
    );
    _container = container;
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const KharisApp()),
    );
    await pumpFor(tester, const Duration(milliseconds: 500));
  }

  /// Stops playback, unmounts the app and disposes its container.
  Future<void> unmount() async {
    final container = _container;
    if (container == null) return;
    _container = null;
    try {
      if (container.exists(audioPlayerServiceProvider)) {
        await container
            .read(audioPlayerServiceProvider)
            .stop()
            .timeout(const Duration(seconds: 5));
      }
    } catch (e) {
      debugPrint('KNOTE:$id:audio stop on teardown failed: $e');
    }
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 200));
    container.dispose();
    // AudioPlayer.dispose runs unawaited in the provider's onDispose; give
    // the platform side a moment before the next launch creates a player.
    await Future<void>.delayed(const Duration(milliseconds: 800));
  }

  /// Pops sheets, dialogs and pushed pages, then goes to [location].
  Future<void> resetTo(String location) async {
    final router = c.read(appRouterProvider);
    router.routerDelegate.navigatorKey.currentState?.popUntil(
      (route) => route.settings is Page,
    );
    router.go(location);
    FocusManager.instance.primaryFocus?.unfocus();
    await pumpFor(tester, const Duration(milliseconds: 1200));
  }
}

/// Set once a journey trips a framework invariant (duplicate GlobalKey,
/// build-scope or layout assertions). The element tree of this process is
/// no longer trustworthy, so later journeys report DEFER and the runner
/// starts them again in a fresh process.
bool _treeCorrupted = false;

final _corruption = RegExp(
  r'Duplicate GlobalKey|GlobalKey was used multiple times|wrong build scope|'
  r'_needsLayout|parentDataDirty|debugNeedsLayout|was mutated in',
);

/// Registers journey [id] as its own test. A failure inside [body] is
/// recorded and the journey reported FAIL; the next journey still runs.
void journey(
  String id,
  String description,
  Future<void> Function(Journey j) body, {
  Duration timeout = const Duration(minutes: 15),
}) {
  testWidgets(
    '$id: $description',
    skip: !journeySelected(id),
    timeout: Timeout(timeout),
    (tester) async {
      if (_treeCorrupted) {
        debugPrint(
          'KJOURNEY:$id:DEFER:0:an earlier journey corrupted the widget '
          'tree; rerun in a fresh process',
        );
        return;
      }
      await bootstrapOnce();
      installChannelFakes();
      final j = Journey(id, tester);
      final started = DateTime.now();
      debugPrint('KJOURNEY-BEGIN:$id');

      // Every FlutterError (layout overflow, build exception, image error)
      // during the journey is a finding. The binding's handler is restored
      // before the test ends, as the test framework requires.
      final bindingHandler = FlutterError.onError;
      var dumped = 0;
      FlutterError.onError = (details) {
        final summary = details
            .exceptionAsString()
            .split('\n')
            .where((l) => l.trim().isNotEmpty)
            .take(2)
            .join(' | ');
        j.check(false, 'FlutterError: $summary (${details.context ?? ''})');
        if (_corruption.hasMatch(summary)) _treeCorrupted = true;
        // The full report (stack, widget chain) for the first few, as
        // evidence; later ones repeat as one line.
        FlutterError.dumpErrorToConsole(details, forceReport: dumped++ < 3);
      };

      String? skipReason;
      try {
        await body(j);
      } on JourneySkip catch (s) {
        skipReason = s.reason;
      } catch (e, st) {
        final where = st.toString().split('\n').take(4).join(' <- ');
        j.check(false, 'aborted: ${e.toString().split('\n').first} @ $where');
        try {
          await j.shot('ABORTED');
        } catch (_) {}
      } finally {
        try {
          await j.unmount();
        } catch (e) {
          debugPrint('KNOTE:$id:teardown failed: $e');
        }
        FlutterError.onError = bindingHandler;
      }

      final ms = DateTime.now().difference(started).inMilliseconds;
      final String status;
      final String detail;
      if (j.failures.isNotEmpty) {
        status = 'FAIL';
        detail = j.failures.join(' || ');
      } else if (skipReason != null) {
        status = 'SKIP';
        detail = skipReason;
      } else {
        status = 'PASS';
        detail = '';
      }
      debugPrint('KJOURNEY:$id:$status:$ms:${detail.replaceAll('\n', ' ')}');
      if (j.failures.isNotEmpty) {
        fail('journey $id failed:\n  ${j.failures.join('\n  ')}');
      }
    },
  );
}
