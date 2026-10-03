import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kharis_app/core/services/app_router.dart';
import 'package:kharis_app/core/services/notification_service.dart';
import 'package:kharis_app/features/calendar/data/event_repository.dart';
import 'package:kharis_app/features/calendar/data/rsvp_repository.dart';
import 'package:kharis_app/features/calendar/presentation/screens/calendar_screen.dart';
import 'package:kharis_app/features/calendar/presentation/screens/event_detail_screen.dart';
import 'package:kharis_app/features/home/data/daily_content_repository.dart';
import 'package:kharis_app/features/home/data/live_repository.dart';
import 'package:kharis_app/features/home/data/news_repository.dart';
import 'package:kharis_app/features/home/presentation/screens/home_screen.dart';
import 'package:kharis_app/features/home/presentation/screens/notifications_screen.dart';
import 'package:kharis_app/features/home/presentation/screens/reading_screen.dart';
import 'package:kharis_app/features/home/presentation/widgets/continue_listening_card.dart';
import 'package:kharis_app/features/home/presentation/widgets/news_section.dart';
import 'package:kharis_app/features/home/presentation/widgets/todays_reading_card.dart';
import 'package:kharis_app/features/onboarding/data/branch_repository.dart';
import 'package:kharis_app/shared/models/sermon.dart';
import 'package:kharis_app/shared/models/user.dart';
import 'package:kharis_app/shared/providers/admin_provider.dart';
import 'package:kharis_app/shared/providers/auth_provider.dart';
import 'package:kharis_app/shared/providers/branch_provider.dart';
import 'package:kharis_app/shared/providers/notification_feed_provider.dart';
import 'package:kharis_app/shared/providers/notification_provider.dart';
import 'package:kharis_app/shared/providers/onboarding_provider.dart';
import 'package:kharis_app/shared/providers/sermon_provider.dart';

// ── Fixtures ──────────────────────────────────────────────────────────────────

final _now = DateTime.now();

final _prayerNight = Event(
  id: 'e-prayer',
  title: 'Prayer Night',
  description: 'An evening of corporate prayer. All welcome.',
  location: 'Main Hall',
  address: '12 High Street, London',
  branch: 'London',
  startTime: _now.add(const Duration(days: 3)),
  endTime: _now.add(const Duration(days: 3, hours: 2)),
);

final _allCampusConference = Event(
  id: 'e-conf',
  title: 'Global Conference',
  location: 'ExCeL Centre',
  startTime: _now.add(const Duration(days: 9)),
);

final _manchesterPicnic = Event(
  id: 'e-picnic',
  title: 'Manchester Picnic',
  location: 'Heaton Park',
  branch: 'Manchester',
  startTime: _now.add(const Duration(days: 5)),
);

NewsItem _news(
  String id,
  String title, {
  String? branch,
  String? eventId,
  String? linkUrl,
  String? ctaLabel,
}) => NewsItem(
  id: id,
  title: title,
  type: 'Announcement',
  publishedAt: _now.subtract(const Duration(hours: 2)),
  branch: branch,
  eventId: eventId,
  linkUrl: linkUrl,
  ctaLabel: ctaLabel,
);

const _reading = DailyContent(
  reading: BibleReading(book: '2 Corinthians', chapter: 13, verse: '1-end'),
  prayer: 'Lord, make us complete.',
  prayerReference: '2 Corinthians 13:11',
  planDay: 13,
  planDays: 13,
);

// ── Harness ───────────────────────────────────────────────────────────────────

/// Mirrors the app's overlay routes (`/announcements`, `/notifications`,
/// `/events/:id`) exactly as app_router.dart builds them, around the screen
/// under test.
GoRouter _router(String initial, Widget Function() start) => GoRouter(
  initialLocation: initial,
  routes: [
    GoRoute(path: '/home', builder: (_, _) => start()),
    GoRoute(path: '/calendar', builder: (_, _) => const CalendarScreen()),
    GoRoute(
      path: '/notifications',
      builder: (_, _) => const NotificationsScreen(),
    ),
    GoRoute(
      path: '/announcements',
      builder: (_, state) => NotificationsScreen.announcements(
        focusId: state.uri.queryParameters['id'],
      ),
    ),
    GoRoute(
      path: '/events/:id',
      builder: (_, state) => EventDetailScreen(
        eventId: state.pathParameters['id']!,
        initial: state.extra is Event ? state.extra as Event : null,
      ),
    ),
    GoRoute(
      path: '/reading',
      builder: (_, _) => const Scaffold(body: Text('reader')),
    ),
  ],
);

