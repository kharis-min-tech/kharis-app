import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kharis_app/core/services/app_router.dart';
import 'package:kharis_app/features/home/presentation/screens/dashboard_shell.dart';
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

/// Pages pushed above the tab shell keep its floating nav, with the tab the
/// member came from highlighted; the full player has none.

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

final _nav = find.byKey(const Key('dashboard-nav'));

Finder _tab(String label) =>
    find.descendant(of: _nav, matching: find.text(label)).hitTestable();

/// The highlighted tab of the nav on top.
int _highlighted(WidgetTester tester) =>
    tester.widget<KFloatingNav>(_nav.last).currentIndex;

/// Every pushed page the member can reach, as a location to open.
const _pushedPages = [
  '/history',
  '/downloads',
  '/calendar',
  '/give',
  '/playlists',
  '/playlists/p1',
  '/favorites',
  '/notes',
  '/notifications',
  '/announcements',
  '/branch',
  '/profile/edit',
  '/settings/notifications',
  '/events/e1',
  '/e/e1',
  '/a/a1',
];

/// A tab's page: its name and the ways out of it a member has.
class _TabPage extends StatelessWidget {
  const _TabPage(this.path);

  final String path;

  @override
  Widget build(BuildContext context) {
    final links = switch (path) {
      '/home' => {'Give card': '/give', 'Play': '/player'},
      '/messages' => {'Search': '/messages/search'},
      '/more' => {'Events tile': '/calendar'},
      _ => const <String, String>{},
    };
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('page $path'),
        for (final MapEntry(key: label, value: to) in links.entries)
          TextButton(
            onPressed: () => unawaited(context.push(to)),
            child: Text(label),
          ),
        if (path == '/more')
          TextButton(
            // As More's New here and Testimony rows open their forms.
            onPressed: () => unawaited(
              Navigator.of(context, rootNavigator: true).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      const WithTabNav(child: Scaffold(body: Text('a form'))),
                ),
              ),
            ),
            child: const Text('Form row'),
          ),
      ],
    );
  }
}

/// A pushed page: its name and a way further in.
class _Pushed extends StatelessWidget {
  const _Pushed(this.name, {this.next});

