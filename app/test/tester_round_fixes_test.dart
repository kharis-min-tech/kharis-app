import 'dart:async';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kharis_app/features/home/presentation/screens/dashboard_shell.dart';
import 'package:kharis_app/features/onboarding/presentation/screens/login_screen.dart';
import 'support/fake_audio_player_service.dart';
import 'support/fake_cache_service.dart';
import 'support/more_screen_overrides.dart';
import 'package:kharis_app/features/playlists/providers/playlist_providers.dart';
import 'package:kharis_app/features/player/presentation/screens/media_player_screen.dart';
import 'package:kharis_app/features/player/presentation/widgets/mini_player.dart';
import 'package:kharis_app/features/settings/presentation/screens/settings_screen.dart';
import 'package:kharis_app/features/feedback/presentation/feedback_sheet.dart';
import 'package:kharis_app/shared/models/sermon.dart';
import 'package:kharis_app/shared/models/user.dart';
import 'package:kharis_app/shared/providers/audio_provider.dart';
import 'package:kharis_app/shared/providers/cache_provider.dart';
import 'package:kharis_app/shared/providers/auth_provider.dart';
import 'package:kharis_app/shared/providers/branch_provider.dart';
import 'package:kharis_app/shared/providers/onboarding_provider.dart';
import 'package:kharis_app/theme/kharis_theme.dart';
import 'package:kharis_app/ui/components/k_button.dart';

/// Regression guards for the tester-round fixes closed on 9 Sep
/// (docs/BUG-TRACKER.md): each test pins one acceptance criterion so a later
/// change cannot quietly reopen the complaint. The on-device counterpart is
/// integration_test/tester_round_fixes_test.dart.

/// Shared engine-less fake, plus the hooks these regressions need.
class _FakeAudio extends FakeAudioPlayerService {
  /// Lets a test model a real engine, whose stream clears the sermon a frame
  /// or more *after* `stop()` returns.
  void Function()? onStop;

  @override
  Future<void> loadPaused(Sermon sermon) async {
    current = sermon;
  }

  @override
  Future<void> stop() async {
    await super.stop();
    onStop?.call();
  }
}

final _sermon = Sermon(
  id: 's1',
  title: 'Walking in Faith',
  speaker: 'Pastor A',
  audioUrl: 'https://audio.example/s1.mp3',
);

