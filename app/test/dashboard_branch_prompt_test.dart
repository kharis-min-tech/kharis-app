import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kharis_app/core/services/notification_service.dart';
import 'package:kharis_app/features/home/presentation/screens/dashboard_shell.dart';
import 'package:kharis_app/features/onboarding/data/branch_repository.dart';
import 'package:kharis_app/features/onboarding/presentation/screens/branch_selection_screen.dart';
import 'package:kharis_app/shared/models/user.dart';
import 'package:kharis_app/shared/providers/admin_provider.dart';
import 'package:kharis_app/shared/providers/audio_provider.dart';
import 'package:kharis_app/shared/providers/auth_provider.dart';
import 'package:kharis_app/shared/providers/branch_provider.dart';
import 'package:kharis_app/shared/providers/cache_provider.dart';
import 'package:kharis_app/shared/providers/notification_provider.dart';
import 'package:kharis_app/shared/providers/onboarding_provider.dart';
import 'package:kharis_app/theme/kharis_theme.dart';

import 'support/fake_audio_player_service.dart';
import 'support/fake_cache_service.dart';

/// While no branch is chosen, every launch opens the branch picker once,
/// after the first frame; it can be dismissed. A member with a branch is
/// never asked.
void main() {
  final guest = User(
    id: 'guest-1',
    email: '',
    displayName: 'Guest',
    role: 'guest',
    createdAt: DateTime(2026),
  );

  const london = Branch(id: 'london', name: 'London', subtitle: 'Main branch');

  /// One launch: a fresh [ProviderScope] unless [container] is reused.
  Future<ProviderContainer> launch(
    WidgetTester tester, {
    Map<String, Object> prefs = const {'onboarding_completed': true},
    Stream<String?>? branch,
    ProviderContainer? container,
    String initialLocation = '/home',
  }) async {
    SharedPreferences.setMockInitialValues(prefs);
    final sp = await SharedPreferences.getInstance();
    final router = GoRouter(
      initialLocation: initialLocation,
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
        GoRoute(
          path: '/branch-selection',
          builder: (_, _) => const BranchSelectionScreen(),
        ),
      ],
    );
    addTearDown(router.dispose);

    final c =
        container ??
        ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(sp),
            audioPlayerServiceProvider.overrideWithValue(
              FakeAudioPlayerService(),
            ),
            cacheServiceProvider.overrideWithValue(FakeCacheService()),
            currentUserProvider.overrideWith((ref) => Stream.value(guest)),
            // Unset: resolved from the onboarding prefs, as for a guest.
            if (branch != null)
              currentBranchProvider.overrideWith((ref) => branch),
            branchesProvider.overrideWith((ref) => Stream.value([london])),
            notificationServiceProvider.overrideWithValue(
              _QuietNotifications(),
            ),
          ],
        );
    if (container == null) addTearDown(c.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp.router(
          theme: KharisTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    return c;
  }

  final picker = find.byKey(const ValueKey('branch-use-location'));

  testWidgets('while no branch is chosen, launch opens the picker', (
    tester,
  ) async {
    await launch(tester);

    expect(find.text('Choose your branch'), findsOneWidget);
    expect(picker, findsOneWidget);
    expect(find.byKey(const ValueKey('branch-choice-London')), findsOneWidget);
  });

  testWidgets('a legacy "All branches" pick is asked like no choice', (
    tester,
  ) async {
    await launch(
      tester,
      prefs: {'onboarding_completed': true, 'onboarding_branch': ''},
    );

    expect(picker, findsOneWidget);
  });

  testWidgets('dismissed, it is not offered again in the same launch', (
    tester,
  ) async {
    final c = await launch(tester);
    expect(picker, findsOneWidget);

    // Dismiss: tap the scrim above the sheet.
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();
    expect(picker, findsNothing);
    expect(find.text('page /home'), findsOneWidget);

    // The shell is rebuilt within the same launch.
    await tester.pumpWidget(const SizedBox());
    await launch(tester, container: c);
    expect(picker, findsNothing);
  });

  testWidgets('a member with a branch is not asked', (tester) async {
    await launch(
      tester,
      prefs: {'onboarding_completed': true, 'onboarding_branch': 'London'},
    );

    expect(picker, findsNothing);
    expect(find.text('page /home'), findsOneWidget);
  });

  testWidgets('a branch that resolves late is not asked for', (tester) async {
    // The slow-device window right after onboarding: the branch arrives
    // after the first frame.
    final late = StreamController<String?>();
    addTearDown(late.close);
    Timer(const Duration(seconds: 1), () => late.add('London'));
    await launch(tester, branch: late.stream);

    expect(picker, findsNothing);
  });

  testWidgets('a branch chosen in onboarding opens Home with no prompt', (
    tester,
  ) async {
    // Fresh install: Get started -> Member -> Find your branch.
    final c = await launch(
      tester,
      prefs: {'onboarding_role': 'member'},
      initialLocation: '/branch-selection',
    );
    expect(find.text('Find your branch'), findsOneWidget);

    await tester.tap(find.text('London'));
    // Home's first frame already has the choice: no stale "no branch"
    // carried over from before it was made.
    for (var i = 0; i < 20 && find.text('page /home').evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.text('page /home'), findsOneWidget);
    final atHome = c.read(currentBranchProvider);
    expect(atHome.isLoading, isFalse);
    expect(atHome.valueOrNull, 'London');

    await tester.pumpAndSettle();
    expect(find.text('page /home'), findsOneWidget);
    expect(picker, findsNothing);
    expect(find.text('Choose your branch'), findsNothing);
  });
}

class _QuietNotifications extends NotificationService {
  @override
  Future<void> switchBranchTopic({String? from, String? to}) async {}
}
