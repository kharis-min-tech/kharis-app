import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
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
import 'package:kharis_app/ui/components/components.dart';

import 'support/fake_audio_player_service.dart';
import 'support/fake_cache_service.dart';

/// The shell is four tabs (Home, Messages, Bible, More) in a floating nav
/// over the page, with the mini player above it. Events and Give are pushed
/// routes, not tabs.

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

const _labels = ['Home', 'Messages', 'Bible', 'More'];
final _nav = find.byKey(const Key('dashboard-nav'));

Finder _tab(String label) =>
    find.descendant(of: _nav, matching: find.text(label));

/// A tab's page: its name, and buttons that open a sheet from it.
class _Page extends StatelessWidget {
  const _Page(this.path);

  final String path;

  void _sheet(BuildContext context, {required bool root}) {
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        useRootNavigator: root,
        builder: (_) => const SizedBox(height: 200, child: Text('a sheet')),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('page $path'),
        TextButton(
          onPressed: () => _sheet(context, root: false),
          child: const Text('Open sheet'),
        ),
        TextButton(
          onPressed: () => _sheet(context, root: true),
          child: const Text('Open root sheet'),
        ),
      ],
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the app router', () {
    late ProviderContainer container;
    late RouteConfiguration config;

    setUp(() {
      container = ProviderContainer(
        overrides: [
          cacheServiceProvider.overrideWithValue(FakeCacheService()),
          onboardingCompletedProvider.overrideWithValue(true),
          currentUserProvider.overrideWith((ref) => Stream.value(null)),
        ],
      );
      addTearDown(container.dispose);
      config = container.read(appRouterProvider).configuration;
    });

    test('the shell branches run Home, Messages, Bible, More', () {
      final shell = config.routes.whereType<StatefulShellRoute>().single;
      expect(
        [for (final b in shell.branches) (b.routes.single as GoRoute).path],
        ['/home', '/messages', '/bible', '/more'],
      );
      expect(kTabPaths, ['/home', '/messages', '/bible', '/more']);
      expect([for (final t in kDashboardTabs) t.label], _labels);
    });

    test('Events, Give and an event open as pushed routes above the '
        'shell, with their deep links intact', () {
      for (final location in ['/calendar', '/give', '/reading', '/player']) {
        final match = config.findMatch(Uri.parse(location));
        expect(match.matches, hasLength(1), reason: location);
        expect(
          (match.matches.single.route as GoRoute).path,
          location,
          reason: '$location is a root route, not a tab',
        );
      }
      final event = config.findMatch(Uri.parse('/events/e1'));
      expect(event.matches, hasLength(1));
      expect((event.matches.single.route as GoRoute).path, '/events/:id');
      expect(event.pathParameters['id'], 'e1');
    });

