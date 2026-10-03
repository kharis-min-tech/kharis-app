import 'dart:async';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kharis_app/features/home/presentation/screens/dashboard_shell.dart';
import 'package:kharis_app/features/onboarding/presentation/screens/login_screen.dart';
import 'support/fake_audio_player_service.dart';
import 'support/fake_cache_service.dart';
import 'package:kharis_app/features/playlists/data/playlist_repository.dart';
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
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets(
    'KA-001: the mini-player hides on Giving and returns on Home without '
    'stopping the message',
    (tester) async {
      SharedPreferences.setMockInitialValues({'branch_prompt_shown': true});
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
              for (final path in [
                '/home',
                '/messages',
                '/giving',
                '/calendar',
                '/more',
              ])
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
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      // Flush the shell's launch work (branch prompt delay, nudge decision).
      await tester.pump(const Duration(seconds: 2));

      expect(find.byType(MiniPlayer), findsOneWidget, reason: 'docked on Home');

      router.go('/giving');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('page /giving'), findsOneWidget);
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

      router.go('/messages');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        find.byType(MiniPlayer),
        findsOneWidget,
        reason: 'the bar is back on any other tab',
      );

      router.go('/home');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
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
          child: const MaterialApp(
            home: Scaffold(body: Column(children: [MiniPlayer()])),
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
          // The like button reads the member's playlists; keep it offline.
          playlistsProvider.overrideWith(
            (ref) => Stream.value(const <Playlist>[]),
          ),
        ],
        child: MaterialApp(
          home: MediaPlayerScreen(sermon: _sermon, mode: MediaMode.audio),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byIcon(Icons.ios_share_rounded),
      findsOneWidget,
      reason: 'KA-013: header duplicate removed; actions-row share stays',
    );
    expect(find.text('Share'), findsOneWidget);
    expect(find.text('Notes'), findsOneWidget);
    expect(find.text('Playlist'), findsOneWidget);
    // KA-007: the player keeps its close chevron.
    expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsOneWidget);
    // KA-017: the transport controls (now Previous / Next message) are real
    // buttons with a ripple.
    expect(
      find.ancestor(
        of: find.byIcon(Icons.skip_previous_rounded),
        matching: find.byType(InkWell),
      ),
      findsWidgets,
    );
  });

  testWidgets(
    'KA-003 / KA-012: More lists My Notes, My Playlists and Rate & Feedback, '
    'and the row opens the sheet',
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
            isAdminProvider.overrideWith((ref) => false),
          ],
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );
      await tester.pumpAndSettle();

      for (final label in [
        'Daily Reading',
        'My Notes',
        'My Playlists',
        'Rate & Feedback',
      ]) {
        expect(find.text(label), findsOneWidget, reason: 'More row "$label"');
      }

      await tester.ensureVisible(find.text('Rate & Feedback'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rate & Feedback'));
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

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const MaterialApp(home: LoginScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final guest = find.text('Continue as Guest');
    expect(guest, findsOneWidget);
    final button = find.ancestor(
      of: guest,
      matching: find.byType(OutlinedButton),
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
