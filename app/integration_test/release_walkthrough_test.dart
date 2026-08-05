// Release-verification walkthrough against the LIVE kharis-church backend.
//
// Drives the real app (no mocks) through:
//   1. fresh launch → onboarding (visitor role, London branch)
//   2. Home: seeded announcement "Welcome to the new Kharis app"
//   3. Messages: Featured carousel ("CHRIST Magnified…") + Message of the Day
//      ("A Living Witness…")
//   4. Message of the Day (video-only sermon) → unified player in video mode,
//      Audio chip disabled, no "video only" copy anywhere
//   5. back out of the player
//
// Screenshots are captured host-side: the test prints `KSHOT:<name>` and then
// holds the frame for ~3s while scripts/run_release_walkthrough.sh shells out
// to `xcrun simctl io <udid> screenshot`.
//
// Run (from app/):
//   scripts/run_release_walkthrough.sh
// or directly:
//   flutter test integration_test/release_walkthrough_test.dart \
//     -d F7F25682-5CB9-4E69-B116-46F898FF044D \
//     --dart-define-from-file=env.json --timeout none

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kharis_app/core/configs/app_startup.dart';
import 'package:kharis_app/features/onboarding/presentation/widgets/branch_tile.dart';
import 'package:kharis_app/core/constants/api_config.dart';
import 'package:kharis_app/core/services/cache_service.dart';
import 'package:kharis_app/features/player/presentation/media_mode.dart';
import 'package:kharis_app/features/player/presentation/widgets/media_mode_toggle.dart';
import 'package:kharis_app/main.dart';
import 'package:kharis_app/shared/providers/cache_provider.dart';
import 'package:kharis_app/shared/providers/onboarding_provider.dart';
import 'package:kharis_app/shared/widgets/press_effect.dart';

/// Real wall-clock pump for [duration] — the app keeps animating/streaming.
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
    '${reason == null ? '' : ' — $reason'}',
  );
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

/// Scrolls [scrollable] upward until [finder] appears, waiting out network
/// loads along the way, then brings it fully on screen.
Future<void> scrollUntilFound(
  WidgetTester tester,
  Finder finder, {
  required Finder scrollable,
  double delta = 130,
  Duration timeout = const Duration(seconds: 90),
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
      await tester.drag(
        scrollable.first,
        Offset(0, -delta),
        warnIfMissed: false,
      );
    }
  }
  fail('Timed out after ${timeout.inSeconds}s scrolling for $finder');
}

/// Taps the bottom-most on-screen match of [label] — the tab-bar item, even
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
  await pumpFor(tester, const Duration(milliseconds: 600));
}

/// Signals the host runner to grab a simulator screenshot, then holds the
/// frame long enough for `simctl io screenshot` to land on it.
Future<void> hostShot(WidgetTester tester, String name) async {
  debugPrint('KSHOT:$name');
  await pumpFor(tester, const Duration(seconds: 3));
}