    testWidgets('/giving redirects to /give', (tester) async {
      await tester.pumpWidget(const SizedBox());
      final redirected = await config.redirect(
        tester.element(find.byType(SizedBox)),
        config.findMatch(Uri.parse('/giving')),
        redirectHistory: <RouteMatchList>[],
      );
      expect(redirected.uri.path, '/give');
      expect((redirected.matches.single.route as GoRoute).path, '/give');
    });
  });

  group('the shell', () {
    late FakeCacheService cache;
    late GoRouter router;

    Future<void> pumpShell(
      WidgetTester tester, {
      Sermon? playing = _sermon,
    }) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();
      cache = FakeCacheService();
      final audio = FakeAudioPlayerService();
      if (playing != null) await audio.play(playing);
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          cacheServiceProvider.overrideWithValue(cache),
          audioPlayerServiceProvider.overrideWithValue(audio),
          currentSermonProvider.overrideWith((ref) => playing),
          currentUserProvider.overrideWith((ref) => Stream.value(_member)),
          currentBranchProvider.overrideWith((ref) => Stream.value('London')),
        ],
      );
      addTearDown(container.dispose);
      final openSheets = container.read(openSheetsProvider);
      router = GoRouter(
        initialLocation: '/home',
        observers: [SheetObserver(openSheets)],
        routes: [
          StatefulShellRoute.indexedStack(
            builder: (context, state, shell) =>
                DashboardShell(navigationShell: shell),
            branches: [
              for (final path in kTabPaths)
                StatefulShellBranch(
                  observers: [SheetObserver(openSheets)],
                  routes: [
                    GoRoute(
                      path: path,
                      builder: (_, _) => _Page(path),
                      routes: [
                        GoRoute(
                          path: 'detail',
                          builder: (_, _) =>
                              Center(child: Text('detail of $path')),
                        ),
                      ],
                    ),
                  ],
                ),
            ],
          ),
          GoRoute(
            path: '/player',
            builder: (_, _) => const Scaffold(body: Text('full player')),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            theme: KharisTheme.light(),
            routerConfig: router,
          ),
        ),
      );
      // Flush the shell's launch work.
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
    }

    testWidgets('reads Home, Messages, Bible, More and each opens its own '
        'screen', (tester) async {
      await pumpShell(tester);

      final xs = [for (final l in _labels) tester.getCenter(_tab(l)).dx];
      expect(xs, [...xs]..sort(), reason: 'left to right in this order');
      expect(
        find.descendant(of: _nav, matching: find.byType(Text)),
        findsNWidgets(4),
        reason: 'four tabs: Events and Giving are no longer tabs',
      );

      for (var i = 0; i < _labels.length; i++) {
        await tester.tap(_tab(_labels[i]));
        await tester.pumpAndSettle();
        expect(find.text('page ${kTabPaths[i]}'), findsOneWidget);
        expect(cache.preferences[kLastTabKey], kTabPaths[i]);
      }
    });

    testWidgets('the active tab is announced as selected', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpShell(tester);

      Finder node(String label) => find.descendant(
        of: _nav,
        matching: find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == label,
        ),
      );

      expect(
        tester.getSemantics(node('Home')),
        isSemantics(label: 'Home', isButton: true, isSelected: true),
      );
      expect(
        tester.getSemantics(node('Bible')),
        isSemantics(label: 'Bible', isButton: true, isSelected: false),
      );

      await tester.tap(_tab('Bible'));
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(node('Bible')),
        isSemantics(label: 'Bible', isButton: true, isSelected: true),
      );
      expect(
        tester.getSemantics(node('Home')),
        isSemantics(label: 'Home', isButton: true, isSelected: false),
      );
      semantics.dispose();
    });

    testWidgets('tapping the active tab returns it to its first screen', (
      tester,
    ) async {
      await pumpShell(tester);
      router.go('/messages/detail');
      await tester.pumpAndSettle();
      expect(find.text('detail of /messages'), findsOneWidget);

      await tester.tap(_tab('Messages'));
      await tester.pumpAndSettle();
      expect(find.text('detail of /messages'), findsNothing);
      expect(find.text('page /messages'), findsOneWidget);
    });

    testWidgets('the mini player sits above the nav on every tab and opens '
        'the player', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 800);
      addTearDown(tester.view.reset);
      await pumpShell(tester);

      for (final label in _labels) {
        await tester.tap(_tab(label));
        await tester.pumpAndSettle();
        final mini = tester.getRect(find.byType(KMiniPlayer));
        final nav = tester.getRect(_nav);
        expect(mini.bottom, lessThanOrEqualTo(nav.top), reason: label);
        expect(mini.left, KSize.navInsetX, reason: label);
      }

      await tester.tap(find.text('Walking in Faith'));
      await tester.pumpAndSettle();
      expect(find.text('full player'), findsOneWidget);
      expect(find.byType(MiniPlayer), findsNothing, reason: 'under the player');
    });

    testWidgets('with nothing loaded there is no mini player', (tester) async {
      await pumpShell(tester, playing: null);
      expect(find.byType(KMiniPlayer), findsNothing);
      expect(_nav, findsOneWidget);
    });

    testWidgets('the nav and mini player hide while a sheet is open', (
      tester,
    ) async {
      await pumpShell(tester);

      for (final button in ['Open sheet', 'Open root sheet']) {
        await tester.tap(find.text(button));
        await tester.pumpAndSettle();
        expect(find.text('a sheet'), findsOneWidget);
        expect(_nav, findsNothing, reason: button);
        expect(find.byType(KMiniPlayer), findsNothing, reason: button);

        Navigator.of(tester.element(find.text('a sheet'))).pop();
        await tester.pumpAndSettle();
        expect(_nav, findsOneWidget, reason: '$button closed');
        expect(find.byType(KMiniPlayer), findsOneWidget);
      }
    });

    testWidgets('the nav hides while the keyboard is up', (tester) async {
      await pumpShell(tester);
      addTearDown(tester.view.reset);

      tester.view.viewInsets = const FakeViewPadding(bottom: 900);
      await tester.pumpAndSettle();
      expect(_nav, findsNothing);

      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      expect(_nav, findsOneWidget);
    });

    testWidgets('the nav floats 14 from each side and 18 from the bottom, or '
        'on the safe area when that is larger', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 800);
      addTearDown(tester.view.reset);
      await pumpShell(tester);

      final bar = find.descendant(of: _nav, matching: find.byType(ClipRRect));
      expect(
        tester.getRect(bar),
        const Rect.fromLTRB(14, 800 - 18 - 68, 390 - 14, 800 - 18),
      );

      tester.view.padding = const FakeViewPadding(bottom: 34);
      await tester.pumpAndSettle();
      expect(tester.getRect(bar).bottom, 800 - 34);
    });

    testWidgets('above 600 wide the nav is centred at the content width', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(900, 800);
      addTearDown(tester.view.reset);
      await pumpShell(tester);

      final nav = tester.getRect(_nav);
      expect(nav.width, KSize.maxContentWidth);
      expect(nav.center.dx, 450);
    });
  });

  group('last tab on launch', () {
    test('a saved tab reopens; a tab that no longer exists opens Home', () {
      for (final path in kTabPaths) {
        expect(lastTabLocation(path), path);
      }
      // Giving and Events were tabs; they are pushed screens now.
      expect(lastTabLocation('/giving'), '/home');
      expect(lastTabLocation('/calendar'), '/home');
      // Indexes from the version that saved the tab's position.
      expect(lastTabLocation(0), '/home');
      expect(lastTabLocation(1), '/messages');
      expect(lastTabLocation(2), '/home', reason: 'was Giving');
      expect(lastTabLocation(3), '/home', reason: 'was Events');
      expect(lastTabLocation(4), '/more');
      for (final saved in [null, 9, -1, '/nowhere']) {
        expect(lastTabLocation(saved), '/home', reason: '$saved');
      }
    });

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

    testWidgets('a member who left on Giving or Events lands on Home', (
      tester,
    ) async {
      for (final saved in ['/giving', '/calendar', 2, 3]) {
        await launch(tester, saved);
        expect(find.text('page /home'), findsOneWidget, reason: '$saved');
      }
    });

    testWidgets('a member who left on Bible lands on Bible', (tester) async {
      await launch(tester, '/bible');
      expect(find.text('page /bible'), findsOneWidget);
    });
  });
}
