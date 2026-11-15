// The Events list (`/calendar`) and the event detail (`/events/:id`): what a
// member sees and can do, the loading, empty and error states, where taps
// lead, and layout at the 390 design width in light and dark at 100% and
// 130% text size.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kharis_app/core/services/notification_service.dart';
import 'package:kharis_app/features/calendar/data/event_repository.dart';
import 'package:kharis_app/features/calendar/data/rsvp_repository.dart';
import 'package:kharis_app/features/calendar/presentation/screens/calendar_screen.dart';
import 'package:kharis_app/features/calendar/presentation/screens/event_detail_screen.dart';
import 'package:kharis_app/features/calendar/presentation/widgets/event_card.dart';
import 'package:kharis_app/features/onboarding/data/branch_repository.dart';
import 'package:kharis_app/shared/models/user.dart';
import 'package:kharis_app/shared/providers/admin_provider.dart';
import 'package:kharis_app/shared/providers/auth_provider.dart';
import 'package:kharis_app/shared/providers/branch_provider.dart';
import 'package:kharis_app/shared/providers/cache_provider.dart';
import 'package:kharis_app/shared/providers/event_reminders_provider.dart';
import 'package:kharis_app/shared/providers/location_provider.dart';
import 'package:kharis_app/shared/providers/notification_feed_provider.dart';
import 'package:kharis_app/shared/providers/notification_provider.dart';
import 'package:kharis_app/shared/providers/onboarding_provider.dart';
import 'package:kharis_app/shared/providers/sermon_provider.dart';
import 'package:kharis_app/ui/components/components.dart';

import 'support/design_harness.dart';
import 'support/fake_cache_service.dart';
import 'support/fake_location_service.dart';
import 'support/fake_reminder_notifications.dart';

const _phone = Size(KSize.designWidth, 844);

/// The app's permission prompt, answered by the test.
class _Prompt extends NotificationService {
  _Prompt({required this.answer});

  final bool answer;

  @override
  Future<bool> requestPermission() async => answer;

  @override
  Future<void> switchBranchTopic({String? from, String? to}) async {}
}

/// The member's RSVPs, kept in memory.
class _Rsvps implements RsvpRepository {
  final Set<String> going = {};
  final StreamController<void> _changes = StreamController.broadcast();

  List<Rsvp> get _list => [
    for (final id in going)
      Rsvp(id: 'u1_$id', userId: 'u1', eventId: id, eventStartTime: _soon),
  ];

  @override
  Future<bool> toggleRsvp(Event event, {String? branch}) async {
    final added = going.add(event.id);
    if (!added) going.remove(event.id);
    _changes.add(null);
    return added;
  }

  @override
  Stream<List<Rsvp>> watchMyRsvps() async* {
    yield _list;
    await for (final _ in _changes.stream) {
      yield _list;
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final _member = User(
  id: 'u1',
  email: 'member@kharis.org',
  displayName: 'Grace Member',
  role: 'member',
  createdAt: DateTime(2024),
);

const _london = Branch(
  id: 'london',
  name: 'London',
  subtitle: 'England',
);

DateTime _at(int daysAhead, int hour, [int minute = 0]) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day + daysAhead, hour, minute);
}

final DateTime _soon = _at(3, 19);

final _prayerNight = Event(
  id: 'e-prayer',
  title: 'Prayer Night',
  description: 'An evening of corporate prayer. All welcome.',
  location: 'Main Hall',
  address: '12 High Street, London',
  branch: 'London',
  startTime: _soon,
  endTime: _at(3, 21),
);

/// Sunday and Wednesday at 09:00; next on [_at] 2 days from now.
final _sundayService = Event(
  id: 'e-sunday',
  title: 'Sunday Service',
  location: 'The Lighthouse Theatre',
  branch: 'London',
  startTime: _at(2, 9),
  endTime: _at(2, 10, 30),
  recurrenceDays: const [0, 3],
);

final _carols = Event(
  id: 'e-carols',
  title: 'Carols by Candlelight',
  location: 'Main Hall',
  branch: 'London',
  startTime: _at(-20, 18),
  endTime: _at(-20, 20),
);

String _listWhen(Event e) =>
    DateFormat('EEE d MMM \u00b7 HH:mm').format(e.startTime);

class _Harness {
  final FakeCacheService cache = FakeCacheService();
  final FakeReminderNotifications notifications = FakeReminderNotifications();
  final _Rsvps rsvps = _Rsvps();
  final List<String> launched = [];
  final List<Map<Object?, Object?>> calendarAdds = [];
  final List<String> shared = [];