Future<void> _pump(
  WidgetTester tester, {
  required Widget Function() start,
  String initial = '/home',
  String? branch = 'London',
  List<NewsItem> news = const [],
  List<Event> events = const [],
  Stream<DailyContent>? reading,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final prefs = await SharedPreferences.getInstance();
  final byId = {for (final e in events) e.id: e};
  tester.view.physicalSize = const Size(1200, 4000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        currentBranchProvider.overrideWith((ref) => Stream.value(branch)),
        currentUserProvider.overrideWith((ref) => Stream.value(null)),
        branchesProvider.overrideWith(
          (ref) => Stream.value(BranchRepository.seedBranches),
        ),
        newsProvider.overrideWith((ref, b) async => news),
        upcomingEventsProvider.overrideWith((ref, b) => Stream.value(events)),
        pastEventsProvider.overrideWith((ref, b) => Stream.value(const [])),
        myRsvpsProvider.overrideWith((ref) => Stream.value(const <Rsvp>[])),
        eventByIdProvider.overrideWith((ref, id) async => byId[id]),
        videosProvider.overrideWith((ref) async => const <Sermon>[]),
        liveStatusProvider.overrideWith(
          (ref) => Stream.value(LiveStatus.notLive),
        ),
        dailyContentProvider.overrideWith(
          (ref) => reading ?? Stream.value(_reading),
        ),
        // Nothing to resume: the card collapses (its engine is WP2's).
        continueListeningProvider.overrideWith((ref) => null),
      ],
      child: MaterialApp.router(routerConfig: _router(initial, start)),
    ),
  );
  await _frames(tester);
}

