import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kharis_app/features/home/presentation/screens/dashboard_shell.dart';
import 'package:kharis_app/shared/models/user.dart';
import 'package:kharis_app/shared/providers/audio_provider.dart';
import 'package:kharis_app/shared/providers/auth_provider.dart';
import 'package:kharis_app/shared/providers/branch_provider.dart';
import 'package:kharis_app/shared/providers/cache_provider.dart';
import 'package:kharis_app/shared/providers/onboarding_provider.dart';

import 'support/fake_audio_player_service.dart';
import 'support/fake_cache_service.dart';

/// The shell asks for a campus once, for accounts that never chose one. It
/// must not ask again a moment after a member chose one in onboarding, even
/// when the campus stream has not caught up yet (slow Android devices).
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  final guest = User(
    id: 'guest-1',
    email: '',
    displayName: 'Guest',
    role: 'guest',
    createdAt: DateTime(2026),
  );

  Future<void> launch(
    WidgetTester tester, {
    required Map<String, Object> prefs,
    required Stream<String?> branch,
  }) async {
    SharedPreferences.setMockInitialValues(prefs);
    final sp = await SharedPreferences.getInstance();
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(
          path: '/branch-selection',
          builder: (_, _) => const Text('Find your branch'),
        ),
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
          sharedPreferencesProvider.overrideWithValue(sp),
          audioPlayerServiceProvider.overrideWithValue(
            FakeAudioPlayerService(),
          ),
          cacheServiceProvider.overrideWithValue(FakeCacheService()),
          currentUserProvider.overrideWith((ref) => Stream.value(guest)),
          currentBranchProvider.overrideWith((ref) => branch),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'a campus chosen in onboarding is not asked for again while the campus '
    'stream is still loading',
    (tester) async {
      // A stream that never emits: the slow-device window right after
      // onboarding.
      final pending = StreamController<String?>.broadcast();
      addTearDown(pending.close);
      await launch(
        tester,
        prefs: {'onboarding_completed': true, 'onboarding_branch': 'London'},
        branch: pending.stream,
      );

      expect(find.text('Find your branch'), findsNothing);
      expect(find.text('page /home'), findsOneWidget);
    },
  );

  testWidgets('choosing "All campuses" also counts as an answer', (
    tester,
  ) async {
    final pending = StreamController<String?>.broadcast();
    addTearDown(pending.close);
    await launch(
      tester,
      prefs: {'onboarding_completed': true, 'onboarding_branch': ''},
      branch: pending.stream,
    );

    expect(find.text('Find your branch'), findsNothing);
  });

  testWidgets('a legacy account that never chose a campus is asked once', (
    tester,
  ) async {
    await launch(
      tester,
      prefs: {'onboarding_completed': true},
      branch: Stream.value(null),
    );

    expect(find.text('Find your branch'), findsOneWidget);
  });
}