  /// How many times the upcoming events were fetched.
  int upcomingLoads = 0;

  late final GoRouter router;

  Future<void> pump(
    WidgetTester tester, {
    String initial = '/calendar',
    AsyncValue<List<Event>>? upcoming,
    AsyncValue<List<Event>> past = const AsyncData([]),
    Map<String, Event> byId = const {},
    Future<Event?> Function(String id)? loadEvent,
    User? user,
    bool allowNotifications = true,
    RsvpEvents? myRsvps,
    bool dark = false,
    double textScale = 1,
  }) async {
    tester.view.physicalSize = _phone;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    _mockChannels();

    router = GoRouter(
      initialLocation: initial,
      routes: [
        GoRoute(
          path: '/home',
          builder: (_, _) => const Scaffold(body: Text('home screen')),
        ),
        GoRoute(path: '/calendar', builder: (_, _) => const CalendarScreen()),
        GoRoute(
          path: '/events/:id',
          builder: (_, state) => EventDetailScreen(
            eventId: state.pathParameters['id']!,
            initial: state.extra is Event ? state.extra as Event : null,
          ),
        ),
        GoRoute(
          path: '/login',
          builder: (_, _) => const Scaffold(body: Text('login screen')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          cacheServiceProvider.overrideWithValue(cache),
          reminderNotificationsProvider.overrideWithValue(notifications),
          eventReminderStartupProvider.overrideWith((ref) async {}),
          notificationPermissionProvider.overrideWith(
            (ref) async => allowNotifications
                ? NotificationPermission.granted
                : NotificationPermission.askable,
          ),
          notificationServiceProvider.overrideWithValue(
            _Prompt(answer: allowNotifications),
          ),
          notificationPermissionAnsweredProvider.overrideWithValue(
            (granted) async {},
          ),
          locationServiceProvider.overrideWithValue(FakeLocationService()),
          branchesProvider.overrideWith((ref) => Stream.value(const [_london])),
          currentBranchProvider.overrideWith((ref) => Stream.value('London')),
          currentUserProvider.overrideWith((ref) => Stream.value(user)),
          rsvpRepositoryProvider.overrideWithValue(rsvps),
          if (upcoming != null)
            eventsUpcomingProvider.overrideWithValue(upcoming),
          upcomingEventsProvider.overrideWith((ref, branch) {
            upcomingLoads++;
            return Stream.value(const <Event>[]);
          }),
          eventsPastProvider.overrideWithValue(past),
          if (myRsvps != null)
            myRsvpEventsProvider.overrideWith((ref) async => myRsvps),
          eventByIdProvider.overrideWith(
            (ref, id) => loadEvent != null ? loadEvent(id) : byId[id],
          ),
        ],
        // As in the app, where the router keeps the session loaded.
        child: Consumer(
          builder: (context, ref, app) {
            ref.watch(currentUserProvider);
            return app!;
          },
          child: MaterialApp.router(
            debugShowCheckedModeBanner: false,
            theme: KharisTheme.light(),
            darkTheme: KharisTheme.dark(),
            themeMode: dark ? ThemeMode.dark : ThemeMode.light,
            builder: (context, app) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(textScale),
                disableAnimations: true,
              ),
              child: app!,
            ),
            routerConfig: router,
          ),
        ),
      ),
    );
    await settle(tester);
  }