final _member = User(
  id: 'member-1',
  email: 'member@kharis.org',
  displayName: 'Member',
  role: 'member',
  branch: 'London',
  createdAt: DateTime(2024),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'KA-001: the mini-player is out of the way on Give and back on Home '
    'without stopping the message',
    (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();
      final audio = _FakeAudio();
      await audio.play(_sermon);

      final router = GoRouter(
        initialLocation: '/home',
        routes: [
          StatefulShellRoute.indexedStack(
            builder: (context, state, shell) =>
                DashboardShell(navigationShell: shell),
            branches: [
              for (final path in ['/home', '/messages', '/bible', '/more'])
                StatefulShellBranch(
                  routes: [
                    GoRoute(
                      path: path,
                      builder: (_, _) => Center(child: Text('page $path')),
                    ),
                  ],
                ),
            ],
          ),
          // Give is a screen pushed over the tabs: it covers the mini player.
          GoRoute(
            path: '/give',
            builder: (_, _) => const Scaffold(body: Text('page /give')),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            audioPlayerServiceProvider.overrideWithValue(audio),
            currentSermonProvider.overrideWith((ref) => _sermon),
            currentUserProvider.overrideWith((ref) => Stream.value(_member)),
            currentBranchProvider.overrideWith((ref) => Stream.value('London')),
          ],
          child: MaterialApp.router(
            theme: KharisTheme.light(),
            routerConfig: router,
          ),
        ),
      );
      // Flush the shell's launch work (branch prompt delay, nudge decision).
      await tester.pump(const Duration(seconds: 2));

      expect(find.byType(MiniPlayer), findsOneWidget, reason: 'docked on Home');

      unawaited(router.push('/give'));
      await tester.pumpAndSettle();
      expect(find.text('page /give'), findsOneWidget);
      expect(
        find.byType(MiniPlayer),
        findsNothing,
        reason: 'KA-001: no bar over the giving flow',
      );
      expect(
        audio.currentSermon,
        isNotNull,
        reason: 'KA-001: hiding the bar must not stop the message',
      );
      expect(audio.stopCalls, 0);

      router.pop();
      await tester.pumpAndSettle();
      expect(find.text('page /home'), findsOneWidget);
      expect(
        find.byType(MiniPlayer),
        findsOneWidget,
        reason: 'the bar is back once Give is closed',
      );

      router.go('/messages');
      await tester.pumpAndSettle();
      expect(find.byType(MiniPlayer), findsOneWidget);
    },
  );

  testWidgets(
    'KA-001: swiping the bar away survives an engine that clears the sermon '
    'a frame late (iPhone: "dismissed Dismissible still in the tree")',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final audio = _FakeAudio();
      await audio.play(_sermon);
      // Stands in for the engine's currentSermon stream.
      final live = StateProvider<Sermon?>((ref) => _sermon);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            audioPlayerServiceProvider.overrideWithValue(audio),
            currentSermonProvider.overrideWith((ref) => ref.watch(live)),
          ],
          child: MaterialApp(
            theme: KharisTheme.light(),
            home: const Scaffold(body: Column(children: [MiniPlayer()])),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(Dismissible), findsOneWidget);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(MiniPlayer)),
      );
      // The real engine nulls the sermon well after the dismiss animation ends.
      audio.onStop = () => Future<void>.delayed(
        const Duration(milliseconds: 500),
        () => container.read(live.notifier).state = null,
      );

      await tester.fling(find.byType(Dismissible), const Offset(0, 300), 1200);
      await tester.pump();
      await tester.pump(
        const Duration(milliseconds: 300),
      ); // dismiss animates out
      await tester.pump(
        const Duration(milliseconds: 50),
      ); // sermon still non-null

      expect(
        tester.takeException(),
        isNull,
        reason: 'a dismissed Dismissible must leave the tree at once',
      );
      expect(audio.stopCalls, 1, reason: 'the swipe stops playback');
      expect(
        find.byType(Dismissible),
        findsNothing,
        reason: 'the bar hides itself before the engine catches up',
      );

      await tester.pump(const Duration(milliseconds: 600)); // engine catches up
      expect(find.byType(Dismissible), findsNothing);

      // The same message played again later must dock the bar again.
      container.read(live.notifier).state = _sermon;
      await tester.pump();
      expect(
        find.byType(Dismissible),
        findsOneWidget,
        reason: 'the dismissal must not blacklist the sermon for good',
      );
    },
  );

  testWidgets('KA-013: the unified player carries exactly one Share', (
    tester,
  ) async {
    MediaPlayerScreen.debugDisableVideoEngine = true;
    addTearDown(() => MediaPlayerScreen.debugDisableVideoEngine = false);
    final audio = _FakeAudio();
    await audio.play(_sermon);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          audioPlayerServiceProvider.overrideWithValue(audio),
          cacheServiceProvider.overrideWithValue(FakeCacheService()),
          // The like button reads the member's Favorites; keep it offline.
          favoritesProvider.overrideWith((ref) => Stream.value(null)),
        ],
        child: MaterialApp(
          theme: KharisTheme.light(),
          home: MediaPlayerScreen(sermon: _sermon, mode: MediaMode.audio),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('player-action-share')),
      findsOneWidget,
      reason: 'KA-013: header duplicate removed; actions-row share stays',
    );
    expect(find.text('Share'), findsOneWidget);
    expect(find.text('Notes'), findsOneWidget);
    expect(find.text('Playlist'), findsNothing);
    expect(find.bySemanticsLabel('Add to collection'), findsOneWidget);
    // KA-007: the player can always be closed: the grab handle is a
    // "Close player" button.
    expect(find.bySemanticsLabel('Close player'), findsOneWidget);
    // KA-017: the transport controls (now Previous / Next message) are real
    // buttons with a ripple.
    expect(
      find.descendant(
        of: find.byKey(const Key('player-previous')),
        matching: find.byType(InkWell),
      ),
      findsWidgets,
    );
  });

  testWidgets(
    'KA-003 / KA-012: More shows My notes, Collections and Help & feedback, '
    'and Help & feedback opens the feedback sheet',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            firestoreProvider.overrideWithValue(FakeFirebaseFirestore()),
            currentUserProvider.overrideWith((ref) => Stream.value(_member)),
            currentBranchProvider.overrideWith((ref) => Stream.value('London')),
            ...moreScreenOverrides(),
          ],
          child: MaterialApp(
            theme: KharisTheme.light(),
            home: const SettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      for (final label in ['My notes', 'Collections', 'Help & feedback']) {
        expect(find.text(label), findsOneWidget, reason: 'More shows "$label"');
      }

      await tester.ensureVisible(find.text('Help & feedback'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Help & feedback'));
      await tester.pumpAndSettle();

      // KA-012 now opens the in-app feedback sheet (stars + comment saved to
      // the church backend); store ratings come from the OS card at the end
      // of a listen, never from a button (review_prompt_flow_test).
      expect(find.byType(FeedbackSheet), findsOneWidget);
      expect(find.text('How is the Kharis app serving you?'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.byType(FeedbackSheet), findsNothing);
    },
  );

  testWidgets('KA-016: "Continue as Guest" is a full-width outlined button', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    // A phone: on wider screens the form column is capped, not full width.
    tester.view.physicalSize = const Size(KSize.designWidth, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: MaterialApp(
          theme: KharisTheme.light(),
          home: const LoginScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final guest = find.text('Continue as guest');
    expect(guest, findsOneWidget);
    final button = find.ancestor(of: guest, matching: find.byType(KButton));
    expect(
      tester.widget<KButton>(button).variant,
      KButtonVariant.outline,
      reason: 'KA-016: the guest path must read as a button, not a link',
    );
    expect(
      button,
      findsOneWidget,
      reason: 'KA-016: the guest path must read as a button, not a link',
    );
    final screenWidth = tester.getSize(find.byType(Scaffold)).width;
    expect(
      tester.getSize(button).width,
      greaterThan(screenWidth * 0.8),
      reason: 'full-width so it is obviously tappable',
    );
  });
}
