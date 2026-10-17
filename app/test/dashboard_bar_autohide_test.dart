import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kharis_app/features/home/presentation/screens/dashboard_shell.dart';
import 'package:kharis_app/shared/providers/audio_provider.dart';
import 'package:kharis_app/shared/providers/auth_provider.dart';
import 'package:kharis_app/shared/providers/branch_provider.dart';
import 'package:kharis_app/shared/providers/cache_provider.dart';
import 'package:kharis_app/shared/providers/onboarding_provider.dart';

import 'support/fake_audio_player_service.dart';
import 'support/fake_cache_service.dart';

/// The tab bar slides away while a tab's list scrolls down and comes back
/// on a scroll up, at the top, and on a route change, unless a screen reader
/// is navigating.
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  late GoRouter router;

  Future<void> launch(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'onboarding_completed': true,
      'onboarding_branch': 'London',
    });
    final sp = await SharedPreferences.getInstance();
    router = GoRouter(
      initialLocation: '/home',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, shell) =>
              DashboardShell(navigationShell: shell),
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/home',
                  builder: (_, _) => ListView.builder(
                    itemCount: 100,
                    itemBuilder: (_, i) =>
                        SizedBox(height: 80, child: Text('row $i')),
                  ),
                ),
              ],
            ),
            for (final path in ['/messages', '/giving', '/calendar', '/more'])
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
          currentUserProvider.overrideWith((ref) => Stream.value(null)),
          currentBranchProvider.overrideWith((ref) => Stream.value('London')),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
  }

  Offset barOffset(WidgetTester tester) => tester
      .widget<AnimatedSlide>(find.byKey(const Key('dashboard-bottom-bar')))
      .offset;

  Future<void> scrollList(WidgetTester tester, double dy) async {
    await tester.drag(find.byType(ListView), Offset(0, dy));
    await tester.pumpAndSettle();
  }

  testWidgets('hides on scroll down, shows on scroll up and at the top', (
    tester,
  ) async {
    await launch(tester);
    expect(barOffset(tester), Offset.zero);

    await scrollList(tester, -400);
    expect(barOffset(tester), const Offset(0, 1), reason: 'scrolled down');

    await scrollList(tester, 120);
    expect(barOffset(tester), Offset.zero, reason: 'scrolled up');

    await scrollList(tester, -400);
    expect(barOffset(tester), const Offset(0, 1));

    // Back at the top without a drag (e.g. a scroll-to-top).
    tester.state<ScrollableState>(find.byType(Scrollable)).position.jumpTo(0);
    await tester.pumpAndSettle();
    expect(barOffset(tester), Offset.zero, reason: 'at the top');
  });

  testWidgets('a route change brings it back', (tester) async {
    await launch(tester);
    await scrollList(tester, -400);
    expect(barOffset(tester), const Offset(0, 1));

    router.go('/messages');
    await tester.pumpAndSettle();
    expect(barOffset(tester), Offset.zero);
    expect(find.text('page /messages'), findsOneWidget);
  });

  testWidgets('stays put while a screen reader navigates', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(accessibleNavigation: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await launch(tester);

    await scrollList(tester, -400);
    expect(barOffset(tester), Offset.zero);
  });
}