  /// Lets streams, futures and a page transition finish. Skeletons and
  /// snack bars keep the tree from ever "settling".
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
  }

  void _mockChannels() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const urlLauncher = MethodChannel('plugins.flutter.io/url_launcher');
    const calendar = MethodChannel('add_2_calendar_new');
    const share = MethodChannel('dev.fluttercommunity.plus/share');
    messenger.setMockMethodCallHandler(urlLauncher, (call) async {
      if (call.method == 'launch') {
        launched.add((call.arguments as Map)['url']! as String);
      }
      return true;
    });
    messenger.setMockMethodCallHandler(calendar, (call) async {
      calendarAdds.add(call.arguments as Map);
      return true;
    });
    messenger.setMockMethodCallHandler(share, (call) async {
      shared.add((call.arguments as Map)['text'] as String);
      return 'dev.fluttercommunity.plus/share/unavailable';
    });
    addTearDown(() {
      for (final channel in const [urlLauncher, calendar, share]) {
        messenger.setMockMethodCallHandler(channel, null);
      }
    });
  }

  /// The path of the screen on top, pushed or not.
  String get location => Uri.parse(
    router.routerDelegate.currentConfiguration.matches.last.matchedLocation,
  ).path;
}

Finder _card(Event event) =>
    find.byWidgetPredicate((w) => w is EventCard && w.event.id == event.id);

Finder _in(Finder scope, Finder what) =>
    find.descendant(of: scope, matching: what);

Future<void> _tapTab(WidgetTester tester, _Harness h, String label) async {
  await tester.tap(find.text(label));
  await h.settle(tester);
}

Future<void> _tap(WidgetTester tester, _Harness h, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await h.settle(tester);
}

void _forEachMode(
  String name,
  Future<void> Function(WidgetTester tester, bool dark, double scale) body,
) {
  for (final dark in const [false, true]) {
    for (final scale in const [1.0, 1.3, 2.0]) {
      testWidgets('$name \u00b7 ${dark ? 'dark' : 'light'} \u00b7 '
          '${(scale * 100).round()}%', (tester) async {
        await body(tester, dark, scale);
        expect(tester.takeException(), isNull);
      });
    }
  }
}

