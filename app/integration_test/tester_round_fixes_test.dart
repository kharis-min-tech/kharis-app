// Tester-round fix verification — on-device walkthrough against the LIVE
// kharis-church backend (no mocks), driven the way the 30 Aug TestFlight
// testers (NJ, Pastor Luke's reviewer) used the app.
//
// Each block asserts the acceptance criterion of a docs/BUG-TRACKER.md item
// closed on 9 Sep, on a real iOS Simulator, and drops a KSHOT marker so
// scripts/run_tester_round_fixes.sh can capture a screenshot of the proof:
//
//   KA-016          login: "Continue as Guest" is a real (outlined) button
//   KA-012 (launch) launching the app never shows the ratings sheet
//   KA-009          Today's Reading is on Home, above the fold
//   KA-020 / 002    Home bell → notifications feed → row opens a detail sheet
//   KA-004 / 007    Read now → in-app Bible reader with scripture + a way back
//   KA-014          Messages search bar keeps its pill shape idle and focused
//   KA-013 / 017    player has exactly one Share; Previous/Next are real buttons
//   KA-001          mini-player hidden on Giving, audio still loaded, back on Home
//   KA-003 / 007    More → My Notes (with a way back), My Playlists
//   KA-012 (row)    More → Rate & Feedback opens the sheet
//   KA-001 (swipe)  swipe-down on the bar stops playback and removes it
//   KA-015 / 018    featured message video: YouTube surface pinned outside the scroll
//
// Run (from app/):
//   scripts/run_tester_round_fixes.sh
// or directly:
//   flutter test integration_test/tester_round_fixes_test.dart \
//     -d F7F25682-5CB9-4E69-B116-46F898FF044D \
//     --dart-define-from-file=env.json --timeout none

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import 'package:kharis_app/core/configs/app_startup.dart';
import 'package:kharis_app/core/constants/api_config.dart';
import 'package:kharis_app/core/services/cache_service.dart';
import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/features/giving/presentation/screens/giving_screen.dart';
import 'package:kharis_app/features/home/presentation/screens/notifications_screen.dart';
import 'package:kharis_app/features/home/presentation/screens/reading_screen.dart';
import 'package:kharis_app/features/home/presentation/widgets/todays_reading_card.dart';
import 'package:kharis_app/features/messages/presentation/widgets/sermon_list_item.dart';
import 'package:kharis_app/features/notes/presentation/screens/notes_screen.dart';
import 'package:kharis_app/features/onboarding/presentation/widgets/branch_tile.dart';
import 'package:kharis_app/features/player/presentation/media_mode.dart';
import 'package:kharis_app/features/player/presentation/widgets/media_mode_toggle.dart';
import 'package:kharis_app/features/player/presentation/widgets/mini_player.dart';
import 'package:kharis_app/features/feedback/presentation/feedback_sheet.dart';
import 'package:kharis_app/main.dart';
import 'package:kharis_app/shared/providers/audio_provider.dart';
import 'package:kharis_app/shared/providers/cache_provider.dart';
import 'package:kharis_app/shared/providers/sermon_provider.dart';
import 'package:kharis_app/shared/providers/onboarding_provider.dart';
import 'package:kharis_app/shared/widgets/press_effect.dart';

// ── Pump helpers (same contract as release_walkthrough_test.dart) ────────────

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

/// Soft variant of [pumpUntilFound]: reports instead of failing.
Future<bool> waitFor(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 200));
    if (finder.evaluate().isNotEmpty) return true;
  }
  return false;
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

/// Any of the app's back/close affordances — an AppBar [BackButton], the
/// player/reader chevron, or a close glyph. KA-007's contract is "a way back
/// on every pushed surface", not one specific icon.
final _backIcons = <IconData>{
  Icons.arrow_back,
  Icons.arrow_back_rounded,
  Icons.arrow_back_ios,
  Icons.arrow_back_ios_new,
  Icons.arrow_back_ios_new_rounded,
  Icons.keyboard_arrow_down_rounded,
  Icons.close,
  Icons.close_rounded,
};

Finder backAffordance() => find.byWidgetPredicate(
  (w) => w is BackButton || (w is Icon && _backIcons.contains(w.icon)),
  description: 'back/close affordance',
);

