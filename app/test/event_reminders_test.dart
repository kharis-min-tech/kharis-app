import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:kharis_app/core/services/app_router.dart';
import 'package:kharis_app/features/calendar/data/event_reminder_service.dart';
import 'package:kharis_app/features/calendar/data/event_repository.dart';
import 'package:kharis_app/shared/providers/cache_provider.dart';
import 'package:kharis_app/shared/providers/clock_provider.dart';
import 'package:kharis_app/shared/providers/event_reminders_provider.dart';

import 'support/fake_cache_service.dart';
import 'support/fake_reminder_notifications.dart';

void main() {
  late FakeCacheService cache;
  late FakeReminderNotifications notifications;

  // Wednesday 11 November 2026, 09:00.
  late DateTime now;

  /// What the app can currently find, by event id.
  late Map<String, Event> known;
  late bool lookupFails;
  late bool permissionGranted;
  late int permissionAsks;

  EventReminderService service() => EventReminderService(
    cache,
    notifications,
    clock: () => now,
    resolveEvent: (id) async {
      if (lookupFails) throw StateError('offline');
      return known[id];
    },
    ensurePermission: () async {
      permissionAsks++;
      return permissionGranted;
    },
  );

  /// A one-off event on Saturday 14 November at 18:30.
  Event conference({DateTime? start, String? location = 'Kharis Centre'}) =>
      Event(
        id: 'evt-conf',
        title: 'Worship Night',
        startTime: start ?? DateTime(2026, 11, 14, 18, 30),
        endTime: (start ?? DateTime(2026, 11, 14, 18, 30)).add(
          const Duration(hours: 2),
        ),
        location: location,
        address: '1 Grace Road, London',
      );

  /// The Sunday service, as `branchServiceEvents` dates it at [now]: its
  /// next occurrence that has not ended.
  Event sundayService() {
    var start = DateTime(now.year, now.month, now.day, 10);
    while (start.weekday != DateTime.sunday ||
        start.add(const Duration(hours: 2)).isBefore(now)) {
      start = DateTime(start.year, start.month, start.day + 1, 10);
    }
    return Event(
      id: 'service:london:sun',
      title: 'Sunday Service',
      startTime: start,
      endTime: start.add(const Duration(hours: 2)),
      location: 'Millennium Gloucester Hotel',
      recurrenceDays: const [0],
    );
  }

  ReminderNotification only() => notifications.scheduled.values.single;

  setUp(() {
    cache = FakeCacheService();
    notifications = FakeReminderNotifications();
    now = DateTime(2026, 11, 11, 9);
    known = {};
    lookupFails = false;
    permissionGranted = true;
    permissionAsks = 0;
  });

  group('turning a reminder on', () {
    test('schedules a notification one hour before the start', () async {
      final reminders = service();

      expect(await reminders.enable(conference()), ReminderOutcome.on);

      final reminder = only();
      expect(reminder.at, DateTime(2026, 11, 14, 17, 30));
      expect(reminder.title, 'Worship Night');
      expect(reminder.body, 'Starts at 18:30 · Kharis Centre');
      expect(reminder.eventId, 'evt-conf');
      expect(reminders.isReminded('evt-conf'), isTrue);
      expect(reminders.remindedIds, {'evt-conf'});
    });

    test('with no venue name the body gives the address', () async {
      await service().enable(conference(location: null));

      expect(only().body, 'Starts at 18:30 · 1 Grace Road, London');
    });

    test('with no place at all the body gives the time', () async {
      await service().enable(
        Event(
          id: 'evt-online',
          title: 'Prayer call',
          startTime: DateTime(2026, 11, 12, 6),
        ),
      );

      expect(only().body, 'Starts at 06:00');
    });

    test('asks for permission, and stays off when it is refused', () async {
      permissionGranted = false;
      final reminders = service();

      expect(
        await reminders.enable(conference()),
        ReminderOutcome.permissionRefused,
      );

      expect(permissionAsks, 1);
      expect(reminders.isReminded('evt-conf'), isFalse);
      expect(notifications.scheduled, isEmpty);
      expect(cache.preferences[EventReminderService.remindersKey], isNull);
    });

    test(
      'a one-off event starting within the hour cannot be reminded',
      () async {
        final reminders = service();
        final soon = conference(start: DateTime(2026, 11, 11, 9, 45));

        expect(reminders.canRemind(soon), isFalse);
        expect(await reminders.enable(soon), ReminderOutcome.startsTooSoon);

        expect(permissionAsks, 0, reason: 'nothing to ask permission for');
        expect(reminders.isReminded('evt-conf'), isFalse);
      },
    );

    test('stays off when the phone cannot schedule it', () async {
      notifications.failScheduling = true;
      final reminders = service();

      expect(await reminders.enable(conference()), ReminderOutcome.failed);
      expect(reminders.isReminded('evt-conf'), isFalse);
    });

    test(
      'each event gets its own notification id, clear of the player\'s',
      () async {
        final reminders = service();
        await reminders.enable(conference());
        await reminders.enable(sundayService());

        final ids = notifications.scheduled.keys.toList();
        expect(ids.toSet(), hasLength(2));
        for (final id in ids) {
          expect(id, inInclusiveRange(0x10000000, 0x1FFFFFFF));
        }
      },
    );

    test('an event keeps its notification id across launches', () async {
      await service().enable(conference());
      final first = only().id;
      await service().disable('evt-conf');

      await service().enable(conference());

      expect(only().id, first);
    });
  });

  group('turning a reminder off', () {
    test('cancels the notification and forgets the event', () async {
      final reminders = service();
      await reminders.enable(conference());
      final id = only().id;

      expect(await reminders.disable('evt-conf'), ReminderOutcome.off);

      expect(notifications.cancelled, [id]);
      expect(notifications.scheduled, isEmpty);
      expect(reminders.isReminded('evt-conf'), isFalse);
    });

    test('toggle flips between on and off', () async {
      final reminders = service();

      expect(await reminders.toggle(conference()), ReminderOutcome.on);
      expect(await reminders.toggle(conference()), ReminderOutcome.off);
      expect(reminders.remindedIds, isEmpty);
    });

    test('turning off an event that is not reminded does nothing', () async {
      expect(await service().disable('nope'), ReminderOutcome.off);
      expect(notifications.cancelled, isEmpty);
    });

    test('changes fires on every switch', () async {
      final reminders = service();
      var fired = 0;
      reminders.changes.addListener(() => fired++);

      await reminders.enable(conference());
      await reminders.disable('evt-conf');

      expect(fired, 2);
    });
  });

  group('persistence', () {
    test('reminded events are remembered after a restart', () async {
      await service().enable(conference());
      await service().enable(sundayService());

      expect(service().remindedIds, {'evt-conf', 'service:london:sun'});
    });

    test('unreadable saved data reads as no reminders', () {
      cache.preferences[EventReminderService.remindersKey] = '{not json';

      expect(service().remindedIds, isEmpty);
    });
  });

  group('weekly events', () {
    test('the next occurrence is scheduled', () async {
      await service().enable(sundayService());

      expect(only().at, DateTime(2026, 11, 15, 9));
      expect(only().body, 'Starts at 10:00 · Millennium Gloucester Hotel');
    });

    test(
      'turned on within the hour before a service: reminded next week',
      () async {
        now = DateTime(2026, 11, 15, 9, 30);

        expect(await service().enable(sundayService()), ReminderOutcome.on);
        expect(only().at, DateTime(2026, 11, 22, 9));
      },
    );

    test('an event on two weekdays is reminded about the nearer one', () {
      final midweek = Event(
        id: 'evt-bible-study',
        title: 'Bible Study',
        // Dated at its next occurrence: Wednesday the 11th at 19:00.
        startTime: DateTime(2026, 11, 11, 19),
        recurrenceDays: const [0, 3],
      );

      expect(
        EventReminderService.nextReminder(midweek, DateTime(2026, 11, 11, 9)),
        DateTime(2026, 11, 11, 19),
      );
      expect(
        EventReminderService.nextReminder(
          midweek,
          DateTime(2026, 11, 11, 18, 30),
        ),
        DateTime(2026, 11, 15, 19),
        reason: 'tonight is under an hour away, so Sunday',
      );
    });

    test('the reminder keeps its wall-clock time across a clock change', () {
      // UK clocks go back on Sunday 25 October 2026.
      final service = Event(
        id: 'service:london:sun',
        title: 'Sunday Service',
        startTime: DateTime(2026, 10, 18, 10),
        recurrenceDays: const [0],
      );

      final next = EventReminderService.nextReminder(
        service,
        DateTime(2026, 10, 18, 9, 30),
      )!;

      expect((next.day, next.hour, next.minute), (25, 10, 0));
    });

    test(
      'at launch a passed reminder moves on to the next occurrence',
      () async {
        await service().enable(sundayService());
        final id = only().id;

        // The app is next opened on Monday; the service is now dated at the
        // following Sunday.
        now = DateTime(2026, 11, 16, 8);
        known['service:london:sun'] = sundayService();
        final reminders = service();
        await reminders.sync();

        expect(only().id, id, reason: 'the same notification, re-scheduled');
        expect(only().at, DateTime(2026, 11, 22, 9));
        expect(reminders.isReminded('service:london:sun'), isTrue);
      },
    );

    test('at launch a changed time and venue are picked up', () async {
      await service().enable(sundayService());

      known['service:london:sun'] = Event(
        id: 'service:london:sun',
        title: 'Sunday Service',
        startTime: DateTime(2026, 11, 15, 11, 30),
        location: 'Cedar Mountain Chapel',
        recurrenceDays: const [0],
      );
      await service().sync();

      expect(only().at, DateTime(2026, 11, 15, 10, 30));
      expect(only().body, 'Starts at 11:30 · Cedar Mountain Chapel');
    });

    test('offline at launch: the reminder is kept as it is', () async {
      await service().enable(sundayService());
      final before = only();

      lookupFails = true;
      now = DateTime(2026, 11, 13, 8);
      final reminders = service();
      await reminders.sync();

      expect(reminders.isReminded('service:london:sun'), isTrue);
      expect(only().at, before.at);
      expect(notifications.cancelled, isEmpty);
    });

    test('a weekly event not found for 60 days is dropped', () async {
      await service().enable(sundayService());
      final id = only().id;

      now = DateTime(2026, 12, 20, 8);
      final soon = service();
      await soon.sync();
      expect(soon.isReminded('service:london:sun'), isTrue);

      now = DateTime(2027, 1, 12, 8);
      final later = service();
      await later.sync();

      expect(later.isReminded('service:london:sun'), isFalse);
      expect(notifications.cancelled, [id]);
    });
  });

  group('cleaning up at launch', () {
    test('a one-off event that has started is removed', () async {
      await service().enable(conference());
      final id = only().id;

      now = DateTime(2026, 11, 14, 19);
      known['evt-conf'] = conference();
      final reminders = service();
      var fired = 0;
      reminders.changes.addListener(() => fired++);
      await reminders.sync();

      expect(reminders.remindedIds, isEmpty);
      expect(notifications.cancelled, [id]);
      expect(fired, 1);
    });

    test(
      'a past one-off event that can no longer be found is removed',
      () async {
        await service().enable(conference());

        now = DateTime(2026, 11, 20, 9);
        final reminders = service();
        await reminders.sync();

        expect(reminders.remindedIds, isEmpty);
      },
    );

    test('an upcoming one-off event that is not found is kept', () async {
      await service().enable(conference());

      now = DateTime(2026, 11, 12, 9);
      final reminders = service();
      await reminders.sync();

      expect(reminders.isReminded('evt-conf'), isTrue);
      expect(only().at, DateTime(2026, 11, 14, 17, 30));
    });

    test('a one-off event moved to a new time is re-scheduled', () async {
      await service().enable(conference());

      known['evt-conf'] = conference(start: DateTime(2026, 11, 21, 19));
      await service().sync();

      expect(only().at, DateTime(2026, 11, 21, 18));
    });

    test('an event in its last hour before starting is left alone', () async {
      await service().enable(conference());

      now = DateTime(2026, 11, 14, 18);
      known['evt-conf'] = conference();
      final reminders = service();
      await reminders.sync();

      expect(reminders.isReminded('evt-conf'), isTrue);
      expect(notifications.cancelled, isEmpty);
    });

    test('a reminder turned off during the launch check stays off', () async {
      await service().enable(sundayService());
      final reminders = EventReminderService(
        cache,
        notifications,
        clock: () => now,
        ensurePermission: () async => true,
        resolveEvent: (id) async {
          // The member switches it off while the lookup is in flight.
          await reminders_.disable(id);
          return sundayService();
        },
      );
      reminders_ = reminders;

      await reminders.sync();

      expect(reminders.isReminded('service:london:sun'), isFalse);
      expect(notifications.scheduled, isEmpty);
    });

    test('with no reminders nothing is looked up', () async {
      lookupFails = true;

      await expectLater(service().sync(), completes);
      expect(notifications.scheduled, isEmpty);
    });
  });

  group('providers', () {
    late GoRouter router;

    ProviderContainer container(EventReminderService reminders) {
      final c = ProviderContainer(
        overrides: [
          cacheServiceProvider.overrideWithValue(cache),
          clockProvider.overrideWithValue(() => now),
          appRouterProvider.overrideWithValue(router),
          reminderNotificationsProvider.overrideWithValue(notifications),
          eventReminderServiceProvider.overrideWithValue(reminders),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    Future<void> pumpApp(WidgetTester tester, ProviderContainer c) =>
        tester.pumpWidget(
          UncontrolledProviderScope(
            container: c,
            child: MaterialApp.router(routerConfig: router),
          ),
        );

    setUp(() {
      router = GoRouter(
        initialLocation: '/home',
        routes: [
          GoRoute(path: '/home', builder: (_, _) => const Text('Home')),
          GoRoute(
            path: '/events/:id',
            builder: (_, state) => Text('Event ${state.pathParameters['id']}'),
          ),
        ],
      );
      addTearDown(router.dispose);
    });

    testWidgets('the toggle sets the plugin up, then switches the reminder', (
      tester,
    ) async {
      final c = container(service());
      await pumpApp(tester, c);
      final reminded = c.listen(isEventRemindedProvider('evt-conf'), (_, _) {});
      addTearDown(reminded.close);
      expect(reminded.read(), isFalse);

      final toggle = c.read(toggleEventReminderProvider);
      expect(await toggle(conference()), ReminderOutcome.on);

      expect(notifications.initCalls, 1);
      expect(reminded.read(), isTrue);
      expect(c.read(remindedEventIdsProvider), {'evt-conf'});

      expect(await toggle(conference()), ReminderOutcome.off);

      expect(reminded.read(), isFalse);
      expect(notifications.initCalls, 1, reason: 'set up once per launch');
    });

    testWidgets('refused permission leaves the toggle off', (tester) async {
      permissionGranted = false;
      final c = container(service());
      await pumpApp(tester, c);

      final outcome = await c.read(toggleEventReminderProvider)(conference());

      expect(outcome, ReminderOutcome.permissionRefused);
      expect(c.read(isEventRemindedProvider('evt-conf')), isFalse);
    });

    testWidgets('tapping a reminder opens the event over Home', (tester) async {
      final c = container(service());
      await pumpApp(tester, c);
      await c.read(eventReminderStartupProvider.future);

      notifications.tap('service:london:sun');
      await tester.pumpAndSettle();

      expect(find.text('Event service:london:sun'), findsOneWidget);
      expect(router.canPop(), isTrue, reason: 'Back returns to Home');
    });

    testWidgets('a reminder tap that launched the app opens its event', (
      tester,
    ) async {
      notifications.launchedBy = 'evt-conf';
      final c = container(service());
      await pumpApp(tester, c);

      await c.read(eventReminderStartupProvider.future);
      await tester.pumpAndSettle();

      expect(find.text('Event evt-conf'), findsOneWidget);
      expect(router.canPop(), isTrue, reason: 'Back returns to Home');
    });

    testWidgets('startup re-schedules weekly reminders', (tester) async {
      await service().enable(sundayService());
      now = DateTime(2026, 11, 16, 8);
      known['service:london:sun'] = sundayService();
      final c = container(service());
      await pumpApp(tester, c);

      await c.read(eventReminderStartupProvider.future);

      expect(only().at, DateTime(2026, 11, 22, 9));
    });

    testWidgets('a host without the plugin: the toggle reports a failure', (
      tester,
    ) async {
      notifications
        ..failInit = true
        ..failScheduling = true;
      final c = container(service());
      await pumpApp(tester, c);

      final outcome = await c.read(toggleEventReminderProvider)(conference());

      expect(outcome, ReminderOutcome.failed);
      expect(c.read(isEventRemindedProvider('evt-conf')), isFalse);
    });
  });
}

/// The service a lookup reaches back into (see "turned off during the
/// launch check").
late EventReminderService reminders_;