void main() {
  setUpAll(loadDesignAssets);

  late _Harness h;
  setUp(() => h = _Harness());

  group('Events list', () {
    testWidgets('names the screen and the branch, with three tabs and no '
        'back button', (tester) async {
      await h.pump(tester, upcoming: AsyncData([_prayerNight]));

      expect(find.text('Events'), findsOneWidget);
      expect(find.text('Your branch \u00b7 London'), findsOneWidget);
      expect(find.byType(KTabs), findsOneWidget);
      for (final tab in ['Upcoming', 'Past', 'My RSVPs']) {
        expect(find.text(tab), findsOneWidget);
      }
      expect(find.byType(BackButton), findsNothing);
      expect(find.byTooltip('Back'), findsNothing);
    });

    testWidgets('a card shows the date, the title, when and where', (
      tester,
    ) async {
      await h.pump(tester, upcoming: AsyncData([_sundayService, _prayerNight]));

      final prayer = _card(_prayerNight);
      expect(_in(prayer, find.text('Prayer Night')), findsOneWidget);
      expect(
        _in(prayer, find.text(DateFormat('MMM').format(_soon))),
        findsOneWidget,
      );
      expect(_in(prayer, find.text('${_soon.day}')), findsOneWidget);
      expect(
        _in(prayer, find.text('${_listWhen(_prayerNight)}\nMain Hall')),
        findsOneWidget,
      );

      // A weekly event is one card that says when it repeats, on the
      // 24-hour clock.
      expect(
        _in(
          _card(_sundayService),
          find.text(
            'Every Sunday and Wednesday \u00b7 09:00\nThe Lighthouse Theatre',
          ),
        ),
        findsOneWidget,
      );
    });

    testWidgets('tapping a card opens that event', (tester) async {
      await h.pump(
        tester,
        upcoming: AsyncData([_prayerNight]),
        byId: {_prayerNight.id: _prayerNight},
      );

      await tester.tap(find.text('Prayer Night'));
      await h.settle(tester);

      expect(h.location, '/events/e-prayer');
      expect(
        tester
            .widget<EventDetailScreen>(find.byType(EventDetailScreen))
            .eventId,
        'e-prayer',
      );
    });

    testWidgets('"Remind me" schedules a reminder, says so, and turns off '
        'again', (tester) async {
      await h.pump(tester, upcoming: AsyncData([_prayerNight]));
      expect(find.text('Remind me'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Remind me about Prayer Night'),
        findsOneWidget,
      );

      await tester.tap(find.text('Remind me'));
      await h.settle(tester);

      expect(find.text('Reminder on'), findsOneWidget);
      expect(find.text('Remind me'), findsNothing);
      expect(
        find.text('We\u2019ll remind you an hour before Prayer Night.'),
        findsOneWidget,
      );
      expect(
        h.notifications.scheduled.values.single.at,
        _soon.subtract(const Duration(hours: 1)),
      );
      // Still on the list: the toggle does not open the event.
      expect(h.location, '/calendar');

      await tester.tap(find.text('Reminder on'));
      await h.settle(tester);

      expect(find.text('Remind me'), findsOneWidget);
      expect(find.text('Reminder off for Prayer Night.'), findsOneWidget);
      expect(h.notifications.scheduled, isEmpty);
    });

    testWidgets('a refused notification permission keeps the reminder off '
        'and says why', (tester) async {
      await h.pump(
        tester,
        upcoming: AsyncData([_prayerNight]),
        allowNotifications: false,
      );

      await tester.tap(find.text('Remind me'));
      await h.settle(tester);

      expect(find.text('Remind me'), findsOneWidget);
      expect(
        find.text(
          'Notifications are off. Turn them on in Settings to get reminders.',
        ),
        findsOneWidget,
      );
      expect(h.notifications.scheduled, isEmpty);
    });

    testWidgets('a reminder the phone cannot schedule stays off and says so', (
      tester,
    ) async {
      h.notifications.failScheduling = true;
      await h.pump(tester, upcoming: AsyncData([_prayerNight]));

      await tester.tap(find.text('Remind me'));
      await h.settle(tester);

      expect(find.text('Remind me'), findsOneWidget);
      expect(
        find.text('Couldn\u2019t set the reminder. Please try again.'),
        findsOneWidget,
      );
    });

    testWidgets('no "Remind me" on an event that starts within the hour or '
        'has finished', (tester) async {
      final startingNow = Event(
        id: 'e-now',
        title: 'Worship Night',
        startTime: DateTime.now().add(const Duration(minutes: 20)),
      );
      await h.pump(
        tester,
        upcoming: AsyncData([startingNow]),
        past: AsyncData([_carols]),
      );

      expect(_card(startingNow), findsOneWidget);
      expect(find.text('Remind me'), findsNothing);

      await _tapTab(tester, h, 'Past');
      expect(_card(_carols), findsOneWidget);
      expect(find.text('Remind me'), findsNothing);
    });

    testWidgets('loading shows card-sized blocks, not an empty state', (
      tester,
    ) async {
      await h.pump(tester, upcoming: const AsyncLoading());

      expect(find.byType(KSkeleton), findsWidgets);
      expect(find.byType(EventCard), findsNothing);
      expect(find.text('No upcoming events'), findsNothing);
    });

    testWidgets('a failed load says what to do; Retry loads again', (
      tester,
    ) async {
      await h.pump(
        tester,
        upcoming: AsyncError(StateError('offline'), StackTrace.empty),
      );

      expect(
        find.text('Events didn\u2019t load. Check your connection and retry.'),
        findsOneWidget,
      );
      final before = h.upcomingLoads;
      await tester.tap(find.text('Retry'));
      await h.settle(tester);
      expect(h.upcomingLoads, greaterThan(before));
    });

    testWidgets('no events: an empty state names the branch and leads to '
        'past events', (tester) async {
      await h.pump(tester, upcoming: const AsyncData([]));

      expect(find.text('No upcoming events'), findsOneWidget);
      expect(
        find.text('Check back soon for events at London.'),
        findsOneWidget,
      );

      await tester.tap(find.text('See past events'));
      await h.settle(tester);

      expect(find.text('No past events'), findsOneWidget);
    });

    testWidgets('a full Past list says it is only the most recent events', (
      tester,
    ) async {
      final past = [
        for (var i = 0; i < EventRepository.pastEventLimit; i++)
          Event(
            id: 'past-$i',
            title: 'Past event $i',
            startTime: _at(-10 - i, 18),
          ),
      ];
      await h.pump(
        tester,
        upcoming: const AsyncData([]),
        past: AsyncData(past),
      );
      await _tapTab(tester, h, 'Past');

      await tester.scrollUntilVisible(
        find.textContaining('most recent events'),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.text(
          'Showing the 15 most recent events. Anything older is no longer '
          'listed.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('My RSVPs asks a signed-out member to sign in', (tester) async {
      await h.pump(tester, upcoming: AsyncData([_prayerNight]));
      await _tapTab(tester, h, 'My RSVPs');

      expect(find.text('Sign in to see your RSVPs'), findsOneWidget);

      await tester.tap(find.text('Sign in'));
      await h.settle(tester);
      expect(h.location, '/login');
    });

    testWidgets('My RSVPs with none leads back to upcoming events', (
      tester,
    ) async {
      await h.pump(tester, upcoming: AsyncData([_prayerNight]), user: _member);
      await _tapTab(tester, h, 'My RSVPs');

      expect(find.text('No RSVPs yet'), findsOneWidget);

      await tester.tap(find.text('See upcoming events'));
      await h.settle(tester);
      expect(_card(_prayerNight), findsOneWidget);
    });

    testWidgets('My RSVPs groups events into Upcoming and Past', (
      tester,
    ) async {
      await h.pump(
        tester,
        upcoming: const AsyncData([]),
        user: _member,
        myRsvps: RsvpEvents(upcoming: [_prayerNight], past: [_carols]),
      );
      await _tapTab(tester, h, 'My RSVPs');

      final upcoming = tester.getTopLeft(find.text('Upcoming').last).dy;
      final prayer = tester.getTopLeft(_card(_prayerNight)).dy;
      final past = tester.getTopLeft(find.text('Past').last).dy;
      final carols = tester.getTopLeft(_card(_carols)).dy;
      expect(upcoming, lessThan(prayer));
      expect(prayer, lessThan(past));
      expect(past, lessThan(carols));
    });

    testWidgets('the branch line opens the branch list; "All branches" only '
        'widens this list', (tester) async {
      await h.pump(tester, upcoming: AsyncData([_prayerNight]));

      await tester.tap(find.text('Your branch \u00b7 London'));
      await h.settle(tester);

      expect(find.text('Choose your branch'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('branch-choice-all')));
      await h.settle(tester);

      expect(find.text('Showing \u00b7 All branches'), findsOneWidget);
      expect(find.text('Your branch \u00b7 London'), findsNothing);
    });
  });

  group('Event detail', () {
    Future<void> open(
      WidgetTester tester,
      Event event, {
      User? user,
      String? initial,
    }) => h.pump(
      tester,
      initial: initial ?? '/events/${event.id}',
      upcoming: AsyncData([event]),
      byId: {event.id: event},
      user: user,
    );

    testWidgets('shows what, when and where, with one main button', (
      tester,
    ) async {
      await open(tester, _prayerNight);

      expect(find.text('IN 3 DAYS'), findsOneWidget);
      expect(find.text('Prayer Night'), findsOneWidget);
      expect(
        find.text(DateFormat('EEEE d MMMM yyyy').format(_soon)),
        findsOneWidget,
      );
      expect(find.text('19:00 \u2013 21:00'), findsOneWidget);
      final venue = find.byKey(const Key('event-detail-venue'));
      expect(_in(venue, find.text('Main Hall')), findsOneWidget);
      expect(_in(venue, find.text('12 High Street, London')), findsOneWidget);
      expect(find.text('London'), findsOneWidget);
      expect(
        find.text('An evening of corporate prayer. All welcome.'),
        findsOneWidget,
      );
      for (final action in [
        'Remind me',
        'Get directions',
        'RSVP',
        'Add to calendar',
        'Share',
        'All events',
      ]) {
        expect(find.text(action), findsOneWidget, reason: action);
      }
      expect(find.byType(BackButton), findsNothing);
      expect(find.byTooltip('Back'), findsNothing);
      // No photo: no empty image block.
      expect(find.byType(KImageFill), findsNothing);
    });

    testWidgets('a weekly event says when it repeats and when it is next', (
      tester,
    ) async {
      await open(tester, _sundayService);

      expect(
        _in(
          find.byKey(const Key('event-detail-recurrence')),
          find.text('EVERY SUNDAY AND WEDNESDAY'),
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          'Next: ${DateFormat('EEEE d MMMM yyyy').format(_sundayService.startTime)}',
        ),
        findsOneWidget,
      );
      expect(find.text('09:00 \u2013 10:30'), findsOneWidget);
    });

    testWidgets('an event with a photo shows it at 16:9', (tester) async {
      await open(
        tester,
        Event(
          id: 'e-photo',
          title: 'Baptism Sunday',
          startTime: _soon,
          imageUrl: 'https://cdn.test/baptism.jpg',
        ),
      );

      final image = tester.getSize(find.byType(KImageFill));
      expect(image.width / image.height, closeTo(16 / 9, 0.01));
    });

    testWidgets('"Remind me" turns into "Reminder on" and back', (
      tester,
    ) async {
      await open(tester, _prayerNight);

      await _tap(tester, h, find.text('Remind me'));
      expect(find.text('Reminder on'), findsOneWidget);
      expect(
        find.text('We\u2019ll remind you an hour before Prayer Night.'),
        findsOneWidget,
      );
      expect(h.notifications.scheduled, hasLength(1));

      await _tap(tester, h, find.text('Reminder on'));
      expect(find.text('Remind me'), findsOneWidget);
      expect(h.notifications.scheduled, isEmpty);
    });

    testWidgets('a finished event offers no reminder and no RSVP', (
      tester,
    ) async {
      await open(tester, _carols);

      expect(find.text('THIS EVENT HAS ENDED'), findsOneWidget);
      expect(find.text('Remind me'), findsNothing);
      expect(find.text('RSVP'), findsNothing);
      expect(find.text('Add to calendar'), findsOneWidget);
      expect(find.text('Share'), findsOneWidget);
    });

    testWidgets('RSVP while signed out asks the member to sign in', (
      tester,
    ) async {
      await open(tester, _prayerNight);

      await _tap(tester, h, find.text('RSVP'));
      expect(find.text('Sign in to RSVP to events.'), findsOneWidget);
      expect(h.rsvps.going, isEmpty);

      await tester.tap(find.text('Sign in'));
      await h.settle(tester);
      expect(h.location, '/login');
    });

    testWidgets('RSVP turns into "Going"; tapping it again cancels', (
      tester,
    ) async {
      await open(tester, _prayerNight, user: _member);

      await _tap(tester, h, find.text('RSVP'));
      expect(find.text('Going'), findsOneWidget);
      expect(find.text('You\u2019re going to Prayer Night.'), findsOneWidget);
      expect(h.rsvps.going, {_prayerNight.id});

      await _tap(tester, h, find.text('Going'));
      expect(find.text('RSVP'), findsOneWidget);
      expect(h.rsvps.going, isEmpty);
    });

    testWidgets('"Get directions" opens maps for the venue and address', (
      tester,
    ) async {
      await open(tester, _prayerNight);

      await _tap(tester, h, find.text('Get directions'));

      final url = Uri.parse(h.launched.single);
      expect(url.host, 'www.google.com');
      expect(url.queryParameters['query'], 'Main Hall, 12 High Street, London');
    });

    testWidgets('"Add to calendar" hands the event to the calendar', (
      tester,
    ) async {
      await open(tester, _prayerNight);

      await _tap(tester, h, find.text('Add to calendar'));

      final added = h.calendarAdds.single;
      expect(added['title'], 'Prayer Night');
      expect(added['startDate'], _soon.millisecondsSinceEpoch);
    });

    testWidgets('"Share" shares the event text with its Kharis link', (
      tester,
    ) async {
      await open(tester, _prayerNight);

      await _tap(tester, h, find.text('Share'));

      expect(h.shared.single, eventShareText(_prayerNight));
    });

    testWidgets('"All events" returns to the list when it is underneath', (
      tester,
    ) async {
      await open(tester, _prayerNight, initial: '/calendar');
      await tester.tap(find.text('Prayer Night'));
      await h.settle(tester);
      expect(h.location, '/events/e-prayer');

      await _tap(tester, h, find.text('All events'));

      expect(h.location, '/calendar');
      expect(h.router.canPop(), isFalse);
    });

    testWidgets('"All events" opens the list when the event was opened '
        'directly', (tester) async {
      await open(tester, _prayerNight);

      await _tap(tester, h, find.text('All events'));

      expect(h.location, '/calendar');
      expect(find.byType(CalendarScreen), findsOneWidget);
      // Back returns to the event.
      expect(h.router.canPop(), isTrue);
    });

    testWidgets('loading shows blocks, then the event', (tester) async {
      final loaded = Completer<Event?>();
      await h.pump(
        tester,
        initial: '/events/e-prayer',
        upcoming: const AsyncData([]),
        loadEvent: (_) => loaded.future,
      );

      expect(find.byType(KSkeleton), findsWidgets);
      expect(find.text('Prayer Night'), findsNothing);

      loaded.complete(_prayerNight);
      await h.settle(tester);

      expect(find.byType(KSkeleton), findsNothing);
      expect(find.text('Prayer Night'), findsOneWidget);
    });

    testWidgets('an event that is gone says so; "Try again" reads it again '
        'and "All events" opens the list', (tester) async {
      var reads = 0;
      await h.pump(
        tester,
        initial: '/events/gone',
        upcoming: const AsyncData([]),
        loadEvent: (_) async {
          reads++;
          return null;
        },
      );

      expect(find.text('This event isn\u2019t available'), findsOneWidget);
      expect(find.text('Remind me'), findsNothing);

      await tester.tap(find.text('Try again'));
      await h.settle(tester);
      expect(reads, 2);

      await tester.tap(find.text('All events'));
      await h.settle(tester);
      expect(h.location, '/calendar');
    });
  });

  group('layout at 390 wide', () {
    final longEvent = Event(
      id: 'e-long',
      title: 'Thanksgiving and Dedication Service for New Members',
      description:
          'Join us as we give thanks together. Bring a friend, come early '
          'for refreshments, and stay for fellowship afterwards.',
      location: 'The Lighthouse Theatre, Upper Auditorium',
      address: '262\u2013274 Camberwell Road, London SE5 0DL',
      branch: 'London',
      startTime: _at(5, 18, 30),
      endTime: _at(5, 21),
      imageUrl: 'https://cdn.test/thanksgiving.jpg',
    );

    _forEachMode('events list', (tester, dark, scale) async {
      await h.pump(
        tester,
        upcoming: AsyncData([_sundayService, longEvent, _prayerNight]),
        dark: dark,
        textScale: scale,
      );
      // One reminder on, so both toggle states are laid out.
      await tester.tap(find.text('Remind me').first);
      await h.settle(tester);
      expect(find.text('Reminder on'), findsOneWidget);
    });

    _forEachMode('events list, empty', (tester, dark, scale) async {
      await h.pump(
        tester,
        upcoming: const AsyncData([]),
        dark: dark,
        textScale: scale,
      );
      expect(find.text('No upcoming events'), findsOneWidget);
    });

    _forEachMode('event detail', (tester, dark, scale) async {
      await h.pump(
        tester,
        initial: '/events/${longEvent.id}',
        upcoming: const AsyncData([]),
        byId: {longEvent.id: longEvent},
        user: _member,
        dark: dark,
        textScale: scale,
      );
      expect(find.text('Remind me'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('All events'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
    });

    _forEachMode('event detail, unavailable', (tester, dark, scale) async {
      await h.pump(
        tester,
        initial: '/events/gone',
        upcoming: const AsyncData([]),
        dark: dark,
        textScale: scale,
      );
      expect(find.text('Try again'), findsOneWidget);
    });
  });
}
