import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kharis_app/core/services/app_router.dart';
import 'package:kharis_app/features/home/presentation/screens/dashboard_shell.dart';
import 'package:kharis_app/features/player/presentation/widgets/mini_player.dart';
import 'package:kharis_app/shared/models/sermon.dart';
import 'package:kharis_app/shared/models/user.dart';
import 'package:kharis_app/shared/providers/audio_provider.dart';
import 'package:kharis_app/shared/providers/auth_provider.dart';
import 'package:kharis_app/shared/providers/branch_provider.dart';
import 'package:kharis_app/shared/providers/cache_provider.dart';
import 'package:kharis_app/shared/providers/onboarding_provider.dart';

import 'support/fake_audio_player_service.dart';
import 'support/fake_cache_service.dart';

/// The tab bar reads Home, Messages, Events, Giving, More: the router's
/// branches, the bar's items and the remembered last tab all agree.

const _sermon = Sermon(
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

  test("the app's shell branches run Home, Messages, Events, Giving, More", () {
    final container = ProviderContainer(
      overrides: [
        currentUserProvider.overrideWith((ref) => Stream.value(null)),
      ],
    );
    addTearDown(container.dispose);
    final router = container.read(appRouterProvider);

    final shell = router.configuration.routes
        .whereType<StatefulShellRoute>()
        .single;
    expect(
      [for (final b in shell.branches) (b.routes.single as GoRoute).path],
      ['/home', '/messages', '/calendar', '/giving', '/more'],
    );
    expect(kTabPaths, ['/home', '/messages', '/calendar', '/giving', '/more']);
  });

  group('dashboard tab bar', () {
    late FakeCacheService cache;

    Future<GoRouter> pumpShell(WidgetTester tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();
      cache = FakeCacheService();
      final audio = FakeAudioPlayerService();
      await audio.play(_sermon);
      final router = GoRouter(
        initialLocation: '/home',
        routes: [
          StatefulShellRoute.indexedStack(
            builder: (context, state, shell) =>
                DashboardShell(navigationShell: shell),
            branches: [
              for (final path in kTabPaths)
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
            cacheServiceProvider.overrideWithValue(cache),
            audioPlayerServiceProvider.overrideWithValue(audio),
            currentSermonProvider.overrideWith((ref) => _sermon),
            currentUserProvider.overrideWith((ref) => Stream.value(_member)),
            currentBranchProvider.overrideWith((ref) => Stream.value('London')),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      // Flush the shell's launch work.
      await tester.pump(const Duration(seconds: 2));
      return router;
    }

    const labels = ['Home', 'Messages', 'Events', 'Giving', 'More'];

    testWidgets('reads Home, Messages, Events, Giving, More and each opens '
        'its own screen', (tester) async {
      await pumpShell(tester);

      final xs = [for (final l in labels) tester.getCenter(find.text(l)).dx];
      expect(xs, [...xs]..sort(), reason: 'left to right in this order');

      for (var i = 0; i < labels.length; i++) {
        await tester.tap(find.text(labels[i]));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.text('page ${kTabPaths[i]}'), findsOneWidget);
        expect(cache.preferences[kLastTabKey], kTabPaths[i]);
      }
    });

    testWidgets('deep links land on their tab; only Giving hides the mini '
        'player', (tester) async {
      final router = await pumpShell(tester);

      router.go('/calendar');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('page /calendar'), findsOneWidget);
      expect(find.byType(MiniPlayer), findsOneWidget);

      router.go('/giving');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('page /giving'), findsOneWidget);
      expect(find.byType(MiniPlayer), findsNothing);
    });
  });

  group('last tab on launch', () {
    Future<void> launch(WidgetTester tester, Object? saved) async {
      final cache = FakeCacheService();
      if (saved != null) cache.preferences[kLastTabKey] = saved;
      final container = ProviderContainer(
        overrides: [
          cacheServiceProvider.overrideWithValue(cache),
          onboardingCompletedProvider.overrideWithValue(true),
          currentUserProvider.overrideWith((ref) => Stream.value(null)),
        ],
      );
      addTearDown(container.dispose);
      final router = GoRouter(
        redirect: container.read(routerNotifierProvider).redirect,
        routes: [
          GoRoute(path: '/', builder: (_, _) => const Text('welcome')),
          for (final path in kTabPaths)
            GoRoute(path: path, builder: (_, _) => Text('page $path')),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pump();
    }

    testWidgets('an index saved before Events moved still reopens Giving', (
      tester,
    ) async {
      await launch(tester, 2);
      expect(find.text('page /giving'), findsOneWidget);
    });

    testWidgets('an old saved index 3 still reopens Events', (tester) async {
      await launch(tester, 3);
      expect(find.text('page /calendar'), findsOneWidget);
    });

    testWidgets('a saved tab path reopens that tab', (tester) async {
      await launch(tester, '/giving');
      expect(find.text('page /giving'), findsOneWidget);
    });

    testWidgets('nothing or something unknown saved opens Home', (
      tester,
    ) async {
      for (final saved in [null, 9, '/nowhere']) {
        await launch(tester, saved);
        expect(find.text('page /home'), findsOneWidget, reason: '$saved');
      }
    });
  });
}
