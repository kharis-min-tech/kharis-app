// feat/app-polish on-device walkthrough, run against the LIVE kharis-church
// backend and the live sermon API. No mocks. The native-channel spies below
// pass every message through to the real platform; they only record calls.
//
// Steps (each prints KSTEP:<id>:PASS|FAIL and takes host screenshots):
//   1 launch       no notification permission request and no rating sheet
//                  before onboarding completes (fresh install)
//   2 onboarding   guest / visitor at the London campus
//   3 home         Today's Reading opens real scripture; announcements and
//                  events render (venue shown where the data has one); both
//                  "See all" destinations open and have a way back
//   4 messages     archive hydrates to the full count; year rail reaches 2014
//                  and 2013; topic counts add up; series filter; search hits
//                  and empty state; featured carousel (or latest when off)
//   5 player       timeline (elapsed / -remaining); Next / Previous; audio ->
//                  video -> audio within 3 s; stop and reopen resumes; note at
//                  the current time; playlist create / add / open from More /
//                  remove / delete
//   6 more         every row opens its destination and comes back; external
//                  links reach url_launcher and the browser; version = pubspec
//   7 giving       no "Build God a House"; Copy bank details -> clipboard +
//                  confirmation; Give securely loads the giving page, closes
//   8 share        player Share opens the OS share sheet (dismissed host-side)
//
// Host coordination (scripts/run_app_polish_walkthrough.sh):
//   KSHOT:<name>   host grabs a screenshot (the test holds the frame ~3 s)
//   KACT:<action>  host performs `foreground` (bring the app back from the
//                  browser) or `dismiss-share` (close the OS share sheet)
//
// Run (from app/):
//   scripts/run_app_polish_walkthrough.sh ios|android

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:just_audio/just_audio.dart' show ProcessingState;
import 'package:just_audio_background/just_audio_background.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kharis_app/core/configs/app_startup.dart';
import 'package:kharis_app/core/constants/api_config.dart';
import 'package:kharis_app/core/constants/bible_books.dart';
import 'package:kharis_app/core/services/app_router.dart';
import 'package:kharis_app/core/services/cache_service.dart';
import 'package:kharis_app/features/calendar/presentation/screens/calendar_screen.dart';
import 'package:kharis_app/features/calendar/presentation/screens/event_detail_screen.dart';
import 'package:kharis_app/features/calendar/presentation/widgets/event_card.dart';
import 'package:kharis_app/features/connect/presentation/screens/new_here_screen.dart';
import 'package:kharis_app/features/connect/presentation/screens/testimony_screen.dart';
import 'package:kharis_app/features/feedback/presentation/feedback_sheet.dart';
import 'package:kharis_app/features/giving/presentation/screens/giving_screen.dart';
import 'package:kharis_app/features/giving/presentation/screens/giving_webview_screen.dart';
import 'package:kharis_app/features/home/presentation/screens/notifications_screen.dart';
import 'package:kharis_app/features/home/presentation/screens/reading_screen.dart';
import 'package:kharis_app/features/home/presentation/widgets/todays_reading_card.dart';
import 'package:kharis_app/features/messages/data/curation_repository.dart';
import 'package:kharis_app/features/messages/presentation/widgets/sermon_list_item.dart';
import 'package:kharis_app/features/home/presentation/widgets/upcoming_events_strip.dart';
import 'package:kharis_app/features/notes/presentation/screens/note_editor_screen.dart';
import 'package:kharis_app/features/notes/presentation/screens/notes_screen.dart';
import 'package:kharis_app/features/notes/presentation/widgets/sermon_notes_sheet.dart';
import 'package:kharis_app/features/onboarding/presentation/screens/branch_selection_screen.dart';
import 'package:kharis_app/features/onboarding/presentation/widgets/branch_tile.dart';
import 'package:kharis_app/features/player/presentation/screens/media_player_screen.dart';
import 'package:kharis_app/features/player/presentation/widgets/media_mode_toggle.dart';
import 'package:kharis_app/features/player/presentation/widgets/mini_player.dart';
import 'package:kharis_app/features/player/presentation/widgets/seek_bar.dart';
import 'package:kharis_app/features/playlists/presentation/screens/playlist_detail_screen.dart';
import 'package:kharis_app/features/playlists/presentation/screens/playlists_screen.dart';
import 'package:kharis_app/features/playlists/presentation/widgets/add_to_playlist_sheet.dart';
import 'package:kharis_app/features/settings/presentation/screens/notifications_settings_screen.dart';
import 'package:kharis_app/features/settings/presentation/screens/settings_screen.dart';
import 'package:kharis_app/main.dart';
import 'package:kharis_app/shared/models/sermon.dart';
import 'package:kharis_app/shared/providers/audio_provider.dart';
import 'package:kharis_app/shared/providers/cache_provider.dart';
import 'package:kharis_app/shared/providers/campus_config_provider.dart';
import 'package:kharis_app/shared/providers/notification_feed_provider.dart';
import 'package:kharis_app/shared/providers/onboarding_provider.dart';
import 'package:kharis_app/shared/providers/auth_provider.dart';
import 'package:kharis_app/shared/providers/notes_provider.dart';
import 'package:kharis_app/shared/providers/sermon_provider.dart';

// ── Run configuration (passed by the runner script) ──────────────────────────

/// `version:` line of pubspec.yaml, e.g. `1.0.0+1`.
const _pubspecVersion = String.fromEnvironment('PUBSPEC_VERSION');

/// Archive size the live API reported when the run was prepared.
const _expectedArchive = int.fromEnvironment(
  'EXPECTED_SERMONS',
  defaultValue: 1489,
);

/// Per-year counts of the live archive for the two oldest years (stable:
/// nothing new is ever published into 2013/2014).
const _expected2014 = int.fromEnvironment('EXPECTED_2014', defaultValue: 74);
const _expected2013 = int.fromEnvironment('EXPECTED_2013', defaultValue: 35);

/// Whether the runner can close the OS share sheet (adb can; a headless iOS
/// simulator takes no synthetic touches).
const _hostCanDismissShare = bool.fromEnvironment(
  'HOST_CAN_DISMISS_SHARE',
  defaultValue: true,
);

// ── Pump helpers (same contract as release_walkthrough_test.dart) ────────────

/// Real wall-clock pump for [duration]: the app keeps animating/streaming.
Future<void> pumpFor(WidgetTester tester, Duration duration) async {
  final end = DateTime.now().add(duration);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Pumps until [finder] matches at least one widget. Network-tolerant
/// replacement for pumpAndSettle (which never settles while video/webview
/// surfaces or streams are active).
Future<void> pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 45),
  String? reason,
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 200));
    if (finder.evaluate().isNotEmpty) return;
  }
  fail(
    'Timed out after ${timeout.inSeconds}s waiting for $finder'
    '${reason == null ? '' : ' ($reason)'}',
  );
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

/// Pumps until one of [finders] matches; returns the index of the winner.
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
  fail('Timed out after ${timeout.inSeconds}s waiting for any of: $finders');
}

/// Drags [scrollable] by [step] until [finder] appears, then brings it fully
/// on screen.
Future<void> scrollUntilFound(
  WidgetTester tester,
  Finder finder, {
  required Finder scrollable,
  Offset step = const Offset(0, -130),
  Duration timeout = const Duration(seconds: 60),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 200));
    if (finder.evaluate().isNotEmpty) {
      try {
        await tester.ensureVisible(finder.first);
      } on FlutterError {
        // Sliver children can reject ensureVisible; the match itself stands.
      }
      await tester.pump(const Duration(milliseconds: 300));
      return;
    }
    if (scrollable.evaluate().isNotEmpty) {
      await tester.drag(scrollable.first, step, warnIfMissed: false);
    }
  }
  fail('Timed out after ${timeout.inSeconds}s scrolling for $finder');
}

/// Taps the bottom-most on-screen match of [label]: the tab-bar item, even
/// when the same word appears in page content above it.
Future<void> tapNav(WidgetTester tester, String label) async {
  final matches = find.text(label);
  await pumpUntilFound(tester, matches, reason: 'tab "$label" not on screen');
  final n = matches.evaluate().length;
  var bestIndex = 0;
  var bestDy = -1.0;
  for (var i = 0; i < n; i++) {
    final dy = tester.getCenter(matches.at(i)).dy;
    if (dy > bestDy) {
      bestDy = dy;
      bestIndex = i;
    }
  }
  await tester.tap(matches.at(bestIndex), warnIfMissed: false);
  await pumpFor(tester, const Duration(milliseconds: 700));
}

/// Signals the host runner to grab a screenshot, then holds the frame long
/// enough for the capture to land on it.
Future<void> hostShot(WidgetTester tester, String name) async {
  debugPrint('KSHOT:$name');
  await pumpFor(tester, const Duration(seconds: 3));
}

/// [hostShot] for moments when the app is not in the foreground (browser,
/// OS share sheet): waits in real time instead of pumping frames, first long
/// enough for the other surface to paint.
Future<void> hostShotBackground(String name) async {
  await Future<void>.delayed(const Duration(seconds: 5));
  debugPrint('KSHOT:$name');
  await Future<void>.delayed(const Duration(seconds: 4));
}

/// Back / close affordances the app uses on pushed surfaces.
final _backIcons = <IconData>{
  Icons.arrow_back,
  Icons.arrow_back_rounded,
  Icons.arrow_back_ios,
  Icons.arrow_back_ios_new,
  Icons.arrow_back_ios_new_rounded,
  Icons.keyboard_arrow_down_rounded,
  Icons.chevron_left_rounded,
  Icons.close,
  Icons.close_rounded,
};

Finder backAffordance() => find.byWidgetPredicate(
  (w) => w is BackButton || (w is Icon && _backIcons.contains(w.icon)),
  description: 'back/close affordance',
);

/// Taps the top-left-most back affordance (the app-bar leading button, never
/// a chevron inside the content such as the reader's version pill).
Future<void> tapBack(WidgetTester tester, {required String reason}) async {
  final candidates = backAffordance();
  expect(candidates, findsWidgets, reason: reason);
  final n = candidates.evaluate().length;
  var best = 0;
  var bestScore = double.infinity;
  for (var i = 0; i < n; i++) {
    final c = tester.getCenter(candidates.at(i));
    final score = c.dy * 10 + c.dx;
    if (score < bestScore) {
      bestScore = score;
      best = i;
    }
  }
  await tester.tap(candidates.at(best), warnIfMissed: false);
  await pumpFor(tester, const Duration(milliseconds: 800));
}