/// Taps the *top-left-most* back affordance. `backAffordance().first` is tree
/// order, and Scaffold lays the body before the app bar — on the reader that
/// picked the "NIV ⌄" version pill (same chevron glyph) instead of the leading
/// chevron, so the walkthrough opened a picker rather than going home.
Future<void> tapBack(WidgetTester tester, {required String reason}) async {
  final candidates = backAffordance();
  expect(candidates, findsWidgets, reason: reason);
  final n = candidates.evaluate().length;
  var best = 0;
  var bestScore = double.infinity;
  for (var i = 0; i < n; i++) {
    final c = tester.getCenter(candidates.at(i));
    final score = c.dy * 10 + c.dx; // highest on screen wins, then left-most
    if (score < bestScore) {
      bestScore = score;
      best = i;
    }
  }
  await tester.tap(candidates.at(best), warnIfMissed: false);
}

/// The app's root [ProviderContainer] — lets the walkthrough read the audio
/// engine directly to prove playback survives UI changes (KA-001).
ProviderContainer containerOf(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(KharisApp)));

/// Closes the unified player with its header chevron.
Future<void> closePlayer(WidgetTester tester, Finder landing) async {
  await tester.tap(
    find.byIcon(Icons.keyboard_arrow_down_rounded).first,
    warnIfMissed: false,
  );
  await pumpUntilFound(tester, landing, reason: 'screen beneath the player');
}