/// Home hosts endlessly pulsing skeletons (the hero with no videos), so it
/// never "settles"; advance enough fake time for streams, futures and a page
/// transition instead.
Future<void> _frames(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('navigation', () {
    testWidgets('Home "See all" opens the announcements feed; Back returns', (
      tester,
    ) async {
      await _pump(
        tester,
        start: () => const HomeScreen(),
        news: [_news('n1', 'Baptism sign-ups are open')],
      );

      await tester.tap(find.byKey(const Key('home-announcements-see-all')));
      await _frames(tester);

      // The announcements list, not the Events tab it used to jump to.
      expect(find.byType(NotificationsScreen), findsOneWidget);
      expect(find.widgetWithText(AppBar, 'Announcements'), findsOneWidget);
      expect(find.text('Baptism sign-ups are open'), findsOneWidget);
      expect(find.byType(CalendarScreen), findsNothing);

      // Pushed, so Back lands on Home rather than an empty stack.
      await tester.tap(find.byTooltip('Back'));
      await _frames(tester);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(NotificationsScreen), findsNothing);
    });

    testWidgets('tapping anywhere on an event card opens the event detail', (
      tester,
    ) async {
      await _pump(
        tester,
        initial: '/calendar',
        start: () => const HomeScreen(),
        events: [_prayerNight],
      );

      await tester.tap(find.text('Prayer Night'));
      await _frames(tester);

      expect(find.byType(EventDetailScreen), findsOneWidget);
      expect(
        find.text('An evening of corporate prayer. All welcome.'),
        findsOneWidget,
      );
      // Venue + address with directions, plus the calendar action.
      expect(find.text('Main Hall'), findsOneWidget);
      expect(find.text('12 High Street, London'), findsOneWidget);
      expect(find.text('Get directions'), findsOneWidget);
      expect(find.text('Add to calendar'), findsOneWidget);
    });

    testWidgets('an announcement linked to an event opens that event', (
      tester,
    ) async {
      await _pump(
        tester,
        start: () => const HomeScreen(),
        news: [
          _news('n-linked', 'Join us for prayer', eventId: _prayerNight.id),
        ],
        events: [_prayerNight],
      );

      await tester.tap(find.text('Join us for prayer'));
      await _frames(tester);

      final detail = tester.widget<EventDetailScreen>(
        find.byType(EventDetailScreen),
      );
      expect(detail.eventId, _prayerNight.id);
      expect(find.text('Prayer Night'), findsOneWidget);
    });

    testWidgets('a plain announcement with a link shows its call to action', (
      tester,
    ) async {
      await _pump(
        tester,
        start: () => const HomeScreen(),
        news: [
          _news(
            'n-cta',
            'Volunteer this Sunday',
            linkUrl: 'https://kharis.org/serve',
            ctaLabel: 'Sign up',
          ),
        ],
      );

      await tester.tap(find.text('Volunteer this Sunday'));
      await _frames(tester);

      expect(find.byType(EventDetailScreen), findsNothing);
      expect(find.byKey(const Key('announcement-cta')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('announcement-cta')),
          matching: find.text('Sign up'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('event push deep link opens the event detail', (tester) async {
      await _pump(
        tester,
        start: () => const HomeScreen(),
        events: [_prayerNight],
      );
      final router = GoRouter.of(tester.element(find.byType(HomeScreen)));

      openNotificationTarget(
        router,
        notificationTargetFor({'type': 'event', 'eventId': _prayerNight.id}),
      );
      await _frames(tester);

      expect(find.byType(EventDetailScreen), findsOneWidget);
      expect(find.text('Prayer Night'), findsOneWidget);
      // Pushed above Home: Back has somewhere to go.
      expect(router.canPop(), isTrue);
    });
  });

  group('location on cards', () {
    testWidgets('Home shows the venue on event-linked announcements and on '
        'upcoming event tiles', (tester) async {
      await _pump(
        tester,
        start: () => const HomeScreen(),
        news: [
          _news('n-linked', 'Join us for prayer', eventId: _prayerNight.id),
        ],
        events: [_prayerNight],
      );

      // Announcement card: "venue · address" of the linked event.
      expect(
        find.text('Main Hall \u00b7 12 High Street, London'),
        findsOneWidget,
      );
      // Upcoming events strip tile: the venue.
      expect(find.text('Main Hall'), findsOneWidget);
    });

    testWidgets('event cards on the Events tab show the venue', (tester) async {
      await _pump(
        tester,
        initial: '/calendar',
        start: () => const HomeScreen(),
        events: [_prayerNight],
      );

      expect(find.text('Main Hall'), findsOneWidget);
    });
  });

  group('campus scoping', () {
    testWidgets('Home shows the member campus plus all-campus items only', (
      tester,
    ) async {
      await _pump(
        tester,
        start: () => const HomeScreen(),
        news: [
          _news('n-lon', 'London notice', branch: 'London'),
          _news('n-all', 'All-campus notice'),
          _news('n-blank', 'Blank-campus notice', branch: ''),
          _news('n-man', 'Manchester notice', branch: 'Manchester'),
        ],
        events: [_prayerNight, _allCampusConference, _manchesterPicnic],
      );

      expect(find.text('London notice'), findsOneWidget);
      expect(find.text('All-campus notice'), findsOneWidget);
      expect(find.text('Blank-campus notice'), findsOneWidget);
      expect(find.text('Manchester notice'), findsNothing);

      expect(find.text('Prayer Night'), findsOneWidget);
      expect(find.text('Global Conference'), findsOneWidget);
      expect(find.text('Manchester Picnic'), findsNothing);
    });

    test('a member on All campuses sees every campus', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final container = ProviderContainer(
        overrides: [
          currentBranchProvider.overrideWith((ref) => Stream.value(null)),
          newsProvider.overrideWith(
            (ref, b) async => [
              _news('n-lon', 'London notice', branch: 'London'),
              _news('n-man', 'Manchester notice', branch: 'Manchester'),
            ],
          ),
          upcomingEventsProvider.overrideWith(
            (ref, b) => Stream.value([_prayerNight, _manchesterPicnic]),
          ),
        ],
      );
      addTearDown(container.dispose);
      final news = container.listen(campusNewsProvider, (_, _) {});
      final events = container.listen(campusUpcomingEventsProvider, (_, _) {});
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(news.read().value!.map((n) => n.id), ['n-lon', 'n-man']);
      expect(events.read().value!.map((e) => e.id), ['e-prayer', 'e-picnic']);
    });

    test(
      'nothing is fetched unscoped while the campus is still resolving',
      () async {
        final asked = <String?>[];
        final container = ProviderContainer(
          overrides: [
            currentBranchProvider.overrideWith((ref) => const Stream.empty()),
            newsProvider.overrideWith((ref, b) async {
              asked.add(b);
              return const <NewsItem>[];
            }),
          ],
        );
        addTearDown(container.dispose);
        final sub = container.listen(campusNewsProvider, (_, _) {});
        await Future<void>.delayed(const Duration(milliseconds: 20));

        expect(sub.read().isLoading, isTrue);
        expect(asked, isEmpty);
      },
    );
  });

  group('states', () {
    testWidgets('announcements: loading skeleton, then error with Retry', (
      tester,
    ) async {
      var calls = 0;
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            currentBranchProvider.overrideWith((ref) => Stream.value('London')),
            newsProvider.overrideWith((ref, b) async {
              calls++;
              await Future<void>.delayed(const Duration(milliseconds: 100));
              throw Exception('offline');
            }),
            upcomingEventsProvider.overrideWith(
              (ref, b) => Stream.value(const <Event>[]),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(body: AnnouncementsCarousel()),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const Key('announcements-skeleton')), findsOneWidget);
      expect(find.text('No announcements'), findsNothing);

      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump();
      expect(find.text('Couldn\u2019t load announcements.'), findsOneWidget);
      expect(find.text('No announcements'), findsNothing);

      await tester.tap(find.text('Retry'));
      await tester.pump();
      expect(calls, 2);
      await tester.pump(const Duration(milliseconds: 150));
    });

    testWidgets('reading card: failure shows an error card with Retry, '
        'never a made-up reading', (tester) async {
      var subscriptions = 0;
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            dailyContentProvider.overrideWith((ref) {
              subscriptions++;
              return Stream<DailyContent>.error(Exception('offline'));
            }),
          ],
          child: const MaterialApp(home: Scaffold(body: TodaysReadingCard())),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const Key('reading-card-error')), findsOneWidget);
      expect(
        find.text('We couldn\u2019t load today\u2019s reading.'),
        findsOneWidget,
      );
      expect(find.textContaining('Psalm'), findsNothing);

      await tester.tap(find.text('Retry'));
      await tester.pump();
      expect(subscriptions, 2);
    });

    testWidgets('reading card: skeleton while loading, plan day once loaded', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            dailyContentProvider.overrideWith((ref) async* {
              await Future<void>.delayed(const Duration(milliseconds: 100));
              yield _reading;
            }),
          ],
          child: const MaterialApp(home: Scaffold(body: TodaysReadingCard())),
        ),
      );
      await tester.pump();
      expect(find.byKey(const Key('reading-card-loading')), findsOneWidget);
      expect(find.text('Loading...'), findsNothing);

      await tester.pump(const Duration(milliseconds: 150));
      // The real plan position, not the day of the year.
      expect(find.text("TODAY'S READING \u00b7 DAY 13 OF 13"), findsOneWidget);
      expect(find.text('2 Corinthians 13'), findsOneWidget);
    });
  });

  group('reading', () {
    test('Mark as read persists the date and toggles back off', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);
      final day = DateTime(2026, 10, 3);

      await container.read(readingMarksProvider.notifier).toggle(day);
      expect(container.read(readingMarksProvider), {'2026-10-03'});
      expect(prefs.getStringList(ReadingMarksController.prefsKey), [
        '2026-10-03',
      ]);

      // A fresh controller (next launch) reads the mark back.
      final relaunch = ReadingMarksController(prefs);
      expect(relaunch.isRead(day), isTrue);

      await container.read(readingMarksProvider.notifier).toggle(day);
      expect(container.read(readingMarksProvider), isEmpty);
    });

    testWidgets('a reading past the end of its book explains itself', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            dailyContentProvider.overrideWith(
              (ref) => Stream.value(
                const DailyContent(
                  reading: BibleReading(
                    book: '2 Corinthians',
                    chapter: 17,
                    verse: '1-end',
                  ),
                  prayer: '',
                  prayerReference: '',
                ),
              ),
            ),
          ],
          child: const MaterialApp(home: ReadingScreen()),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(
        find.text('Today\u2019s reading isn\u2019t available'),
        findsOneWidget,
      );
      expect(
        find.textContaining('2 Corinthians has 13 chapters'),
        findsOneWidget,
      );
      expect(find.text('Retry'), findsNothing);
    });
  });

  group('notification permission (C7)', () {
    testWidgets('not requested before onboarding completes; requested once '
        'after', (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();
      final fcm = _RecordingNotificationService();
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(path: '/', builder: (_, _) => const Text('welcome')),
          GoRoute(path: '/branch', builder: (_, _) => const Text('branch')),
          GoRoute(path: '/home', builder: (_, _) => const Text('home')),
        ],
      );
      addTearDown(router.dispose);
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          appRouterProvider.overrideWithValue(router),
          notificationServiceProvider.overrideWithValue(fcm),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );

      container.read(notificationPermissionGateProvider);
      await tester.pump();
      router.go('/branch');
      await tester.pumpAndSettle();
      expect(
        fcm.permissionRequests,
        0,
        reason: 'no OS prompt over the welcome / onboarding screens',
      );

      // Onboarding finishes, then the flow navigates into the app.
      await container
          .read(onboardingRepositoryProvider)
          .completeOnboarding(role: 'member', branch: 'London');
      router.go('/home');
      await tester.pumpAndSettle();
      expect(fcm.permissionRequests, 1);

      router.go('/branch');
      await tester.pumpAndSettle();
      expect(fcm.permissionRequests, 1, reason: 'asked once, never again');
    });
  });

  group('push routing', () {
    test('every push type lands on its screen, overlays pushed', () {
      expect(
        notificationTargetFor({'type': 'announcement', 'newsId': 'n1'}),
        const NotificationTarget('/announcements?id=n1', overlay: true),
      );
      expect(
        notificationTargetFor({'type': 'announcement', 'eventId': 'e1'}),
        const NotificationTarget('/events/e1', overlay: true),
      );
      expect(
        notificationTargetFor({'type': 'event', 'eventId': 'e1'}),
        const NotificationTarget('/events/e1', overlay: true),
      );
      expect(
        notificationTargetFor({'type': 'event'}),
        const NotificationTarget('/calendar'),
      );
      expect(
        notificationTargetFor({'type': 'service_reminder'}),
        const NotificationTarget('/home'),
      );
      expect(
        notificationTargetFor({'type': 'reading'}),
        const NotificationTarget('/reading', overlay: true),
      );
      expect(
        notificationTargetFor({'type': 'birthday'}),
        const NotificationTarget('/home'),
      );
    });

    testWidgets('announcement push opens that announcement in the feed', (
      tester,
    ) async {
      await _pump(
        tester,
        start: () => const HomeScreen(),
        news: [
          _news('n1', 'Baptism sign-ups are open', linkUrl: 'https://k.org'),
        ],
      );
      final router = GoRouter.of(tester.element(find.byType(HomeScreen)));
      openNotificationTarget(
        router,
        notificationTargetFor({'type': 'announcement', 'newsId': 'n1'}),
      );
      await _frames(tester);

      expect(find.widgetWithText(AppBar, 'Announcements'), findsOneWidget);
      expect(find.byKey(const Key('announcement-cta')), findsOneWidget);
    });
  });

  group('admin guard (U12)', () {
    Future<GoRouter> guarded(WidgetTester tester, {required bool admin}) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();
      late GoRouter router;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            currentUserProvider.overrideWith(
              (ref) => Stream.value(
                User(
                  id: 'u1',
                  email: 'a@kharis.org',
                  displayName: 'A',
                  role: admin ? 'admin' : 'member',
                  createdAt: DateTime(2024),
                ),
              ),
            ),
            isAdminProvider.overrideWith((ref) async => admin),
          ],
          child: Consumer(
            builder: (context, ref, _) {
              router = GoRouter(
                initialLocation: '/home',
                redirect: ref.read(routerNotifierProvider).redirect,
                routes: [
                  GoRoute(path: '/home', builder: (_, _) => const Text('home')),
                  GoRoute(
                    path: '/admin',
                    builder: (_, _) => const Text('admin'),
                  ),
                ],
              );
              return MaterialApp.router(routerConfig: router);
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      return router;
    }

    testWidgets('a member is bounced off /admin', (tester) async {
      final router = await guarded(tester, admin: false);
      router.go('/admin');
      await tester.pumpAndSettle();
      expect(find.text('admin'), findsNothing);
      expect(find.text('home'), findsOneWidget);
    });

    testWidgets('an admin gets in', (tester) async {
      final router = await guarded(tester, admin: true);
      router.go('/admin');
      await tester.pumpAndSettle();
      expect(find.text('admin'), findsOneWidget);
    });
  });
}

class _RecordingNotificationService extends NotificationService {
  int permissionRequests = 0;

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return false;
  }
}