/// Every string currently painted (or, with [includeOffstage], built).
List<String> allTexts({bool includeOffstage = false}) => [
  for (final element
      in find.byType(RichText, skipOffstage: !includeOffstage).evaluate())
    (element.widget as RichText).text.toPlainText(),
];

String _fmt(Duration d) =>
    '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

// ── Native channel spies (pass-through) ──────────────────────────────────────

/// Reads the app's own onboarding flag; set once the app is pumped.
bool Function()? onboardingCompletedProbe;

class NativeCall {
  NativeCall(this.channel, this.method, this.args, this.at)
    : onboardedAtCall = onboardingCompletedProbe?.call();

  final String channel;
  final String method;
  final Object? args;
  final DateTime at;

  /// Whether onboarding was complete when the app made this call (null:
  /// before the app was pumped).
  final bool? onboardedAtCall;
  DateTime? repliedAt;

  /// First string argument (the URL for url_launcher calls).
  String? get firstString {
    final a = args;
    if (a is List) {
      for (final v in a) {
        if (v is String) return v;
      }
    }
    if (a is Map) {
      for (final v in a.values) {
        if (v is String) return v;
      }
    }
    return a is String ? a : null;
  }

  @override
  String toString() => '$method${firstString == null ? '' : '($firstString)'}';
}

final List<NativeCall> nativeCalls = [];

/// Records every outbound message on [channel] and forwards it untouched to
/// the real platform, returning the platform's own reply.
void spyChannel(String channel, {required bool methodCodec}) {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMessageHandler(channel, (ByteData? message) async {
    var method = channel.split('.').last;
    Object? args;
    try {
      if (methodCodec) {
        final call = const StandardMethodCodec().decodeMethodCall(message);
        method = call.method;
        args = call.arguments;
      } else {
        args = const StandardMessageCodec().decodeMessage(message);
      }
    } catch (_) {
      // Custom pigeon types: the call is still recorded, without arguments.
    }
    final call = NativeCall(channel, method, args, DateTime.now());
    nativeCalls.add(call);
    debugPrint('KNATIVE:$channel:$call');
    final reply =
        await (messenger.delegate.send(channel, message) ??
            Future<ByteData?>.value());
    call.repliedAt = DateTime.now();
    debugPrint(
      'KNATIVE-REPLY:$channel:${call.method} after '
      '${call.repliedAt!.difference(call.at).inMilliseconds} ms',
    );
    return reply;
  });
}

const _messagingChannel = 'plugins.flutter.io/firebase_messaging';
const _shareChannel = 'dev.fluttercommunity.plus/share';
const _urlLauncherChannels = [
  'dev.flutter.pigeon.url_launcher_ios.UrlLauncherApi.launchUrl',
  'dev.flutter.pigeon.url_launcher_ios.UrlLauncherApi.openUrlInSafariViewController',
  'dev.flutter.pigeon.url_launcher_android.UrlLauncherApi.launchUrl',
  'dev.flutter.pigeon.url_launcher_android.UrlLauncherApi.openUrlInApp',
];

Iterable<NativeCall> permissionRequests() => nativeCalls.where(
  (c) =>
      c.channel == _messagingChannel && c.method.contains('requestPermission'),
);

Iterable<NativeCall> urlLaunches() =>
    nativeCalls.where((c) => _urlLauncherChannels.contains(c.channel));

/// Waits (real time, no frames) until the platform reports the app resumed.
Future<bool> waitForegrounded({
  Duration timeout = const Duration(seconds: 45),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
      return true;
    }
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }
  return false;
}

// ── Step bookkeeping ─────────────────────────────────────────────────────────

class StepResult {
  StepResult(this.id);
  final String id;
  final List<String> failures = [];
  final List<String> notes = [];
  bool get passed => failures.isEmpty;
}

class Walk {
  Walk(this.tester);

  final WidgetTester tester;
  final List<StepResult> steps = [];
  StepResult? _current;

  StepResult get current => _current!;

  /// Soft assertion: records a failure and keeps the walkthrough going, so
  /// one defect never hides the steps after it.
  bool check(bool ok, String what) {
    debugPrint('KCHECK:${ok ? 'ok' : 'FAIL'}:${current.id}:$what');
    if (!ok) current.failures.add(what);
    return ok;
  }

  void note(String what) {
    debugPrint('KNOTE:${current.id}:$what');
    current.notes.add(what);
  }

  /// Logs (and records) framework exceptions the app threw meanwhile.
  void drainExceptions() {
    Object? e;
    while ((e = tester.takeException()) != null) {
      final text = e.toString().split('\n').take(3).join(' | ');
      check(false, 'framework exception: $text');
    }
  }

  Future<void> step(String id, Future<void> Function() body) async {
    final result = StepResult(id);
    steps.add(result);
    _current = result;
    debugPrint('KSTEP-BEGIN:$id');
    try {
      // lib/main.dart runs the app under runZonedGuarded; mirror that so an
      // uncaught async error is recorded as a finding instead of killing the
      // whole walkthrough, while the step body still sees its own errors.
      final done = Completer<void>();
      runZonedGuarded(
        () async {
          try {
            await body();
            if (!done.isCompleted) done.complete();
          } catch (e, st) {
            if (!done.isCompleted) done.completeError(e, st);
          }
        },
        (error, stack) {
          final where = stack.toString().split('\n').take(3).join(' <- ');
          check(
            false,
            'uncaught async error in the app: '
            '${error.toString().split('\n').first} @ $where',
          );
        },
      );
      await done.future;
    } catch (e, st) {
      final first = st.toString().split('\n').take(6).join(' <- ');
      check(false, 'aborted: ${e.toString().split('\n').first} @ $first');
      try {
        await hostShot(tester, '$id-ABORTED');
      } catch (_) {}
      await recover();
    }
    drainExceptions();
    debugPrint(
      'KSTEP:$id:${result.passed ? 'PASS' : 'FAIL'}'
      '${result.failures.isEmpty ? '' : ':${result.failures.join(' || ')}'}',
    );
  }

  ProviderContainer get container =>
      ProviderScope.containerOf(tester.element(find.byType(KharisApp)));

  /// Clears sheets, dialogs and pushed pages, then lands on Home.
  Future<void> recover() async {
    try {
      await waitForegrounded(timeout: const Duration(seconds: 10));
      final router = container.read(appRouterProvider);
      final nav = router.routerDelegate.navigatorKey.currentState;
      // Pops sheets, dialogs and Navigator.push pages (the player, pushed
      // MaterialPageRoutes); keeps the router's own pages.
      nav?.popUntil((route) => route.settings is Page);
      router.go('/home');
      await pumpFor(tester, const Duration(seconds: 2));
      FocusManager.instance.primaryFocus?.unfocus();
    } catch (e) {
      debugPrint('recover: $e');
    }
  }
}

// ── Player helpers ───────────────────────────────────────────────────────────

Finder get _player => find.byType(MediaPlayerScreen);

Finder inPlayer(Finder f) => find.descendant(of: _player, matching: f);

SeekBar seekBarWidget(WidgetTester tester) =>
    tester.widget<SeekBar>(inPlayer(find.byType(SeekBar)).first);

MediaModeToggle toggleWidget(WidgetTester tester) =>
    tester.widget<MediaModeToggle>(inPlayer(find.byType(MediaModeToggle)));

Future<void> tapMode(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(
      of: find.byType(MediaModeToggle),
      matching: find.text(label),
    ),
    warnIfMissed: false,
  );
}

/// Taps a player action (Notes / Playlist / Share). The action row sits at
/// the bottom of the player's scrollable body, below the fold on a phone.
Future<void> tapPlayerAction(WidgetTester tester, String label) async {
  final target = inPlayer(find.text(label));
  await tester.ensureVisible(target);
  await pumpFor(tester, const Duration(milliseconds: 500));
  await tester.tap(target, warnIfMissed: false);
}

/// The horizontal list currently showing any widget matched by [content],
/// re-resolved on every call so it survives sliver rebuilds and scrolling.
Finder railOf(Finder content, String description) {
  Element? rail;
  for (final hit in content.evaluate()) {
    final scrollables = find
        .ancestor(
          of: find.byElementPredicate((e) => identical(e, hit)),
          matching: find.byWidgetPredicate(
            (w) => w is Scrollable && w.axisDirection == AxisDirection.right,
          ),
        )
        .evaluate();
    if (scrollables.isNotEmpty) {
      rail = scrollables.first;
      break;
    }
  }
  return find.byElementPredicate(
    (e) => rail != null && identical(e, rail),
    description: description,
  );
}

/// Clears the Messages search through its own clear button (the query lives
/// in the field's controller, so setting the provider alone would desync).
Future<void> clearMessagesSearch(WidgetTester tester) async {
  final clear = find.byTooltip('Clear search');
  if (clear.evaluate().isNotEmpty) {
    await tester.tap(clear.first, warnIfMissed: false);
    await pumpFor(tester, const Duration(milliseconds: 500));
  }
  FocusManager.instance.primaryFocus?.unfocus();
  await pumpFor(tester, const Duration(milliseconds: 300));
}

/// Messages tab in its default browse state: no search, no filters, newest
/// first, scrolled to the top.
Future<void> openMessagesReset(
  WidgetTester tester,
  ProviderContainer container,
) async {
  await tapNav(tester, 'Messages');
  await clearMessagesSearch(tester);
  container.read(selectedCategoryProvider.notifier).state = 'All';
  container.read(selectedSeriesProvider.notifier).state = null;
  container.read(selectedArchiveYearProvider.notifier).state = null;
  container.read(sermonSortProvider.notifier).state = SermonSort.newest;
  await pumpFor(tester, const Duration(milliseconds: 500));
  final scroll = find.byType(CustomScrollView).first;
  if (scroll.evaluate().isNotEmpty) {
    await tester.drag(scroll, const Offset(0, 6000), warnIfMissed: false);
    await pumpFor(tester, const Duration(milliseconds: 800));
  }
}

Future<void> closePlayer(WidgetTester tester) async {
  await tester.tap(
    inPlayer(find.byIcon(Icons.keyboard_arrow_down_rounded)).first,
    warnIfMissed: false,
  );
  await pumpUntil(tester, () => _player.evaluate().isEmpty);
  await pumpFor(tester, const Duration(milliseconds: 600));
}