  final String name;
  final String? next;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(name),
            if (next case final next?)
              TextButton(
                onPressed: () => unawaited(context.push(next)),
                child: const Text('Open next'),
              ),
          ],
        ),
      ),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the app routes', () {
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

    Widget page(WidgetTester tester, String location) {
      final match = config.findMatch(Uri.parse(location));
      expect(match.isError, isFalse, reason: location);
      final leaf = match.last;
      return leaf.route.builder!(
        tester.element(find.byType(SizedBox)),
        leaf.buildState(config, match),
      );
    }

    testWidgets('every pushed page is built with the tab nav', (tester) async {
      await tester.pumpWidget(const SizedBox());
      for (final location in _pushedPages) {
        expect(
          page(tester, location),
          isA<WithTabNav>(),
          reason: '$location keeps the nav',
        );
      }
    });

    testWidgets('Search opens inside the Messages tab, under its nav', (
      tester,
    ) async {
      final match = config.findMatch(Uri.parse('/messages/search'));
      final shell = match.matches.single as ShellRouteMatch;
      expect(shell.route, isA<StatefulShellRoute>());
      expect(
        (shell.matches.first.route as GoRoute).path,
        '/messages',
        reason: 'the Messages branch',
      );
    });

    testWidgets('the full player has no nav', (tester) async {
      await tester.pumpWidget(const SizedBox());
      expect(page(tester, '/player'), isNot(isA<WithTabNav>()));
    });
  });

  group('a pushed page', () {
    late GoRouter router;

    Future<void> pumpApp(
      WidgetTester tester, {
      String initialLocation = '/home',
      Sermon? playing,
    }) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();
      final audio = FakeAudioPlayerService();
      if (playing != null) await audio.play(playing);
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          cacheServiceProvider.overrideWithValue(FakeCacheService()),
          audioPlayerServiceProvider.overrideWithValue(audio),
          currentSermonProvider.overrideWith((ref) => playing),
          currentUserProvider.overrideWith((ref) => Stream.value(_member)),
          currentBranchProvider.overrideWith((ref) => Stream.value('London')),
        ],
      );
      addTearDown(container.dispose);
      final openSheets = container.read(openSheetsProvider);
      router = GoRouter(
        initialLocation: initialLocation,
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
                      builder: (_, _) => _TabPage(path),
                      routes: [
                        if (path == '/messages')
                          GoRoute(
                            path: 'search',
                            builder: (_, _) => const Scaffold(
                              body: Center(
                                child: TextField(
                                  key: Key('search-field'),
                                  autofocus: true,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
            ],
          ),
          GoRoute(
            path: '/give',
            builder: (_, _) => const WithTabNav(child: _Pushed('give page')),
          ),
          GoRoute(
            path: '/calendar',
            builder: (_, _) => const WithTabNav(
              child: _Pushed('events page', next: '/events/e1'),
            ),
          ),
          GoRoute(
            path: '/events/:id',
            builder: (_, state) => WithTabNav(
              child: _Pushed('event ${state.pathParameters['id']}'),
            ),
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

    Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
      await tester.tap(finder);
      await tester.pumpAndSettle();
    }

    String location() => router.routerDelegate.currentConfiguration.uri.path;

    testWidgets('from More: Events shows the nav with More highlighted', (
      tester,
    ) async {
      await pumpApp(tester);
      await tapAndSettle(tester, _tab('More'));
      await tapAndSettle(tester, find.text('Events tile'));

      expect(find.text('events page'), findsOneWidget);
      expect(_nav, findsOneWidget);
      expect(_highlighted(tester), 3, reason: 'More, not a switch to Home');

      // Further in, More stays highlighted.
      await tapAndSettle(tester, find.text('Open next'));
      expect(find.text('event e1'), findsOneWidget);
      expect(_highlighted(tester), 3);
    });

    testWidgets('from Home: Give shows the nav with Home highlighted, and the '
        'mini player above it', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 800);
      addTearDown(tester.view.reset);
      await pumpApp(tester, playing: _sermon);
      await tapAndSettle(tester, find.text('Give card'));

      expect(find.text('give page'), findsOneWidget);
      expect(_highlighted(tester), 0);
      final mini = tester.getRect(find.byType(KMiniPlayer));
      expect(mini.bottom, lessThanOrEqualTo(tester.getRect(_nav).top));
    });

    testWidgets('from Messages: Search keeps Messages highlighted, and the nav '
        'hides while the keyboard is up', (tester) async {
      await pumpApp(tester);
      addTearDown(tester.view.reset);
      await tapAndSettle(tester, _tab('Messages'));
      await tapAndSettle(tester, find.text('Search'));

      expect(find.byKey(const Key('search-field')), findsOneWidget);
      expect(_nav, findsOneWidget);
      expect(_highlighted(tester), 1);

      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      expect(_nav, findsNothing, reason: 'typing');

      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      expect(_nav, findsOneWidget);
    });

    testWidgets('the nav on a pushed page hides with the keyboard and while '
        'a sheet is open', (tester) async {
      await pumpApp(tester);
      addTearDown(tester.view.reset);
      await tapAndSettle(tester, find.text('Give card'));

      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      expect(_nav, findsNothing);
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      expect(_nav, findsOneWidget);

      unawaited(
        showModalBottomSheet<void>(
          context: tester.element(find.text('give page')),
          useRootNavigator: true,
          builder: (_) => const SizedBox(height: 200, child: Text('a sheet')),
        ),
      );
      await tester.pumpAndSettle();
      expect(_nav, findsNothing);
      Navigator.of(tester.element(find.text('a sheet'))).pop();
      await tester.pumpAndSettle();
      expect(_nav, findsOneWidget);
    });

    testWidgets('tapping another tab leaves the page for that tab', (
      tester,
    ) async {
      await pumpApp(tester);
      await tapAndSettle(tester, find.text('Give card'));
      await tapAndSettle(tester, _tab('Messages'));

      expect(find.text('give page'), findsNothing);
      expect(find.text('page /messages'), findsOneWidget);
      expect(location(), '/messages');
      expect(_highlighted(tester), 1);
    });

    testWidgets('tapping the highlighted tab returns to its root', (
      tester,
    ) async {
      await pumpApp(tester);
      await tapAndSettle(tester, _tab('More'));
      await tapAndSettle(tester, find.text('Events tile'));
      await tapAndSettle(tester, find.text('Open next'));
      expect(find.text('event e1'), findsOneWidget);

      await tapAndSettle(tester, _tab('More'));
      expect(find.text('event e1'), findsNothing);
      expect(find.text('events page'), findsNothing);
      expect(find.text('page /more'), findsOneWidget);
      expect(location(), '/more');
    });

    testWidgets('a form pushed from More closes when a tab is tapped', (
      tester,
    ) async {
      await pumpApp(tester);
      await tapAndSettle(tester, _tab('More'));
      await tapAndSettle(tester, find.text('Form row'));
      expect(find.text('a form'), findsOneWidget);
      expect(_highlighted(tester), 3);

      await tapAndSettle(tester, _tab('Home'));
      expect(find.text('a form'), findsNothing);
      expect(find.text('page /home'), findsOneWidget);
    });

    testWidgets('system back still returns one page', (tester) async {
      await pumpApp(tester);
      await tapAndSettle(tester, _tab('More'));
      await tapAndSettle(tester, find.text('Events tile'));
      await tapAndSettle(tester, find.text('Open next'));

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('events page'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('page /more'), findsOneWidget);
    });

    testWidgets('an event deep link shows the nav with Home highlighted', (
      tester,
    ) async {
      await pumpApp(tester, initialLocation: '/events/e9');
      expect(find.text('event e9'), findsOneWidget);
      expect(_nav, findsOneWidget);
      expect(_highlighted(tester), 0);

      await tapAndSettle(tester, _tab('Home'));
      expect(find.text('event e9'), findsNothing);
      expect(find.text('page /home'), findsOneWidget);
    });

    testWidgets('the full player has no nav', (tester) async {
      await pumpApp(tester);
      await tapAndSettle(tester, find.text('Play'));
      expect(find.text('full player'), findsOneWidget);
      expect(_nav, findsNothing);
    });
  });
}
