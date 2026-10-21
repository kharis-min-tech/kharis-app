import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:just_audio/just_audio.dart' show PlayerState, ProcessingState;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kharis_app/features/home/presentation/screens/dashboard_shell.dart';
import 'package:kharis_app/features/player/presentation/widgets/mini_player.dart';
import 'package:kharis_app/shared/models/sermon.dart';
import 'package:kharis_app/shared/providers/audio_provider.dart';
import 'package:kharis_app/shared/providers/auth_provider.dart';
import 'package:kharis_app/shared/providers/branch_provider.dart';
import 'package:kharis_app/shared/providers/cache_provider.dart';
import 'package:kharis_app/shared/providers/onboarding_provider.dart';

import 'support/fake_audio_player_service.dart';
import 'support/fake_cache_service.dart';

/// The tab bar slides away while a tab's list scrolls down and comes back
/// on a scroll up, at the top, on a route change (including closing a screen
/// pushed over the shell), on playback starting and on app resume, unless a
/// screen reader is navigating.
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  late GoRouter router;
  late FakeAudioPlayerService audio;

  Future<void> launch(WidgetTester tester) async {
    audio = FakeAudioPlayerService();
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
          audioPlayerServiceProvider.overrideWithValue(audio),
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

  testWidgets('comes back shortly after a scroll comes to rest; a new '
      'scroll before then restarts the wait', (tester) async {
    await launch(tester);
    final list = find.byType(ListView);
    const step = Duration(milliseconds: 100);

    await tester.drag(list, const Offset(0, -400));
    await tester.pump();
    await tester.pump(kBarReturnDelay - step);
    expect(barOffset(tester), const Offset(0, 1), reason: 'just rested');

    // Reading on before the delay is up: the wait starts over.
    await tester.drag(list, const Offset(0, -300));
    await tester.pump();
    await tester.pump(kBarReturnDelay - step);
    expect(barOffset(tester), const Offset(0, 1), reason: 'reading on');

    await tester.pump(step * 2);
    await tester.pumpAndSettle();
    expect(barOffset(tester), Offset.zero, reason: 'at rest');
  });

  testWidgets(
    'reaching the end of the page brings it back (Android: no bounce)',
    (tester) async {
      await launch(tester);
      await scrollList(tester, -400);
      expect(barOffset(tester), const Offset(0, 1), reason: 'mid page');

      await scrollList(tester, -20000);
      expect(barOffset(tester), Offset.zero, reason: 'at the end');
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets('a route change brings it back', (tester) async {
    await launch(tester);
    await scrollList(tester, -400);
    expect(barOffset(tester), const Offset(0, 1));

    router.go('/messages');
    await tester.pumpAndSettle();
    expect(barOffset(tester), Offset.zero);
    expect(find.text('page /messages'), findsOneWidget);
  });

  testWidgets('closing a screen pushed over the shell brings it back', (
    tester,
  ) async {
    await launch(tester);
    await scrollList(tester, -400);
    expect(barOffset(tester), const Offset(0, 1));

    // The full player: a plain route on the root navigator, which changes
    // no go_router location.
    final navigator = Navigator.of(
      tester.element(find.byType(ListView)),
      rootNavigator: true,
    );
    unawaited(
      navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('full player')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    navigator.pop();
    await tester.pumpAndSettle();

    expect(find.text('full player'), findsNothing);
    expect(barOffset(tester), Offset.zero);
  });

  testWidgets('playback starting shows the bar with the mini player', (
    tester,
  ) async {
    await launch(tester);
    await scrollList(tester, -400);
    expect(barOffset(tester), const Offset(0, 1));

    await audio.play(
      const Sermon(id: 's1', title: 'Message 1', speaker: 'P', audioUrl: 'a'),
    );
    audio.playerStates.add(PlayerState(true, ProcessingState.ready));
    await tester.pumpAndSettle();

    expect(find.byType(MiniPlayer), findsOneWidget);
    expect(barOffset(tester), Offset.zero);

    // Paused and hidden again, then resumed (lock screen, headphones).
    audio.playerStates.add(PlayerState(false, ProcessingState.ready));
    await scrollList(tester, -400);
    expect(barOffset(tester), const Offset(0, 1));
    audio.playerStates.add(PlayerState(true, ProcessingState.ready));
    await tester.pumpAndSettle();
    expect(barOffset(tester), Offset.zero);
  });

  testWidgets('returning to the app brings it back', (tester) async {
    await launch(tester);
    await scrollList(tester, -400);
    expect(barOffset(tester), const Offset(0, 1));

    final binding = tester.binding;
    for (final state in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      binding.handleAppLifecycleStateChanged(state);
    }
    await tester.pumpAndSettle();

    expect(barOffset(tester), Offset.zero);
  });

  testWidgets('stays put while a screen reader navigates', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(accessibleNavigation: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await launch(tester);

    await scrollList(tester, -400);
    expect(barOffset(tester), Offset.zero);
  });

  testWidgets('hidden, it leaves nothing over the list: the home-indicator '
      'band shows and touches the rows beneath (tester: "black box" over '
      'More)', (tester) async {
    tester.view.padding = const FakeViewPadding(bottom: 34 * 3);
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = const Size(400 * 3, 800 * 3);
    addTearDown(tester.view.reset);
    await launch(tester);
    await scrollList(tester, -400);
    expect(barOffset(tester), const Offset(0, 1));

    // A point inside the home-indicator band, at the screen's bottom edge.
    final result = HitTestResult();
    WidgetsBinding.instance.hitTestInView(
      result,
      const Offset(200, 800 - 12),
      tester.view.viewId,
    );
    expect(
      result.path.any((e) => e.target is RenderParagraph),
      isTrue,
      reason: 'the list row under the band receives the touch',
    );
  });
}