// ── The walkthrough ──────────────────────────────────────────────────────────

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'feat/app-polish walkthrough on device (live backend)',
    timeout: const Timeout(Duration(minutes: 40)),
    (tester) async {
      final walk = Walk(tester);
      ProviderContainer c() => walk.container;

      // Spies go in before anything can talk to the platform.
      spyChannel(_messagingChannel, methodCodec: true);
      spyChannel(_shareChannel, methodCodec: true);
      for (final ch in _urlLauncherChannels) {
        spyChannel(ch, methodCodec: false);
      }

      // ── Bootstrap: mirrors lib/main.dart minus splash/orientation chrome ──
      ApiConfig.warnIfProjectSplit();
      await JustAudioBackground.init(
        androidNotificationChannelId: 'com.kharis.church.channel.audio',
        androidNotificationChannelName: 'Kharis audio playback',
        androidNotificationOngoing: true,
      );
      final results = await Future.wait([
        SharedPreferences.getInstance(),
        CacheService.init(),
        AppStartUp().setUp(),
      ]);
      final prefs = results[0] as SharedPreferences;
      final cacheService = results[1] as CacheService;
      final savedKeys = prefs.getKeys().length;

      onboardingCompletedProbe = () {
        try {
          return walk.container.read(onboardingRepositoryProvider).isCompleted;
        } catch (_) {
          return false;
        }
      };
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            cacheServiceProvider.overrideWithValue(cacheService),
            sermonArchiveCacheProvider.overrideWithValue(cacheService),
          ],
          child: const KharisApp(),
        ),
      );

      final navHome = find.text('Home');

      // ── 1. Launch ───────────────────────────────────────────────────────
      final getStarted = find.text('Get started');
      final branchTitle = find.text('Find your branch');
      await walk.step('1-launch', () async {
        walk.note('saved preference keys at launch: $savedKeys');
        final first = await pumpUntilAny(tester, [
          getStarted,
          branchTitle,
          navHome,
        ]);
        walk.check(first == 0, 'fresh install opens on the welcome screen');
        await hostShot(tester, '1-launch-first-screen');
        // A fresh install must wait on the welcome screen for the member, and
        // must not ask for notifications or a rating meanwhile. Watch for 8 s.
        final watchEnd = DateTime.now().add(const Duration(seconds: 8));
        Duration? leftWelcomeAfter;
        final shown = DateTime.now();
        while (DateTime.now().isBefore(watchEnd)) {
          await tester.pump(const Duration(milliseconds: 200));
          if (leftWelcomeAfter == null && getStarted.evaluate().isEmpty) {
            leftWelcomeAfter = DateTime.now().difference(shown);
          }
        }
        final where = getStarted.evaluate().isNotEmpty
            ? 'welcome'
            : branchTitle.evaluate().isNotEmpty
            ? 'branch selection (pushed over Home)'
            : navHome.evaluate().isNotEmpty
            ? 'Home'
            : 'unknown';
        walk.check(
          leftWelcomeAfter == null,
          'welcome screen waits for the member (left it on its own after '
          '${leftWelcomeAfter?.inMilliseconds} ms; now on $where; '
          'signed-in=${c().read(isAuthenticatedProvider)})',
        );
        walk.check(
          permissionRequests().isEmpty,
          'no notification permission request on launch '
          '(calls: ${permissionRequests().toList()})',
        );
        walk.check(
          find.byType(FeedbackSheet).evaluate().isEmpty,
          'no rating sheet on launch',
        );
        await hostShot(tester, '1-launch-after-8s');
      });

      // ── 2. Onboarding: visitor, London, guest ──────────────────────────
      await walk.step('2-onboarding', () async {
        final visited = <String>[];
        void visit(String screen) {
          if (visited.isEmpty || visited.last != screen) visited.add(screen);
        }

        final visitor = find.text('Visitor');
        final guestButton = find.text('Continue as Guest');
        final londonTile = find
            .descendant(
              of: find.byType(BranchTile),
              matching: find.text('London'),
            )
            .first;
        var londonTapped = false;
        final shots = <String>{};
        Future<void> shotOnce(String name) async {
          if (shots.add(name)) await hostShot(tester, name);
        }

        final deadline = DateTime.now().add(const Duration(seconds: 120));
        while (true) {
          if (DateTime.now().isAfter(deadline)) {
            fail('Timed out finishing onboarding (visited: $visited)');
          }
          final completed = c().read(onboardingRepositoryProvider).isCompleted;
          if (!completed) {
            walk.check(
              permissionRequests().isEmpty,
              'no permission request before onboarding completes',
            );
            walk.check(
              find.byType(FeedbackSheet).evaluate().isEmpty,
              'no rating sheet before onboarding completes',
            );
          }
          // Later screens first: during a route transition the outgoing
          // screen is still on stage, and a second tap on it would land on
          // whatever the incoming screen has at that spot.
          Future<void> tapAndLeave(Finder target) async {
            await tester.tap(target.first, warnIfMissed: false);
            await pumpUntil(
              tester,
              () => target.evaluate().isEmpty,
              timeout: const Duration(seconds: 15),
            );
            await pumpFor(tester, const Duration(milliseconds: 600));
          }

          if (branchTitle.evaluate().isNotEmpty) {
            visit('branch');
            if (!londonTapped) {
              await pumpFor(tester, const Duration(milliseconds: 600));
              await tester.enterText(find.byType(TextField).first, 'London');
              await pumpFor(tester, const Duration(seconds: 1));
              await pumpUntilFound(tester, londonTile, reason: 'London tile');
              await shotOnce('2-branch-london');
              await tester.ensureVisible(londonTile);
              await pumpFor(tester, const Duration(milliseconds: 500));
              await tester.tap(londonTile, warnIfMissed: false);
              londonTapped = true;
            }
          } else if (guestButton.evaluate().isNotEmpty) {
            visit('login');
            await shotOnce('2-login-guest');
            await tapAndLeave(guestButton);
          } else if (visitor.evaluate().isNotEmpty) {
            visit('role');
            await pumpFor(tester, const Duration(milliseconds: 600));
            await shotOnce('2-role-selection');
            await tapAndLeave(visitor);
          } else if (getStarted.evaluate().isNotEmpty) {
            visit('welcome');
            await tapAndLeave(getStarted);
          } else if (navHome.evaluate().isNotEmpty) {
            visit('home');
            if (completed) break;
          }
          await pumpFor(tester, const Duration(milliseconds: 500));
        }
        walk.note('onboarding path: ${visited.join(' -> ')}');
        walk.check(
          visited.take(3).join(',') == 'welcome,role,branch',
          'onboarding runs welcome -> role -> branch (got $visited)',
        );
        await pumpFor(tester, const Duration(seconds: 5));
        final repo = c().read(onboardingRepositoryProvider);
        walk.check(repo.isCompleted, 'onboarding marked complete');
        walk.check(
          repo.selectedRole == 'visitor',
          'role saved as visitor (got ${repo.selectedRole})',
        );
        walk.check(
          repo.selectedBranch == 'London',
          'campus saved as London (got ${repo.selectedBranch})',
        );
        final early = permissionRequests().where(
          (call) => call.onboardedAtCall != true,
        );
        walk.check(
          early.isEmpty,
          'permission requested only once onboarding is complete '
          '(early calls at ${early.map((e) => e.at).toList()})',
        );
        // The other half of the contract: once onboarding is done the app
        // does ask (pre-granted here, so no sheet shows, but the request
        // must reach the platform).
        final asked = await pumpUntil(
          tester,
          () => permissionRequests().any((c) => c.onboardedAtCall == true),
          timeout: const Duration(seconds: 15),
        );
        final init = nativeCalls
            .where((n) => n.method == 'Messaging#getInitialMessage')
            .toList();
        walk.check(
          asked,
          'notification permission requested after onboarding '
          '(requests: ${permissionRequests().length}; getInitialMessage '
          'replied: ${init.map((n) => n.repliedAt != null).toList()})',
        );
        walk.check(
          find.byType(FeedbackSheet).evaluate().isEmpty,
          'no rating sheet on first Home',
        );
        await hostShot(tester, '2-home-after-onboarding');
      });

      // ── 3. Home ────────────────────────────────────────────────────────
      await walk.step('3-home', () async {
        await tapNav(tester, 'Home');
        final homeScroll = find.byType(CustomScrollView).first;
        final readingCard = find.byType(TodaysReadingCard);
        await pumpUntilFound(tester, readingCard);
        final readNow = find.text('Read now');
        final cardState = await pumpUntilAny(tester, [
          readNow,
          find.byKey(const Key('reading-card-error')),
        ], timeout: const Duration(seconds: 45));
        walk.check(cardState == 0, "Today's Reading card loaded (not error)");
        await hostShot(tester, '3-home-reading-card');

        // Reader: real scripture, never an error view.
        if (cardState == 0) {
          final content = c().read(dailyContentProvider).valueOrNull;
          if (content != null) {
            final max = kBibleBooks[content.reading.book];
            walk.check(
              max != null && content.reading.chapter <= max,
              'plan reading is a real chapter: '
              '${content.reading.book} ${content.reading.chapter} '
              '(book has $max)',
            );
            walk.note(
              'reading: ${content.reading.reference} '
              'planDay=${content.planDay}/${content.planDays}',
            );
          }
          await tester.tap(readNow.first, warnIfMissed: false);
          await pumpUntilFound(tester, find.byType(ReadingScreen));
          final reader = find.byType(ReadingScreen);
          await pumpUntil(
            tester,
            () => find
                .descendant(
                  of: reader,
                  matching: find.byType(CircularProgressIndicator),
                )
                .evaluate()
                .isEmpty,
            timeout: const Duration(seconds: 60),
          );
          await pumpFor(tester, const Duration(seconds: 1));
          final readerTexts = [
            for (final e
                in find
                    .descendant(of: reader, matching: find.byType(RichText))
                    .evaluate())
              (e.widget as RichText).text.toPlainText(),
          ];
          final errorShown = readerTexts.any(
            (t) =>
                t.contains('isn\u2019t available') ||
                t.contains('Couldn\u2019t load') ||
                t == 'Retry',
          );
          walk.check(
            !errorShown,
            'reader shows scripture, not an error view '
            '(${readerTexts.where((t) => t.length < 160).take(4).toList()})',
          );
          final scripture = readerTexts
              .where((t) => t.length > 40)
              .fold<int>(0, (n, t) => n + t.length);
          walk.check(
            scripture > 300,
            'reader has verse text ($scripture chars of passage)',
          );
          await hostShot(tester, '3-reader-scripture');
          await tapBack(tester, reason: 'reader needs a way back');
          await pumpUntilFound(
            tester,
            readingCard,
            reason: 'Home after reader',
          );
        }

        // Announcements.
        final seeAllNews = find.byKey(const Key('home-announcements-see-all'));
        await scrollUntilFound(tester, seeAllNews, scrollable: homeScroll);
        final newsSettled = await pumpUntil(
          tester,
          () =>
              c().read(campusNewsProvider).hasValue ||
              c().read(campusNewsProvider).hasError,
          timeout: const Duration(seconds: 45),
        );
        final news = c().read(campusNewsProvider);
        walk.check(newsSettled && !news.hasError, 'announcements loaded');
        final newsItems = news.valueOrNull ?? const [];
        walk.note('campus announcements: ${newsItems.length}');
        if (newsItems.isNotEmpty) {
          walk.check(
            find.text(newsItems.first.title).evaluate().isNotEmpty,
            'first announcement card painted: "${newsItems.first.title}"',
          );
        } else {
          walk.note(
            'DATA: the live London announcements feed is empty '
            '(production news expired); checking the empty state instead',
          );
          walk.check(
            find.text('No announcements').evaluate().isNotEmpty,
            'empty announcements carousel says "No announcements"',
          );
          walk.check(
            find.byKey(const Key('announcements-skeleton')).evaluate().isEmpty,
            'announcements carousel is not stuck on its skeleton',
          );
        }
        await hostShot(tester, '3-home-announcements');
        await tester.tap(seeAllNews, warnIfMissed: false);
        await pumpUntilFound(
          tester,
          find.byType(NotificationsScreen),
          reason: 'Announcements "See all" destination',
        );
        await pumpFor(tester, const Duration(seconds: 2));
        walk.check(
          find.text('Announcements').evaluate().isNotEmpty,
          '"See all" opens the Announcements list',
        );
        if (newsItems.isEmpty) {
          walk.check(
            await pumpUntil(
              tester,
              () =>
                  find
                      .text('No announcements right now')
                      .evaluate()
                      .isNotEmpty &&
                  find
                      .text('News from your branch will show up here.')
                      .evaluate()
                      .isNotEmpty,
              timeout: const Duration(seconds: 15),
            ),
            'empty Announcements list shows its guidance text',
          );
        }
        await hostShot(tester, '3-announcements-see-all');
        await tapBack(tester, reason: 'Announcements list needs a way back');
        walk.check(
          (await pumpUntil(
            tester,
            () =>
                readingCard.evaluate().isNotEmpty ||
                seeAllNews.evaluate().isNotEmpty,
          )),
          'Back from Announcements returns to Home',
        );

        // Upcoming events (+ venue).
        final seeAllEvents = find.byKey(const Key('home-events-see-all'));
        await scrollUntilFound(tester, seeAllEvents, scrollable: homeScroll);
        await tester.drag(
          homeScroll,
          const Offset(0, -200),
          warnIfMissed: false,
        );
        await pumpUntil(
          tester,
          () =>
              c().read(campusUpcomingEventsProvider).hasValue ||
              c().read(campusUpcomingEventsProvider).hasError,
          timeout: const Duration(seconds: 45),
        );
        final eventsAsync = c().read(campusUpcomingEventsProvider);
        walk.check(!eventsAsync.hasError, 'upcoming events loaded');
        final events = eventsAsync.valueOrNull ?? const [];
        walk.note('campus upcoming events: ${events.length}');
        if (events.isEmpty) {
          walk.note(
            'DATA: the live London events feed is empty (no events '
            'authored, website sync not deployed); checking the empty state',
          );
          walk.check(
            find
                .textContaining(RegExp(r'^No upcoming events( at .+)? yet\.$'))
                .evaluate()
                .isNotEmpty,
            'empty events strip says there are no upcoming events '
            '(${allTexts().where((t) => t.startsWith('No upcoming')).toList()})',
          );
          walk.check(
            find.byKey(const Key('events-strip-skeleton')).evaluate().isEmpty,
            'events strip is not stuck on its skeleton',
          );
        }
        await pumpFor(tester, const Duration(seconds: 1));
        Finder inStrip(Finder f) =>
            find.descendant(of: find.byType(UpcomingEventsStrip), matching: f);
        var venueChecked = 0;
        for (final event in events.take(5)) {
          if (inStrip(find.text(event.title)).evaluate().isEmpty) continue;
          final hasVenue = [
            event.location,
            event.address,
          ].any((v) => v != null && v.trim().isNotEmpty);
          if (!hasVenue) continue;
          final place = eventPlaceLabel(event)!;
          walk.check(
            inStrip(find.text(place)).evaluate().isNotEmpty,
            'event "${event.title}" card shows its venue "$place"',
          );
          venueChecked++;
        }
        if (events.isNotEmpty && venueChecked == 0) {
          walk.note('no on-screen event carries a venue in the data');
        }
        await hostShot(tester, '3-home-events');
        if (events.isNotEmpty &&
            inStrip(find.text(events.first.title)).evaluate().isNotEmpty) {
          await tester.tap(
            inStrip(find.text(events.first.title)).first,
            warnIfMissed: false,
          );
          await pumpUntilFound(
            tester,
            find.byType(EventDetailScreen),
            reason: 'event card opens its detail',
          );
          await pumpFor(tester, const Duration(seconds: 2));
          final loc = events.first.location?.trim();
          if (loc != null && loc.isNotEmpty) {
            walk.check(
              allTexts().any((t) => t.contains(loc)),
              'event detail shows the venue "$loc"',
            );
          }
          await hostShot(tester, '3-event-detail');
          await tapBack(tester, reason: 'event detail needs a way back');
          await pumpUntilFound(
            tester,
            seeAllEvents,
            reason: 'Home after event',
          );
        }
        await tester.tap(seeAllEvents, warnIfMissed: false);
        await pumpUntilFound(
          tester,
          find.byType(CalendarScreen),
          reason: 'Events "See all" destination',
        );
        await pumpFor(tester, const Duration(seconds: 2));
        if (events.isEmpty) {
          walk.check(
            await pumpUntil(
              tester,
              () => find.text('No upcoming events').evaluate().isNotEmpty,
              timeout: const Duration(seconds: 20),
            ),
            'empty Events tab says "No upcoming events" with guidance '
            '(${allTexts().where((t) => t.startsWith('Check back')).toList()})',
          );
        }
        await hostShot(tester, '3-events-see-all');
        walk.check(
          navHome.evaluate().isNotEmpty,
          'Events tab keeps the tab bar (way back to Home)',
        );
        await tapNav(tester, 'Home');
        walk.check(
          await pumpUntil(
            tester,
            () => find.byType(CalendarScreen).evaluate().isEmpty,
          ),
          'Home tab returns from Events',
        );
      });

      // ── 4. Messages ────────────────────────────────────────────────────
      await walk.step('4-messages', () async {
        // Clean slate: the topic filter is persisted between launches.
        await openMessagesReset(tester, c());
        final scroll = find.byType(CustomScrollView).first;

        // Hydration of the whole archive.
        final hydrateStart = DateTime.now();
        final hydrated = await pumpUntil(
          tester,
          () {
            final lib = c().read(sermonLibraryProvider);
            return lib.loaded && !lib.hasMore && !lib.hydrating;
          },
          timeout: const Duration(minutes: 5),
          step: const Duration(seconds: 1),
        );
        final lib = c().read(sermonLibraryProvider);
        walk.note(
          'archive: ${lib.sermons.length}/${lib.totalCount} in '
          '${DateTime.now().difference(hydrateStart).inSeconds}s '
          '(fallback=${lib.usedFallback} offline=${lib.offline} '
          'hydrationFailed=${lib.hydrationFailed})',
        );
        walk.check(hydrated, 'archive finished hydrating');
        walk.check(!lib.usedFallback, 'live archive, not the bundled fallback');
        walk.check(
          lib.totalCount == _expectedArchive,
          'server total is $_expectedArchive (got ${lib.totalCount})',
        );
        walk.check(
          lib.sermons.length == _expectedArchive,
          'archive reaches $_expectedArchive (got ${lib.sermons.length})',
        );
        await pumpFor(tester, const Duration(seconds: 2));
        final merged = c().read(sermonsProvider).valueOrNull ?? const [];
        walk.note('merged library (CMS + API): ${merged.length}');

        // Featured (top of the page), unless the Studio turned it off.
        await tester.drag(scroll, const Offset(0, 4000), warnIfMissed: false);
        await pumpFor(tester, const Duration(seconds: 1));
        final mode = c().read(featuredModeProvider).valueOrNull;
        walk.note('featured mode: $mode');
        if (mode == FeaturedMode.off) {
          walk.check(
            find.text('Latest messages').evaluate().isNotEmpty,
            'featured off: the tab leads with the latest messages',
          );
        } else {
          final featured = c().read(featuredSermonsProvider);
          walk.check(featured.isNotEmpty, 'featured carousel has items');
          walk.check(
            find.text('FEATURED').evaluate().isNotEmpty ||
                find.text('NOW PLAYING').evaluate().isNotEmpty,
            'featured carousel painted',
          );
        }
        await hostShot(tester, '4-messages-featured');

        // Search: hits come fast; nonsense gets a real empty state.
        final searchField = find.byType(TextField).first;
        await tester.tap(searchField, warnIfMissed: false);
        final searchStart = DateTime.now();
        await tester.enterText(searchField, 'Holy Spirit');
        final resultsRe = RegExp(r'^([\d,]+) results? for "Holy Spirit"$');
        int? hits;
        final found = await pumpUntil(
          tester,
          () {
            for (final t in allTexts()) {
              final m = resultsRe.firstMatch(t);
              if (m != null) {
                hits = int.parse(m.group(1)!.replaceAll(',', ''));
                return hits! > 0;
              }
            }
            return false;
          },
          timeout: const Duration(seconds: 20),
          step: const Duration(milliseconds: 100),
        );
        final searchMs = DateTime.now().difference(searchStart).inMilliseconds;
        walk.check(
          found,
          '"Holy Spirit" returns results ($hits hits after ${searchMs}ms)',
        );
        walk.check(
          searchMs <= 5000,
          '"Holy Spirit" results within 5 s ($searchMs ms)',
        );
        walk.check(
          find.byType(SermonListItem).evaluate().isNotEmpty,
          'search result rows painted',
        );
        FocusManager.instance.primaryFocus?.unfocus();
        await pumpFor(tester, const Duration(seconds: 2));
        await hostShot(tester, '4-search-holy-spirit');
        const nonsense = 'zxqvj plorbft 7731';
        await tester.tap(find.byTooltip('Clear search'), warnIfMissed: false);
        await pumpFor(tester, const Duration(milliseconds: 500));
        await tester.tap(searchField, warnIfMissed: false);
        await pumpFor(tester, const Duration(milliseconds: 500));
        await tester.enterText(searchField, nonsense);
        // The empty state waits for the server search to answer (a spinner
        // meanwhile), so allow for a slow network and report the time.
        final emptyStart = DateTime.now();
        final emptyShown = await pumpUntil(
          tester,
          () =>
              find.text('No messages match "$nonsense"').evaluate().isNotEmpty,
          timeout: const Duration(seconds: 60),
        );
        walk.check(
          emptyShown,
          'nonsense query shows "No messages match" '
          '(after ${DateTime.now().difference(emptyStart).inMilliseconds} ms)',
        );
        walk.check(
          find
              .text('Try a title, a speaker or a series name.')
              .evaluate()
              .isNotEmpty,
          'empty state offers guidance',
        );
        FocusManager.instance.primaryFocus?.unfocus();
        await pumpFor(tester, const Duration(seconds: 1));
        await hostShot(tester, '4-search-empty-state');
        await clearMessagesSearch(tester);
        await pumpFor(tester, const Duration(seconds: 2));

        // Topic chips: counts on the cards add up to the library.
        final labels = c()
            .read(categoryLabelsProvider)
            .where((l) => l != 'All')
            .toList();
        final counts = c().read(categoryCountsProvider);
        final total =
            (c().read(sermonsProvider).valueOrNull ?? const []).length;
        final providerSum = labels.fold<int>(0, (n, l) => n + (counts[l] ?? 0));
        walk.check(
          providerSum == total,
          'topic counts sum to the library ($providerSum vs $total; '
          'hidden buckets: ${counts.keys.where((k) => !labels.contains(k)).toList()})',
        );
        await scrollUntilFound(
          tester,
          find.text('Find encouragement'),
          scrollable: scroll,
          step: const Offset(0, -150),
        );
        await pumpFor(tester, const Duration(milliseconds: 600));
        final onScreen = <String, int>{};
        final countRe = RegExp(r'^(\d+) messages$');
        if (labels.isNotEmpty) {
          await pumpUntilFound(tester, find.text(labels.first));
          // Re-resolved each pass: page appends rebuild the slivers, so a
          // pinned element can go stale.
          final anyTopic = find.byWidgetPredicate(
            (w) => w is Text && labels.contains(w.data),
          );
          Finder rail() => railOf(anyTopic, 'topic rail');
          await tester.ensureVisible(rail());
          await pumpFor(tester, const Duration(milliseconds: 400));
          await hostShot(tester, '4-topic-chips');
          for (
            var pass = 0;
            pass < 40 && onScreen.length < labels.length;
            pass++
          ) {
            for (final label in labels) {
              if (onScreen.containsKey(label)) continue;
              final labelText = find.descendant(
                of: rail(),
                matching: find.text(label),
              );
              if (labelText.evaluate().isEmpty) continue;
              final column = find
                  .ancestor(of: labelText.first, matching: find.byType(Column))
                  .first;
              for (final e
                  in find
                      .descendant(of: column, matching: find.byType(RichText))
                      .evaluate()) {
                final m = countRe.firstMatch(
                  (e.widget as RichText).text.toPlainText(),
                );
                if (m != null) onScreen[label] = int.parse(m.group(1)!);
              }
            }
            await tester.drag(
              rail(),
              const Offset(-300, 0),
              warnIfMissed: false,
            );
            await pumpFor(tester, const Duration(milliseconds: 400));
          }
          final screenSum = onScreen.values.fold<int>(0, (n, v) => n + v);
          walk.note('topic cards read: $onScreen');
          walk.check(
            onScreen.length == labels.length,
            'read every topic card (${onScreen.length}/${labels.length})',
          );
          for (final e in onScreen.entries) {
            walk.check(
              counts[e.key] == e.value,
              'topic "${e.key}" card count ${e.value} matches library ${counts[e.key]}',
            );
          }
          walk.check(
            screenSum == total,
            'topic card counts sum to the total ($screenSum vs $total)',
          );
          await tester.drag(rail(), const Offset(4000, 0), warnIfMissed: false);
          await pumpFor(tester, const Duration(milliseconds: 400));
        }

        // Series filter.
        final seriesList = c().read(seriesListProvider);
        walk.note(
          'series in library: ${seriesList.length} '
          '${seriesList.take(5).map((s) => '${s.name}(${s.count})').toList()}',
        );
        if (seriesList.isEmpty) {
          walk.check(
            find.text('Series').evaluate().isEmpty,
            'no Series rail when the library has no series',
          );
          walk.note(
            'Series filter N/A: no sermon in the live library carries a '
            'series (API `series` is null on every record)',
          );
        } else {
          final series = seriesList.first;
          final pill = find.text('${series.name} (${series.count})');
          await scrollUntilFound(tester, pill, scrollable: scroll);
          await tester.tap(pill.first, warnIfMissed: false);
          await pumpFor(tester, const Duration(seconds: 2));
          final filtered = c().read(librarySermonsProvider);
          walk.check(
            filtered.isNotEmpty &&
                filtered.every((s) => s.series == series.name),
            'series "${series.name}" filter returns only that series '
            '(${filtered.length} rows, expected ${series.count})',
          );
          walk.check(
            filtered.length == series.count,
            'series filter count ${filtered.length} == pill ${series.count}',
          );
          final rows = tester.widgetList<SermonListItem>(
            find.byType(SermonListItem),
          );
          walk.check(
            rows.every((r) => r.category == series.name),
            'visible rows all labelled with the series',
          );
          await hostShot(tester, '4-series-filter');
          c().read(selectedSeriesProvider.notifier).state = null;
          await pumpFor(tester, const Duration(seconds: 1));
        }

        // Year rail: 2014 and 2013.
        final allYears = find.text('All years');
        await scrollUntilFound(tester, allYears, scrollable: scroll);
        Finder yearRail() => railOf(
          find.textContaining(RegExp(r'^(All years|\d{4} \(\d+\))$')),
          'year rail',
        );
        for (final (year, expected) in [
          (2014, _expected2014),
          (2013, _expected2013),
        ]) {
          final pill = find.textContaining(RegExp('^$year \\((\\d+)\\)\$'));
          await scrollUntilFound(
            tester,
            pill,
            scrollable: yearRail(),
            step: const Offset(-220, 0),
            timeout: const Duration(seconds: 30),
          );
          final label = (tester.widget<Text>(pill.first)).data ?? '';
          await tester.tap(pill.first, warnIfMissed: false);
          await pumpFor(tester, const Duration(seconds: 2));
          final rows = c().read(librarySermonsProvider);
          walk.check(
            label == '$year ($expected)',
            'year pill reads "$year ($expected)" (got "$label")',
          );
          walk.check(
            rows.length == expected &&
                rows.every((s) => s.publishedAt?.year == year),
            '$year filter lists $expected sermons dated $year '
            '(got ${rows.length}, years ${rows.map((s) => s.publishedAt?.year).toSet()})',
          );
          walk.check(
            await pumpUntil(
              tester,
              () =>
                  find.text('All Messages \u00b7 $year').evaluate().isNotEmpty,
              timeout: const Duration(seconds: 15),
            ),
            'list header shows "All Messages · $year"',
          );
          await pumpUntilFound(tester, find.byType(SermonListItem));
          final painted = tester
              .widgetList<SermonListItem>(find.byType(SermonListItem))
              .toList();
          walk.check(
            painted.isNotEmpty &&
                painted.every((r) => r.dateLabel.endsWith('$year')),
            'painted rows are dated $year '
            '(${painted.map((r) => r.dateLabel).toSet()})',
          );
          await hostShot(tester, '4-year-$year');
          if (year == 2013) {
            // 35 rows > 20: the footer states the archive total.
            final footer = find.textContaining('reached the beginning');
            await scrollUntilFound(
              tester,
              footer,
              scrollable: scroll,
              step: const Offset(0, -400),
              timeout: const Duration(seconds: 60),
            );
            final footerText = tester.widget<Text>(footer.first).data ?? '';
            walk.check(
              footerText.contains(
                '${_expectedArchive ~/ 1000},${(_expectedArchive % 1000).toString().padLeft(3, '0')} messages',
              ),
              'archive footer total: "$footerText"',
            );
            await hostShot(tester, '4-archive-footer-total');
            await scrollUntilFound(
              tester,
              // "All years" sits at the far left of the rail, scrolled out
              // (and disposed) once 2013 is selected; the header stays put.
              find.text('Newest'),
              scrollable: scroll,
              step: const Offset(0, 400),
            );
          }
        }
        c().read(selectedArchiveYearProvider.notifier).state = null;
        await pumpFor(tester, const Duration(seconds: 1));
      });

      // ── 5. Player ──────────────────────────────────────────────────────
      Sermon? playerSermon;
      String? playlistName;
      await walk.step('5-player', () async {
        await openMessagesReset(tester, c());
        final scroll = find.byType(CustomScrollView).first;
        await scrollUntilFound(
          tester,
          find.byType(SermonListItem),
          scrollable: scroll,
          step: const Offset(0, -200),
        );
        final list = c().read(librarySermonsProvider);
        final audio = c().read(audioPlayerServiceProvider);

        // First audio row of the library list.
        final firstAudio = list.firstWhere((s) => s.hasAudio);
        final row = find.byKey(ValueKey(firstAudio.id));
        await scrollUntilFound(tester, row, scrollable: scroll);
        await tester.tap(row, warnIfMissed: false);
        await pumpUntilFound(tester, find.byType(MediaModeToggle));
        walk.check(
          toggleWidget(tester).activeMode == MediaMode.audio,
          'audio message opens in audio mode',
        );
        final playing = await pumpUntil(
          tester,
          () =>
              audio.position > const Duration(seconds: 2) &&
              seekBarWidget(tester).duration > Duration.zero,
          timeout: const Duration(seconds: 60),
        );
        walk.check(playing, 'audio is playing with a known duration');

        // Timeline: elapsed on the left, -remaining on the right.
        final bar = seekBarWidget(tester);
        final timeTexts = [
          for (final e
              in find
                  .descendant(
                    of: inPlayer(find.byType(SeekBar)).first,
                    matching: find.byType(Text),
                  )
                  .evaluate())
            (e.widget as Text).data ?? '',
        ];
        final elapsedOk =
            timeTexts.isNotEmpty &&
            RegExp(r'^\d+:\d\d(:\d\d)?$').hasMatch(timeTexts.first);
        final remainingOk =
            timeTexts.length > 1 &&
            RegExp(r'^-\d+:\d\d(:\d\d)?$').hasMatch(timeTexts.last);
        walk.check(
          elapsedOk && remainingOk,
          'timeline shows elapsed and -remaining $timeTexts '
          '(pos ${_fmt(bar.position)} / ${_fmt(bar.duration)})',
        );
        await hostShot(tester, '5-player-timeline');

        // Next / Previous walk the list.
        final queue = c().read(playbackQueueProvider).valueOrNull;
        walk.check(
          queue != null && queue.hasNext,
          'queue built from the list (${queue?.items.length} items)',
        );
        final expectedNext = queue!.next!;
        final listNext = list
            .skip(list.indexWhere((s) => s.id == firstAudio.id) + 1)
            .firstWhere((s) => s.hasAudio);
        walk.check(
          expectedNext.id == listNext.id,
          'queue next is the next audio row of the list',
        );
        await tester.tap(
          inPlayer(find.byIcon(Icons.skip_next_rounded)),
          warnIfMissed: false,
        );
        final moved = await pumpUntil(
          tester,
          () => audio.currentSermon?.id == expectedNext.id,
          timeout: const Duration(seconds: 20),
          step: const Duration(milliseconds: 100),
        );
        walk.check(
          moved,
          'Next moves to "${expectedNext.title}" '
          '(now "${audio.currentSermon?.title}")',
        );
        walk.check(
          inPlayer(find.text(expectedNext.title)).evaluate().isNotEmpty,
          'player title follows Next',
        );
        await hostShot(tester, '5-player-next');
        // Previous steps back while under the 3 s restart threshold.
        await pumpUntil(
          tester,
          () =>
              c().read(playbackQueueProvider).valueOrNull?.current.id ==
              expectedNext.id,
          timeout: const Duration(seconds: 5),
        );
        if (audio.position > const Duration(seconds: 3)) {
          walk.note(
            'Next opened at ${_fmt(audio.position)} (> 3 s), Previous restarts first',
          );
          await tester.tap(
            inPlayer(find.byIcon(Icons.skip_previous_rounded)),
            warnIfMissed: false,
          );
          await pumpFor(tester, const Duration(milliseconds: 500));
        }
        await tester.tap(
          inPlayer(find.byIcon(Icons.skip_previous_rounded)),
          warnIfMissed: false,
        );
        final back = await pumpUntil(
          tester,
          () => audio.currentSermon?.id == firstAudio.id,
          timeout: const Duration(seconds: 20),
          step: const Duration(milliseconds: 100),
        );
        walk.check(back, 'Previous returns to "${firstAudio.title}"');
        await pumpFor(tester, const Duration(seconds: 1));
        await hostShot(tester, '5-player-previous');

        // Audio -> Video -> Audio keeps the position.
        var current = audio.currentSermon!;
        for (var i = 0; i < 6 && !current.hasVideo; i++) {
          await tester.tap(
            inPlayer(find.byIcon(Icons.skip_next_rounded)),
            warnIfMissed: false,
          );
          await pumpUntil(
            tester,
            () => audio.currentSermon?.id != current.id,
            timeout: const Duration(seconds: 20),
          );
          current = audio.currentSermon!;
        }
        playerSermon = current;
        walk.check(current.hasVideo, '"${current.title}" carries a video');
        await pumpUntil(
          tester,
          () =>
              seekBarWidget(tester).duration > Duration.zero &&
              audio.position > const Duration(seconds: 1),
          timeout: const Duration(seconds: 45),
        );
        // Seek (via the timeline) to ~25% so a reset to 0 cannot pass.
        final rect = tester.getRect(inPlayer(find.byType(SeekBar)).first);
        await tester.tapAt(
          Offset(rect.left + rect.width * 0.25, rect.top + 14),
        );
        await pumpUntil(
          tester,
          () => audio.position > seekBarWidget(tester).duration * 0.2,
          timeout: const Duration(seconds: 20),
        );
        await pumpFor(tester, const Duration(seconds: 2));
        final beforeVideo = audio.position;
        // The video is the whole service; the mp3 starts at `videoStart`
        // inside it, so one message point is `audio + videoStart` in video.
        final offset = current.videoStart ?? Duration.zero;
        walk.note(
          'audio at ${_fmt(beforeVideo)} before switching to video '
          '(videoStart ${_fmt(offset)})',
        );
        await tapMode(tester, 'Video');
        Duration? firstVideoPos;
        final videoUp = await pumpUntil(
          tester,
          () {
            if (toggleWidget(tester).activeMode != MediaMode.video) {
              return false;
            }
            final b = seekBarWidget(tester);
            if (b.duration > Duration.zero && b.position > Duration.zero) {
              firstVideoPos ??= b.position;
              return true;
            }
            return false;
          },
          timeout: const Duration(seconds: 45),
          step: const Duration(milliseconds: 100),
        );
        final videoError = inPlayer(
          find.text('Listen instead'),
        ).evaluate().isNotEmpty;
        walk.check(
          videoUp,
          'video engine starts and reports a position'
          '${videoError ? ' (video error banner shown)' : ''}',
        );
        if (firstVideoPos != null) {
          final drift = (firstVideoPos! - offset - beforeVideo).abs();
          walk.check(
            drift <= const Duration(seconds: 3),
            'audio -> video keeps the position: audio ${_fmt(beforeVideo)} -> '
            'video ${_fmt(firstVideoPos!)} = message '
            '${_fmt(firstVideoPos! - offset)} (drift ${drift.inMilliseconds} ms)',
          );
        }
        await pumpFor(tester, const Duration(seconds: 4));
        await hostShot(tester, '5-player-video-mode');
        final beforeAudio = seekBarWidget(tester).position;
        await tapMode(tester, 'Audio');
        Duration? firstAudioPos;
        final audioUp = await pumpUntil(
          tester,
          () {
            if (toggleWidget(tester).activeMode != MediaMode.audio) {
              return false;
            }
            final state = c().read(playerStateProvider).valueOrNull;
            if (state != null &&
                state.playing &&
                state.processingState == ProcessingState.ready) {
              firstAudioPos ??= audio.position;
              return true;
            }
            return false;
          },
          timeout: const Duration(seconds: 45),
          step: const Duration(milliseconds: 100),
        );
        walk.check(audioUp, 'back in audio mode and playing');
        if (firstAudioPos != null && beforeAudio > Duration.zero) {
          final drift = (firstAudioPos! - (beforeAudio - offset)).abs();
          walk.check(
            drift <= const Duration(seconds: 3),
            'video -> audio keeps the position: video ${_fmt(beforeAudio)} = '
            'message ${_fmt(beforeAudio - offset)} -> audio '
            '${_fmt(firstAudioPos!)} (drift ${drift.inMilliseconds} ms)',
          );
        }
        await pumpFor(tester, const Duration(seconds: 2));
        await hostShot(tester, '5-player-back-to-audio');

        // Stop, close, reopen from the list: resumes where it stopped.
        await tester.tap(
          inPlayer(find.byIcon(Icons.pause_rounded)).first,
          warnIfMissed: false,
        );
        await pumpUntil(
          tester,
          () => !(c().read(playerStateProvider).valueOrNull?.playing ?? true),
          timeout: const Duration(seconds: 10),
        );
        await pumpFor(tester, const Duration(seconds: 1));
        final paused = audio.position;
        final resumeSermon = audio.currentSermon!;
        walk.note('paused "${resumeSermon.title}" at ${_fmt(paused)}');
        await closePlayer(tester);
        await pumpUntilFound(tester, find.byType(MiniPlayer));
        await hostShot(tester, '5-player-closed-minibar');
        // Reopen from the mini player: the same message at the same point.
        await tester.tap(
          find.descendant(
            of: find.byType(MiniPlayer),
            matching: find.text(resumeSermon.title),
          ),
          warnIfMissed: false,
        );
        await pumpUntilFound(tester, find.byType(MediaModeToggle));
        await pumpFor(tester, const Duration(seconds: 1));
        walk.check(
          (seekBarWidget(tester).position - paused).abs() <=
              const Duration(seconds: 3),
          'mini player reopens at ${_fmt(seekBarWidget(tester).position)} '
          '(paused at ${_fmt(paused)})',
        );
        await closePlayer(tester);
        // Dismiss the bar (stops and saves), then start it again from the list.
        await tester.drag(
          find.byType(MiniPlayer),
          const Offset(0, 160),
          warnIfMissed: false,
        );
        await pumpUntil(
          tester,
          () => find.byType(MiniPlayer).evaluate().isEmpty,
          timeout: const Duration(seconds: 10),
        );
        walk.check(
          audio.currentSermon == null,
          'dismissing the bar stops playback',
        );
        final resumeRow = find.byKey(ValueKey(resumeSermon.id));
        await scrollUntilFound(
          tester,
          resumeRow,
          scrollable: scroll,
          step: const Offset(0, -150),
        );
        await tester.tap(resumeRow, warnIfMissed: false);
        await pumpUntilFound(tester, find.byType(MediaModeToggle));
        Duration? resumedAt;
        await pumpUntil(
          tester,
          () {
            final state = c().read(playerStateProvider).valueOrNull;
            if (state != null &&
                state.playing &&
                state.processingState == ProcessingState.ready &&
                audio.currentSermon?.id == resumeSermon.id) {
              resumedAt ??= audio.position;
              return true;
            }
            return false;
          },
          timeout: const Duration(seconds: 45),
          step: const Duration(milliseconds: 100),
        );
        walk.check(
          resumedAt != null &&
              (resumedAt! - paused).abs() <= const Duration(seconds: 3),
          'reopening resumes at the saved position: ${_fmt(paused)} -> '
          '${resumedAt == null ? 'not playing' : _fmt(resumedAt!)}',
        );
        await hostShot(tester, '5-player-resumed');

        // Note at the current time.
        await tapPlayerAction(tester, 'Notes');
        await pumpUntilFound(tester, find.byType(SermonNotesSheet));
        final addNote = find.textContaining('Add a note at ');
        walk.check(
          await pumpUntil(
            tester,
            () => addNote.evaluate().isNotEmpty,
            timeout: const Duration(seconds: 5),
          ),
          'notes sheet offers "Add a note at mm:ss"',
        );
        await hostShot(tester, '5-notes-sheet-add');
        // The label ticks with playback: read it in the same frame as the tap.
        final addLabel = (tester.widget<Text>(addNote.first)).data ?? '';
        final stamp = addLabel.replaceFirst('Add a note at ', '');
        final audioAtTap = audio.position;
        await tester.tap(addNote.first, warnIfMissed: false);
        await pumpUntilFound(tester, find.byType(NoteEditorScreen));
        final noteBody =
            'Walkthrough note ${DateTime.now().millisecondsSinceEpoch}';
        await tester.enterText(
          find.descendant(
            of: find.byType(NoteEditorScreen),
            matching: find.byType(TextField),
          ),
          noteBody,
        );
        await pumpFor(tester, const Duration(milliseconds: 500));
        await tester.tap(find.text('Save'), warnIfMissed: false);
        await pumpUntil(
          tester,
          () => find.byType(NoteEditorScreen).evaluate().isEmpty,
        );
        await tapPlayerAction(tester, 'Notes');
        await pumpUntilFound(tester, find.byType(SermonNotesSheet));
        final noteListed = await pumpUntil(
          tester,
          () => find.text(noteBody).evaluate().isNotEmpty,
          timeout: const Duration(seconds: 15),
        );
        walk.check(noteListed, 'saved note is listed in the notes sheet');
        int? secondsOf(String mmss) {
          final m = RegExp(r'^(?:(\d+):)?(\d+):(\d\d)$').firstMatch(mmss);
          if (m == null) return null;
          return int.parse(m.group(1) ?? '0') * 3600 +
              int.parse(m.group(2)!) * 60 +
              int.parse(m.group(3)!);
        }

        final sheetTimes = [
          for (final e
              in find
                  .descendant(
                    of: find.byType(SermonNotesSheet),
                    matching: find.byType(RichText),
                  )
                  .evaluate())
            (e.widget as RichText).text.toPlainText().trim(),
        ].where((t) => secondsOf(t) != null).toList();
        final want = secondsOf(stamp);
        walk.check(
          want != null &&
              sheetTimes.any((t) => (secondsOf(t)! - want).abs() <= 2) &&
              (want - audioAtTap.inSeconds).abs() <= 2,
          'note is stamped at the playback time: button said $stamp, audio '
          'at ${_fmt(audioAtTap)}, sheet shows $sheetTimes',
        );
        await hostShot(tester, '5-notes-sheet-listed');
        Navigator.of(tester.element(find.byType(SermonNotesSheet))).pop();
        await pumpFor(tester, const Duration(milliseconds: 800));

        // Leave no test data in the live backend: delete this run's note and
        // any left by earlier runs (iOS keeps the anonymous uid across
        // reinstalls, so leftovers accumulate under the same account).
        final notesRepo = c().read(notesRepositoryProvider);
        final leftovers = (c().read(notesProvider).valueOrNull ?? const [])
            .where((n) => n.body.startsWith('Walkthrough note '))
            .toList();
        for (final note in leftovers) {
          await notesRepo.delete(note.id);
        }
        walk.check(
          await pumpUntil(
            tester,
            () => !(c().read(notesProvider).valueOrNull ?? const []).any(
              (n) => n.body.startsWith('Walkthrough note '),
            ),
            timeout: const Duration(seconds: 15),
          ),
          'walkthrough notes cleaned up (${leftovers.length} removed)',
        );

        // Playlist: create, add the message.
        playlistName = 'Walk ${DateTime.now().millisecondsSinceEpoch % 100000}';
        await tapPlayerAction(tester, 'Playlist');
        await pumpUntilFound(tester, find.byType(AddToPlaylistSheet));
        await pumpUntilFound(
          tester,
          find.descendant(
            of: find.byType(AddToPlaylistSheet),
            matching: find.text('New playlist'),
          ),
          reason: 'signed in (anonymous) so playlists are available',
        );
        await tester.tap(
          find.descendant(
            of: find.byType(AddToPlaylistSheet),
            matching: find.text('New playlist'),
          ),
          warnIfMissed: false,
        );
        await pumpUntilFound(tester, find.byType(AlertDialog));
        await tester.enterText(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(TextField),
          ),
          playlistName!,
        );
        await tester.tap(find.text('Create'), warnIfMissed: false);
        final added = await pumpUntil(
          tester,
          () =>
              find
                  .descendant(
                    of: find.byType(AddToPlaylistSheet),
                    matching: find.text(playlistName!),
                  )
                  .evaluate()
                  .isNotEmpty &&
              find
                  .descendant(
                    of: find.byType(AddToPlaylistSheet),
                    matching: find.byIcon(Icons.check_circle_rounded),
                  )
                  .evaluate()
                  .isNotEmpty,
          timeout: const Duration(seconds: 20),
        );
        walk.check(added, 'playlist "$playlistName" created with the message');
        await hostShot(tester, '5-playlist-created');
        Navigator.of(tester.element(find.byType(AddToPlaylistSheet))).pop();
        await pumpFor(tester, const Duration(milliseconds: 800));
        await closePlayer(tester);

        // Open it from More > My Playlists, remove the message, delete it.
        await tapNav(tester, 'More');
        final moreScroll = find.byType(SingleChildScrollView).first;
        await scrollUntilFound(
          tester,
          find.text('My Playlists'),
          scrollable: moreScroll,
        );
        await tester.tap(find.text('My Playlists'), warnIfMissed: false);
        await pumpUntilFound(tester, find.byType(PlaylistsScreen));
        await pumpUntilFound(
          tester,
          find.text(playlistName!),
          reason: 'new playlist listed in My Playlists',
        );
        await hostShot(tester, '5-my-playlists');
        await tester.tap(find.text(playlistName!).first, warnIfMissed: false);
        await pumpUntilFound(tester, find.byType(PlaylistDetailScreen));
        final rowInPlaylist = find.descendant(
          of: find.byType(PlaylistDetailScreen),
          matching: find.byType(SermonListItem),
        );
        walk.check(
          await pumpUntil(
            tester,
            () => rowInPlaylist.evaluate().isNotEmpty,
            timeout: const Duration(seconds: 20),
          ),
          'playlist shows the added message',
        );
        if (rowInPlaylist.evaluate().isNotEmpty) {
          walk.check(
            tester.widget<SermonListItem>(rowInPlaylist.first).title ==
                resumeSermon.title,
            'playlist row is "${resumeSermon.title}"',
          );
        }
        await hostShot(tester, '5-playlist-detail');
        await tester.tap(
          find.descendant(
            of: rowInPlaylist.first,
            matching: find.byIcon(Icons.more_vert_rounded),
          ),
          warnIfMissed: false,
        );
        await pumpUntilFound(tester, find.text('Remove from this playlist'));
        await tester.tap(
          find.text('Remove from this playlist'),
          warnIfMissed: false,
        );
        walk.check(
          await pumpUntil(
            tester,
            () =>
                rowInPlaylist.evaluate().isEmpty &&
                find.text('0 messages').evaluate().isNotEmpty,
            timeout: const Duration(seconds: 15),
          ),
          'message removed from the playlist',
        );
        await hostShot(tester, '5-playlist-emptied');
        await tester.tap(
          find.descendant(
            of: find.byType(AppBar),
            matching: find.byIcon(Icons.more_vert_rounded),
          ),
          warnIfMissed: false,
        );
        await pumpUntilFound(tester, find.text('Delete playlist'));
        await tester.tap(find.text('Delete playlist'), warnIfMissed: false);
        await pumpUntilFound(tester, find.text('Delete playlist?'));
        await tester.tap(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.text('Delete'),
          ),
          warnIfMissed: false,
        );
        await pumpUntil(
          tester,
          () => find.byType(PlaylistDetailScreen).evaluate().isEmpty,
          timeout: const Duration(seconds: 15),
        );
        walk.check(
          await pumpUntil(
            tester,
            () => find.text(playlistName!).evaluate().isEmpty,
            timeout: const Duration(seconds: 15),
          ),
          'deleted playlist gone from My Playlists',
        );
        await hostShot(tester, '5-playlist-deleted');
        await tapBack(tester, reason: 'My Playlists needs a way back');
        await pumpUntilFound(
          tester,
          find.text('My Playlists'),
          reason: 'More after My Playlists',
        );
      });

      // ── 6. More ────────────────────────────────────────────────────────
      await walk.step('6-more', () async {
        await tapNav(tester, 'More');
        final moreScroll = find.byType(SingleChildScrollView).first;
        Future<void> openRow(String label) async {
          final row = find.text(label);
          await scrollUntilFound(
            tester,
            row,
            scrollable: moreScroll,
            timeout: const Duration(seconds: 20),
          );
          await tester.tap(row.first, warnIfMissed: false);
        }

        Future<void> pushed(
          String label,
          Finder destination,
          String shot,
        ) async {
          await openRow(label);
          final opened = await pumpUntil(
            tester,
            () => destination.evaluate().isNotEmpty,
            timeout: const Duration(seconds: 20),
          );
          walk.check(opened, '"$label" opens its screen');
          if (!opened) return;
          await pumpFor(tester, const Duration(seconds: 1));
          await hostShot(tester, shot);
          await tapBack(tester, reason: '"$label" needs a way back');
          walk.check(
            await pumpUntil(
              tester,
              () =>
                  destination.evaluate().isEmpty &&
                  find.text('More').evaluate().isNotEmpty,
            ),
            '"$label" returns to More',
          );
        }

        await pushed(
          'Daily Reading',
          find.byType(ReadingScreen),
          '6-more-daily-reading',
        );
        await pushed('My Notes', find.byType(NotesScreen), '6-more-my-notes');
        await pushed(
          'My Playlists',
          find.byType(PlaylistsScreen),
          '6-more-my-playlists',
        );
        await pushed(
          'Switch Branch',
          find.byType(BranchSelectionScreen),
          '6-more-switch-branch',
        );
        await pushed(
          'Notifications',
          find.byType(NotificationsSettingsScreen),
          '6-more-notifications',
        );
        await pushed(
          "I'm new here",
          find.byType(NewHereScreen),
          '6-more-new-here',
        );
        await pushed(
          'Share a testimony',
          find.byType(TestimonyScreen),
          '6-more-testimony',
        );

        // Give switches to the Giving tab; the tab bar is the way back.
        await openRow('Give');
        walk.check(
          await pumpUntil(
            tester,
            () => find.byType(GivingScreen).evaluate().isNotEmpty,
            timeout: const Duration(seconds: 15),
          ),
          '"Give" opens the Giving tab',
        );
        await hostShot(tester, '6-more-give');
        await tapNav(tester, 'More');
        walk.check(
          find.byType(SettingsScreen).evaluate().isNotEmpty,
          'tab bar returns from Giving to More',
        );

        // Rate & Feedback sheet.
        await openRow('Rate & Feedback');
        walk.check(
          await pumpUntil(
            tester,
            () => find.byType(FeedbackSheet).evaluate().isNotEmpty,
            timeout: const Duration(seconds: 10),
          ),
          '"Rate & Feedback" opens the feedback sheet',
        );
        await hostShot(tester, '6-more-feedback');
        if (find.text('Cancel').evaluate().isNotEmpty) {
          await tester.tap(find.text('Cancel').last, warnIfMissed: false);
        }
        walk.check(
          await pumpUntil(
            tester,
            () => find.byType(FeedbackSheet).evaluate().isEmpty,
          ),
          'feedback sheet closes with Cancel',
        );

        // External links: url_launcher reaches the platform, the browser
        // takes over, and the app comes back.
        for (final (label, url, shot) in [
          ('Help & Support', kHelpUrl, '6-more-help-browser'),
          ('Privacy Policy', kPrivacyPolicyUrl, '6-more-privacy-browser'),
        ]) {
          final before = urlLaunches().length;
          await openRow(label);
          var left = false;
          final end = DateTime.now().add(const Duration(seconds: 10));
          while (DateTime.now().isBefore(end)) {
            if (WidgetsBinding.instance.lifecycleState !=
                AppLifecycleState.resumed) {
              left = true;
              break;
            }
            if (urlLaunches().length > before &&
                urlLaunches().last.repliedAt != null) {
              // Give the browser a moment to take the foreground.
              await Future<void>.delayed(const Duration(seconds: 2));
              left =
                  WidgetsBinding.instance.lifecycleState !=
                  AppLifecycleState.resumed;
              break;
            }
            await Future<void>.delayed(const Duration(milliseconds: 200));
          }
          final launched = urlLaunches().skip(before).toList();
          walk.check(
            launched.isNotEmpty && launched.first.firstString == url,
            '"$label" invokes url_launcher with $url (got $launched)',
          );
          walk.check(
            left,
            '"$label" hands off to the browser (app left foreground)',
          );
          await hostShotBackground(shot);
          debugPrint('KACT:foreground');
          final back = await waitForegrounded();
          walk.check(back, 'app returns to the foreground after "$label"');
          await pumpFor(tester, const Duration(seconds: 2));
          walk.check(
            find.byType(SettingsScreen).evaluate().isNotEmpty,
            'back on More after "$label"',
          );
        }

        // Version matches pubspec.
        final versionText = find.byKey(const ValueKey('app-version'));
        await scrollUntilFound(tester, versionText, scrollable: moreScroll);
        await pumpUntil(
          tester,
          () =>
              (tester.widget<Text>(versionText).data ?? '') != 'Kharis Church',
          timeout: const Duration(seconds: 10),
        );
        final shown = tester.widget<Text>(versionText).data ?? '';
        final parts = _pubspecVersion.split('+');
        final expectedVersion = parts.length == 2
            ? 'Kharis Church ${parts[0]} (${parts[1]})'
            : 'Kharis Church $_pubspecVersion';
        walk.check(
          _pubspecVersion.isNotEmpty && shown == expectedVersion,
          'version "$shown" matches pubspec "$_pubspecVersion"',
        );
        await hostShot(tester, '6-more-version');
      });

      // ── 7. Giving ──────────────────────────────────────────────────────
      await walk.step('7-giving', () async {
        await tapNav(tester, 'Giving');
        await pumpUntilFound(tester, find.byType(GivingScreen));
        await pumpFor(tester, const Duration(seconds: 2));
        final scroll = find.byType(SingleChildScrollView).first;
        bool buildGodAHouse() => allTexts(
          includeOffstage: true,
        ).any((t) => t.toLowerCase().contains('build god a house'));
        walk.check(!buildGodAHouse(), 'no "Build God a House" (top)');
        await hostShot(tester, '7-giving-top');
        final copy = find.text('Copy bank details');
        await scrollUntilFound(tester, copy, scrollable: scroll);
        walk.check(!buildGodAHouse(), 'no "Build God a House" (bottom)');
        await Clipboard.setData(const ClipboardData(text: ''));
        await tester.tap(copy, warnIfMissed: false);
        walk.check(
          await pumpUntil(
            tester,
            () => find.text('Bank details copied').evaluate().isNotEmpty,
            timeout: const Duration(seconds: 5),
            step: const Duration(milliseconds: 100),
          ),
          'copy shows "Bank details copied"',
        );
        await hostShot(tester, '7-giving-copied');
        final clip = await Clipboard.getData(Clipboard.kTextPlain);
        walk.check(
          clip?.text == givingClipboardText(c().read(effectiveGivingProvider)),
          'clipboard holds the bank details (${clip?.text?.replaceAll('\n', ' / ')})',
        );
        final give = find.text('Give securely');
        await scrollUntilFound(
          tester,
          give,
          scrollable: scroll,
          step: const Offset(0, 150),
        );
        await tester.tap(give, warnIfMissed: false);
        await pumpUntilFound(tester, find.byType(GivingWebViewScreen));
        final loaded = await pumpUntil(
          tester,
          () => find
              .descendant(
                of: find.byType(GivingWebViewScreen),
                matching: find.byType(CircularProgressIndicator),
              )
              .evaluate()
              .isEmpty,
          timeout: const Duration(seconds: 45),
        );
        walk.check(loaded, 'giving page finished loading');
        walk.check(
          find.byType(GivingLoadError).evaluate().isEmpty,
          'giving page loaded without the error state',
        );
        await pumpFor(tester, const Duration(seconds: 2));
        await hostShot(tester, '7-giving-webview');
        await tester.tap(find.byTooltip('Close'), warnIfMissed: false);
        walk.check(
          await pumpUntil(
            tester,
            () => find.byType(GivingWebViewScreen).evaluate().isEmpty,
          ),
          'giving page closes back to Giving',
        );
        walk.check(
          find.byType(GivingScreen).evaluate().isNotEmpty,
          'Giving tab after closing the page',
        );
      });

      // ── 8. Share (last: the OS sheet sits over the app until dismissed) ─
      await walk.step('8-share', () async {
        await openMessagesReset(tester, c());
        final scroll = find.byType(CustomScrollView).first;
        final sermon =
            playerSermon ??
            c().read(librarySermonsProvider).firstWhere((s) => s.hasAudio);
        final row = find.byKey(ValueKey(sermon.id));
        await scrollUntilFound(tester, row, scrollable: scroll);
        await tester.tap(row, warnIfMissed: false);
        await pumpUntilFound(tester, find.byType(MediaModeToggle));
        await pumpFor(tester, const Duration(seconds: 2));
        final before = nativeCalls
            .where((n) => n.channel == _shareChannel)
            .length;
        await tapPlayerAction(tester, 'Share');
        var call = <NativeCall>[];
        final end = DateTime.now().add(const Duration(seconds: 10));
        while (DateTime.now().isBefore(end)) {
          call = nativeCalls
              .where((n) => n.channel == _shareChannel)
              .skip(before)
              .toList();
          if (call.isNotEmpty) break;
          await Future<void>.delayed(const Duration(milliseconds: 200));
        }
        walk.check(call.isNotEmpty, 'Share invokes the OS share sheet ($call)');
        if (call.isNotEmpty) walk.note('share payload: ${call.first.args}');
        final payload = call.isEmpty ? '' : '${call.first.args}';
        walk.check(
          payload.contains('https://kharis-app-47c49.web.app/m/'),
          'shared link opens in the Kharis app (/m/<id>)',
        );
        walk.check(
          !RegExp(
            r'youtube\.com|youtu\.be|yetanothersermon\.host|kharis\.org',
          ).hasMatch(payload),
          'shared text carries no external links',
        );
        await Future<void>.delayed(const Duration(seconds: 2));
        await hostShotBackground('8-share-sheet');
        debugPrint('KACT:dismiss-share');
        var dismissed = false;
        final end2 = DateTime.now().add(const Duration(seconds: 30));
        while (DateTime.now().isBefore(end2)) {
          if (call.isNotEmpty && call.first.repliedAt != null) {
            dismissed = true;
            break;
          }
          await Future<void>.delayed(const Duration(milliseconds: 250));
        }
        if (_hostCanDismissShare) {
          walk.check(dismissed, 'share sheet dismissed (platform replied)');
        } else {
          walk.note(
            'share sheet left open: the host has no input channel to this '
            'device (dismissed=$dismissed)',
          );
        }
        await waitForegrounded(timeout: const Duration(seconds: 15));
        await pumpFor(tester, const Duration(seconds: 2));
        await hostShot(tester, '8-share-dismissed');
        walk.check(
          find.byType(MediaModeToggle).evaluate().isNotEmpty,
          'player still on screen after the share sheet',
        );
        await closePlayer(tester);
      });

      // ── Summary ────────────────────────────────────────────────────────
      debugPrint('WALKTHROUGH-SUMMARY:');
      for (final s in walk.steps) {
        debugPrint(
          '  ${s.passed ? 'PASS' : 'FAIL'} ${s.id}'
          '${s.failures.isEmpty ? '' : ' -> ${s.failures.join(' || ')}'}',
        );
      }
      final failed = walk.steps.where((s) => !s.passed).map((s) => s.id);
      expect(failed, isEmpty, reason: 'failed steps: ${failed.toList()}');
    },
  );
}