/// Opens messages from the library list until one with an audio track is on
/// the unified player in audio mode. Returns that message's toggle.
Future<MediaModeToggle> openAudioMessage(WidgetTester tester) async {
  final scrollable = find.byType(CustomScrollView).first;
  await scrollUntilFound(
    tester,
    find.byType(SermonListItem),
    scrollable: scrollable,
    timeout: const Duration(seconds: 90),
  );
  for (var attempt = 0; attempt < 4; attempt++) {
    await tester.tap(find.byType(SermonListItem).first, warnIfMissed: false);
    await pumpUntilFound(
      tester,
      find.byType(MediaModeToggle),
      reason: 'unified player after tapping a message row',
    );
    await pumpFor(tester, const Duration(seconds: 2));
    var toggle = tester.widget<MediaModeToggle>(find.byType(MediaModeToggle));
    if (toggle.sermon.hasAudio) {
      if (toggle.activeMode != MediaMode.audio) {
        await tester.tap(find.text('Audio'), warnIfMissed: false);
        await pumpFor(tester, const Duration(seconds: 3));
        toggle = tester.widget<MediaModeToggle>(find.byType(MediaModeToggle));
      }
      return toggle;
    }
    debugPrint(
      'fixes: "${toggle.sermon.title}" is video-only — trying the next row',
    );
    await closePlayer(tester, find.byType(SermonListItem));
    // Push the video-only row off the top so `.first` is a new message.
    await tester.drag(scrollable, const Offset(0, -140), warnIfMissed: false);
    await pumpFor(tester, const Duration(milliseconds: 500));
  }
  fail('No message with an audio track in the first rows of the library');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'tester-round fixes: KA-001/002/003/004/007/009/012/013/014/015/016/017/018/020 on device',
    timeout: const Timeout(Duration(minutes: 25)),
    (tester) async {
      final verified = <String>[];

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

      // KA-012: a launch never prompts; ratings wait for the end of a listen
      // (ReviewPromptListener). Clear any prompt history from earlier runs.
      for (final key in prefs.getKeys().where((k) => k.startsWith('review_'))) {
        await prefs.remove(key);
      }

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

      // ── Onboarding (fresh install) or straight to the shell ──────────────
      final getStarted = find.text('Get started');
      final navHomeLabel = find.text('Home');
      final launched = await pumpUntilAny(tester, [getStarted, navHomeLabel]);

      if (launched == 0) {
        await tester.tap(getStarted);
        await pumpUntilFound(
          tester,
          find.text('Visitor'),
          reason: 'role selection screen after Get started',
        );
        await tester.tap(find.text('Visitor'));
        await pumpUntilFound(
          tester,
          find.text('Find your branch'),
          reason: 'branch selection screen after choosing a role',
        );
        await tester.enterText(find.byType(TextField).first, 'London');
        await pumpFor(tester, const Duration(seconds: 1));
        await pumpUntilFound(
          tester,
          find.text('London'),
          reason: 'London branch tile after search',
        );
        final londonTile = find
            .descendant(
              of: find.byType(BranchTile),
              matching: find.text('London'),
            )
            .first;
        await tester.ensureVisible(londonTile);
        await tester.pumpAndSettle();
        await tester.tap(londonTile, warnIfMissed: false);

        final guestButton = find.text('Continue as guest');
        final shellDeadline = DateTime.now().add(const Duration(seconds: 90));
        var loginSeen = false;
        while (tester.widgetList(navHomeLabel).isEmpty) {
          if (DateTime.now().isAfter(shellDeadline)) {
            fail(
              'Timed out waiting for the main shell after branch confirm '
              '(login screen shown: ${tester.widgetList(guestButton).isNotEmpty})',
            );
          }
          if (tester.widgetList(guestButton).isNotEmpty) {
            if (!loginSeen) {
              loginSeen = true;
              // KA-016: the guest path must read as a button, not a text link.
              expect(
                find.ancestor(
                  of: guestButton,
                  matching: find.byType(OutlinedButton),
                ),
                findsOneWidget,
                reason: 'KA-016: "Continue as Guest" must be an OutlinedButton',
              );
              verified.add('KA-016 guest button is an outlined button');
              await hostShot(tester, 'ka016-login-guest-button');
            }
            await tester.tap(guestButton);
          }
          await tester.pump(const Duration(milliseconds: 500));
        }
        if (!loginSeen) {
          debugPrint(
            'fixes: silent sign-in beat the login screen — KA-016 covered by '
            'test/tester_round_fixes_test.dart instead',
          );
        }
      } else {
        debugPrint('fixes: onboarding already complete, continuing');
      }

      // ── KA-012 (launch): opening the app never shows the ratings sheet ────
      await pumpFor(tester, const Duration(seconds: 6));
      expect(
        find.byType(FeedbackSheet),
        findsNothing,
        reason: 'KA-012: a launch must never be interrupted by a rating ask',
      );
      verified.add('KA-012 launch stayed silent');

      // ── KA-009: Today's Reading leads Home, above the fold ────────────────
      await tapNav(tester, 'Home');
      final readingCard = find.byType(TodaysReadingCard);
      await pumpUntilFound(tester, readingCard, reason: 'reading card on Home');
      final readingRect = tester.getRect(readingCard);
      final screenHeight =
          tester.view.physicalSize.height / tester.view.devicePixelRatio;
      expect(
        readingRect.bottom,
        lessThanOrEqualTo(screenHeight),
        reason:
            'KA-009: the reading card must be fully visible without scrolling',
      );
      verified.add('KA-009 reading card on Home, above the fold');
      await hostShot(tester, 'ka009-home-reading-first');

      // ── KA-020 / KA-002: bell → feed → detail sheet ───────────────────────
      final bell = find.byIcon(Icons.notifications_none_rounded);
      expect(bell, findsOneWidget, reason: 'KA-020: Home bell must be present');
      await tester.tap(bell, warnIfMissed: false);
      await pumpUntilFound(
        tester,
        find.byType(NotificationsScreen),
        reason: 'notifications feed after tapping the bell',
      );
      verified.add('KA-020 bell opens the notifications feed');
      // Wait for the feed to *settle* (rows or its empty state), not a fixed 3s.
      final feedRows = find.byType(Dismissible);
      final feedEmpty = find.textContaining('No notifications yet');
      final feedCaughtUp = find.textContaining('all caught up');
      final settled = await pumpUntilAny(tester, [
        feedRows,
        feedEmpty,
        feedCaughtUp,
      ], timeout: const Duration(seconds: 30));
      expect(
        settled,
        isNot(-1),
        reason: 'notifications feed should settle into rows or an empty state',
      );
      final feedHadRows = feedRows.evaluate().isNotEmpty;
      if (feedHadRows) {
        await tester.tap(feedRows.first, warnIfMissed: false);
        await pumpUntilFound(
          tester,
          find.byType(BottomSheet),
          reason: 'KA-002: tapping a feed row must open its detail sheet',
        );
        verified.add('KA-002 feed row opens a detail sheet');
        await hostShot(tester, 'ka002-notification-detail');
        Navigator.of(tester.element(find.byType(BottomSheet))).pop();
        await pumpFor(tester, const Duration(milliseconds: 600));
      } else {
        debugPrint(
          'fixes: feed empty for this branch — KA-002 sheet not exercised',
        );
        await hostShot(tester, 'ka020-notifications-feed');
      }
      await tapBack(
        tester,
        reason: 'KA-007: the notifications feed needs a way back',
      );
      await pumpUntilFound(tester, readingCard, reason: 'Home after the feed');
      // KA-023: the bell's dot must tell the truth — lit iff the feed had rows.
      await pumpFor(tester, const Duration(milliseconds: 500));
      final dotShown = find
          .byKey(const Key('home-bell-unread-dot'))
          .evaluate()
          .isNotEmpty;
      expect(
        dotShown,
        feedHadRows,
        reason:
            'KA-023: bell dot ($dotShown) must match whether the feed has '
            'undismissed rows ($feedHadRows) — it used to be painted always',
      );
      verified.add(
        'KA-023 bell dot mirrors the feed (dot=$dotShown, rows=$feedHadRows)',
      );

      // ── KA-004 / KA-007: Read now → in-app reader ─────────────────────────
      final readNow = find.text('Read now');
      await pumpUntilFound(tester, readNow, reason: 'Read now on the card');
      await tester.tap(readNow, warnIfMissed: false);
      await pumpUntilFound(
        tester,
        find.byType(ReadingScreen),
        reason: 'KA-004: Read now must open the in-app reader',
      );
      final loadDeadline = DateTime.now().add(const Duration(seconds: 60));
      while (DateTime.now().isBefore(loadDeadline) &&
          find.byType(CircularProgressIndicator).evaluate().isNotEmpty) {
        await tester.pump(const Duration(milliseconds: 250));
      }
      expect(
        find.byType(CircularProgressIndicator),
        findsNothing,
        reason: 'KA-004: passage still loading after 60s',
      );
      expect(
        find.text('Retry'),
        findsNothing,
        reason:
            'KA-004: "Bible failed to load" — the reader showed its error view',
      );
      // A plan that runs past the end of its book used to ask for a chapter
      // that does not exist; the reader then shows an error view with no
      // Retry. Real scripture is the only pass.
      final readerTexts = [
        for (final e
            in find
                .descendant(
                  of: find.byType(ReadingScreen),
                  matching: find.byType(RichText),
                )
                .evaluate())
          (e.widget as RichText).text.toPlainText(),
      ];
      expect(
        readerTexts.where(
          (t) =>
              t.contains('isn\u2019t available') ||
              t.contains('Couldn\u2019t load'),
        ),
        isEmpty,
        reason: 'KA-004: the reader showed an error view: $readerTexts',
      );
      expect(
        readerTexts
            .where((t) => t.length > 40)
            .fold<int>(0, (n, t) => n + t.length),
        greaterThan(300),
        reason: 'KA-004: the reader must show the passage text',
      );
      verified.add('KA-004 Read now opens scripture in-app');
      await hostShot(tester, 'ka004-reading-in-app');
      await tapBack(tester, reason: 'KA-007: the reader needs a way back');
      await pumpUntilFound(
        tester,
        readingCard,
        reason: 'Home after the reader',
      );
      verified.add('KA-007 feed + reader have a way back');

      // ── KA-014: search bar is a pill idle and focused ─────────────────────
      await tapNav(tester, 'Messages');
      final search = find.byType(TextField).first;
      await pumpUntilFound(tester, search, reason: 'Messages search field');
      final field = tester.widget<TextField>(search);
      expect(
        field.decoration?.focusedBorder,
        isA<OutlineInputBorder>().having(
          (b) => b.borderRadius,
          'borderRadius',
          BorderRadius.circular(AppRadius.pill),
        ),
        reason: 'KA-014: focused border must be the same pill',
      );
      final searchShell = find
          .ancestor(of: search, matching: find.byType(Container))
          .first;
      final shellDeco =
          tester.widget<Container>(searchShell).decoration as BoxDecoration?;
      expect(
        shellDeco?.borderRadius,
        BorderRadius.circular(AppRadius.pill),
        reason: 'KA-014: idle container must be a pill',
      );
      await hostShot(tester, 'ka014-search-idle');
      await tester.tap(search, warnIfMissed: false);
      await pumpFor(tester, const Duration(milliseconds: 800));
      await hostShot(tester, 'ka014-search-focused');
      FocusManager.instance.primaryFocus?.unfocus();
      await pumpFor(tester, const Duration(milliseconds: 500));
      verified.add('KA-014 search bar pill idle + focused');

      // ── KA-013 / KA-017: audio player chrome ──────────────────────────────
      final audioToggle = await openAudioMessage(tester);
      expect(audioToggle.activeMode, MediaMode.audio);
      expect(
        find.byIcon(Icons.ios_share_rounded),
        findsOneWidget,
        reason: 'KA-013: exactly one Share on the player',
      );
      expect(find.text('Share'), findsOneWidget);
      expect(find.text('Notes'), findsOneWidget);
      expect(find.text('Playlist'), findsOneWidget);
      verified.add('KA-013 single Share on the audio player');
      final previous = find.byIcon(Icons.skip_previous_rounded);
      final next = find.byIcon(Icons.skip_next_rounded);
      expect(previous, findsOneWidget);
      expect(next, findsOneWidget);
      expect(
        find.ancestor(of: previous, matching: find.byType(InkWell)),
        findsWidgets,
        reason: 'KA-017: Previous/Next must be real (ripple) buttons',
      );
      expect(
        find.ancestor(of: next, matching: find.byType(InkWell)),
        findsWidgets,
      );
      verified.add('KA-017 Previous/Next are tonal ripple buttons');
      await hostShot(tester, 'ka013-017-audio-player');

      // ── KA-007: close the player; the bar docks ───────────────────────────
      expect(backAffordance(), findsWidgets, reason: 'KA-007: player back');
      await closePlayer(tester, find.byType(MiniPlayer));
      verified.add('KA-007 player has a way back');
      await hostShot(tester, 'ka001-messages-minibar');

      // ── KA-001: Giving hides the bar without stopping audio ───────────────
      final audio = containerOf(tester).read(audioPlayerServiceProvider);
      expect(audio.currentSermon, isNotNull, reason: 'a message is loaded');
      final positionBefore = audio.position;
      await tapNav(tester, 'Giving');
      await pumpUntilFound(tester, find.byType(GivingScreen));
      await pumpFor(tester, const Duration(seconds: 2));
      expect(
        find.byType(MiniPlayer),
        findsNothing,
        reason: 'KA-001: no mini-bar over the giving flow',
      );
      expect(
        audio.currentSermon,
        isNotNull,
        reason: 'KA-001: hiding the bar must not stop the message',
      );
      debugPrint(
        'fixes: KA-001 audio position on Giving '
        '${positionBefore.inSeconds}s → ${audio.position.inSeconds}s '
        '(${audio.currentSermon?.title})',
      );
      verified.add('KA-001 Giving shows no bar; message still loaded');
      await hostShot(tester, 'ka001-giving-no-minibar');
      await tapNav(tester, 'Home');
      await pumpUntilFound(
        tester,
        find.byType(MiniPlayer),
        reason: 'KA-001: the bar must return on Home',
      );
      verified.add('KA-001 bar returns on Home');
      await hostShot(tester, 'ka001-home-minibar-back');

      // ── KA-003 / KA-012 (row): More menu ──────────────────────────────────
      await tapNav(tester, 'More');
      final moreScroll = find.byType(SingleChildScrollView).first;
      for (final label in ['Daily reading', 'My notes', 'My playlists']) {
        await scrollUntilFound(
          tester,
          find.text(label),
          scrollable: moreScroll,
          timeout: const Duration(seconds: 20),
        );
      }
      verified.add('KA-003 More has My Notes + My Playlists');
      await hostShot(tester, 'ka003-more-menu');
      // Scrolling down to 'My playlists' can push 'My notes' above the
      // viewport (the More rows are 44 px+ tap targets), and a tap there
      // misses silently.
      await tester.ensureVisible(find.text('My notes'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('My notes'), warnIfMissed: false);
      await pumpUntilFound(
        tester,
        find.byType(NotesScreen),
        reason: 'KA-003: My Notes must open the notes list',
      );
      await pumpFor(tester, const Duration(seconds: 2));
      await hostShot(tester, 'ka003-my-notes');
      await tapBack(tester, reason: 'KA-007: My Notes needs a way back');
      await pumpUntilFound(tester, find.text('My notes'), reason: 'More again');
      verified.add('KA-003 My Notes opens and exits');

      await scrollUntilFound(
        tester,
        find.text('Rate & feedback'),
        scrollable: moreScroll,
        timeout: const Duration(seconds: 20),
      );
      await tester.tap(find.text('Rate & feedback'), warnIfMissed: false);
      await pumpUntilFound(
        tester,
        find.byType(FeedbackSheet),
        reason: 'KA-012: the More row must open the feedback sheet',
      );
      expect(find.text('How is the Kharis app serving you?'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      verified.add('KA-012 Rate & Feedback row opens the sheet');
      await hostShot(tester, 'ka012-feedback-sheet');
      await tester.tap(find.text('Cancel'), warnIfMissed: false);
      await pumpFor(tester, const Duration(milliseconds: 800));
      expect(find.byType(FeedbackSheet), findsNothing);

      // ── KA-001 (swipe): the bar can still be dismissed outright ───────────
      await tapNav(tester, 'Home');
      await pumpUntilFound(tester, find.byType(MiniPlayer));
      await tester.drag(
        find.byType(MiniPlayer),
        const Offset(0, 140),
        warnIfMissed: false,
      );
      await pumpFor(tester, const Duration(seconds: 1));
      expect(
        find.byType(MiniPlayer),
        findsNothing,
        reason: 'KA-001: swipe-down must dismiss the bar',
      );
      expect(audio.currentSermon, isNull, reason: 'dismiss stops playback');
      verified.add('KA-001 swipe-down dismisses the bar and stops playback');
      await hostShot(tester, 'ka001-dismissed');

      // ── KA-015 / KA-018: video surface pinned outside the scroll ──────────
      await tapNav(tester, 'Messages');
      final featuredLabel = find.text('FEATURED');
      if (await waitFor(
        tester,
        featuredLabel,
        timeout: const Duration(seconds: 60),
      )) {
        final featuredCard = find
            .ancestor(
              of: featuredLabel.first,
              matching: find.byType(PressEffect),
            )
            .first;
        await tester.tap(featuredCard, warnIfMissed: false);
        await pumpUntilFound(tester, find.byType(MediaModeToggle));
        var toggle = tester.widget<MediaModeToggle>(
          find.byType(MediaModeToggle),
        );
        if (toggle.sermon.hasVideo) {
          if (toggle.activeMode != MediaMode.video) {
            await tester.tap(find.text('Video'), warnIfMissed: false);
          }
          await pumpFor(tester, const Duration(seconds: 4));
          toggle = tester.widget<MediaModeToggle>(find.byType(MediaModeToggle));
          expect(toggle.activeMode, MediaMode.video);
          expect(find.byType(YoutubePlayer), findsOneWidget);
          expect(
            find.descendant(
              of: find.byType(SingleChildScrollView),
              matching: find.byType(YoutubePlayer),
            ),
            findsNothing,
            reason: 'KA-015: the video must be pinned outside the scrollable',
          );
          expect(
            find.byIcon(Icons.ios_share_rounded),
            findsOneWidget,
            reason: 'KA-013 holds in video mode too',
          );
          verified.add(
            'KA-015/018 video pinned outside the scroll, single Share',
          );
          await hostShot(tester, 'ka015-018-video-pinned');
        } else {
          debugPrint(
            'fixes: featured message has no video — KA-015/018 not exercised',
          );
        }
        await closePlayer(tester, featuredLabel);
      } else {
        debugPrint('fixes: no featured carousel — KA-015/018 not exercised');
      }

      debugPrint('FIXES-VERIFIED (${verified.length}):');
      for (final line in verified) {
        debugPrint('  ✓ $line');
      }
    },
  );
}