/// True when any Text on screen contains [needle] (case-insensitive).
bool anyTextContains(String needle) {
  final n = needle.toLowerCase();
  for (final element in find.byType(Text).evaluate()) {
    final text = element.widget as Text;
    final data = text.data ?? text.textSpan?.toPlainText() ?? '';
    if (data.toLowerCase().contains(n)) return true;
  }
  return false;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'release walkthrough: onboarding → announcements → featured/MOTD → video-only player',
    timeout: const Timeout(Duration(minutes: 20)),
    (tester) async {
      // ── Bootstrap: mirrors lib/main.dart minus splash/orientation chrome and
      // minus runZonedGuarded, so the integration binding keeps its own
      // FlutterError handler and exceptions fail the test loudly.
      ApiConfig.warnIfProjectSplit();
      await JustAudioBackground.init(
        androidNotificationChannelId: 'com.kharis.app.channel.audio',
        androidNotificationChannelName: 'Kharis audio playback',
        androidNotificationOngoing: true,
        fastForwardInterval: const Duration(seconds: 15),
        rewindInterval: const Duration(seconds: 15),
      );
      final results = await Future.wait([
        SharedPreferences.getInstance(),
        CacheService.init(),
        AppStartUp().setUp(),
      ]);
      final prefs = results[0] as SharedPreferences;
      final cacheService = results[1] as CacheService;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            cacheServiceProvider.overrideWithValue(cacheService),
          ],
          child: const KharisApp(),
        ),
      );

      // ── Step 1: fresh launch → onboarding ────────────────────────────────
      final getStarted = find.text('Get started');
      final navHomeLabel = find.text('Home');
      final launched = await pumpUntilAny(tester, [getStarted, navHomeLabel]);

      if (launched == 0) {
        await hostShot(tester, 'step1a-splash');

        // Guest path: no account — "Get started" → pick a role → branch.
        await tester.tap(getStarted);
        await pumpUntilFound(
          tester,
          find.text('Visitor'),
          reason: 'role selection screen after Get started',
        );
        await hostShot(tester, 'step1b-role-selection');

        // "Visitor — Just exploring for now" is the continue-without-account
        // role; every role continues to branch selection.
        await tester.tap(find.text('Visitor'));
        await pumpUntilFound(
          tester,
          find.text('Find your branch'),
          reason: 'branch selection screen after choosing a role',
        );

        // Search instead of scrolling: the seed list is long.
        await tester.enterText(find.byType(TextField).first, 'London');
        await pumpFor(tester, const Duration(seconds: 1));
        await pumpUntilFound(
          tester,
          find.text('London'),
          reason: 'London branch tile after search',
        );
        await hostShot(tester, 'step1c-branch-selection-london');

        // Tap the branch TILE, not the search field: after typing, the
        // TextField's own 'London' text is first in the tree, and KP2 London
        // also renders as 'London' after its prefix strip — so scope the
        // finder to a BranchTile descendant and take the first (BRANCHES
        // section precedes KP2). Tile tap IS the confirm (routes onward).
        final londonTile = find
            .descendant(of: find.byType(BranchTile), matching: find.text('London'))
            .first;
        await tester.ensureVisible(londonTile);
        await tester.pumpAndSettle();
        await tester.tap(londonTile, warnIfMissed: false);

        // After the tile confirm the route depends on auth timing: the
        // app-level silent anonymous sign-in usually authenticates before
        // this point (branch → /home directly), but a slow first launch can
        // still land on /login, whose no-account path is "Continue as
        // Guest". Accept either: pump until the shell appears, tapping the
        // guest button if the login screen shows up on the way.
        final guestButton = find.text('Continue as Guest');
        final shellDeadline =
            DateTime.now().add(const Duration(seconds: 90));
        while (tester.widgetList(navHomeLabel).isEmpty) {
          if (DateTime.now().isAfter(shellDeadline)) {
            fail('Timed out waiting for the main shell after branch '
                'confirm (login screen shown: '
                '${tester.widgetList(guestButton).isNotEmpty})');
          }
          if (tester.widgetList(guestButton).isNotEmpty) {
            await hostShot(tester, 'step1d-login');
            await tester.tap(guestButton);
          }
          await tester.pump(const Duration(milliseconds: 500));
        }
      } else {
        // Re-run on a device that already finished onboarding: the redirect
        // sends '/' straight to the shell. Continue from the Home tab.
        debugPrint('walkthrough: onboarding already complete, continuing');
      }

      // ── Step 2: Home — seeded announcement ───────────────────────────────
      await tapNav(tester, 'Home');
      final welcome = find.textContaining('Welcome to the new Kharis app');
      await scrollUntilFound(
        tester,
        welcome,
        scrollable: find.byType(CustomScrollView).first,
        timeout: const Duration(seconds: 120),
      );
      expect(welcome, findsWidgets);
      await hostShot(tester, 'step2-home-announcement');

      // ── Step 3: Messages — Featured carousel + Message of the Day ────────
      await tapNav(tester, 'Messages');
      final featuredTitle = find.textContaining('CHRIST Magnified');
      await pumpUntilFound(
        tester,
        featuredTitle,
        timeout: const Duration(seconds: 90),
        reason: 'featured sermon "CHRIST Magnified…" in the hero carousel',
      );
      expect(find.text('FEATURED'), findsWidgets);

      final motdLabel = find.text('MESSAGE OF THE DAY');
      await pumpUntilFound(
        tester,
        motdLabel,
        timeout: const Duration(seconds: 60),
        reason: 'Message of the Day card',
      );
      final motdCard =
          find.ancestor(of: motdLabel, matching: find.byType(PressEffect)).first;
      expect(
        find.descendant(
          of: motdCard,
          matching: find.textContaining('A Living Witness'),
        ),
        findsOneWidget,
        reason: 'MOTD card must carry the configured sermon '
            '"A Living Witness For Jesus"',
      );
      await hostShot(tester, 'step3-messages-featured-motd');

      // ── Step 4: MOTD (video-only) → unified player in video mode ─────────
      await tester.tap(motdCard, warnIfMissed: false);
      await pumpUntilFound(
        tester,
        find.byType(MediaModeToggle),
        reason: 'unified player screen after tapping the MOTD card',
      );
      // Give the YouTube surface a moment to attach before inspecting/shooting.
      await pumpFor(tester, const Duration(seconds: 4));

      final toggle =
          tester.widget<MediaModeToggle>(find.byType(MediaModeToggle));
      expect(
        toggle.activeMode,
        MediaMode.video,
        reason: 'video-only sermon must open in video mode',
      );
      expect(toggle.sermon.hasVideo, isTrue);
      expect(
        toggle.sermon.hasAudio,
        isFalse,
        reason: 'MOTD sermon is expected to be video-only',
      );
      expect(find.text('Audio'), findsOneWidget);
      expect(find.text('Video'), findsOneWidget);
      // Only a disabled chip is wrapped in a Tooltip — this proves the Audio
      // option renders as disabled.
      expect(
        find.byTooltip('No audio recording for this message'),
        findsOneWidget,
        reason: 'Audio chip must be disabled for a video-only sermon',
      );

      // Semantics: Video is the selected chip, Audio is the disabled one.
      final semantics = tester.ensureSemantics();
      expect(find.bySemanticsLabel('Video, selected'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Audio — No audio recording for this message'),
        findsOneWidget,
      );
      semantics.dispose();

      // The old "video only" failure copy must not exist anywhere on screen.
      expect(
        anyTextContains('video only'),
        isFalse,
        reason: 'no "video only" copy may appear on the unified player',
      );
      await hostShot(tester, 'step4-player-video-mode');

      // ── Step 5: back out of the player ───────────────────────────────────
      await tester.tap(
        find.byIcon(Icons.keyboard_arrow_down_rounded).first,
        warnIfMissed: false,
      );
      await pumpUntilFound(
        tester,
        motdLabel,
        reason: 'Messages screen after closing the player',
      );
      await hostShot(tester, 'step5-back-on-messages');
    },
  );
}
