import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kharis_app/core/services/notification_service.dart';
import 'package:kharis_app/features/calendar/data/event_repository.dart';
import 'package:kharis_app/features/onboarding/data/branch_repository.dart';
import 'package:kharis_app/shared/models/campus_config.dart';
import 'package:kharis_app/shared/providers/admin_provider.dart';
import 'package:kharis_app/shared/providers/cache_provider.dart';
import 'package:kharis_app/shared/providers/clock_provider.dart';
import 'package:kharis_app/shared/providers/event_reminders_provider.dart';
import 'package:kharis_app/shared/providers/notification_provider.dart';
import 'package:kharis_app/shared/providers/sermon_provider.dart';

import 'support/fake_cache_service.dart';
import 'support/fake_reminder_notifications.dart';

/// The app's permission prompt, answered by the test.
class _Prompt extends NotificationService {
  _Prompt({required this.answer});

  final bool answer;
  int asked = 0;

  @override
  Future<bool> requestPermission() async {
    asked++;
    return answer;
  }
}

/// Studio events by id.
class _Events implements EventRepository {
  _Events(this.byId);

  final Map<String, Event> byId;

  @override
  Future<Event?> getEventById(String id) async => byId[id];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _london = Branch(
  id: 'london',
  name: 'London',
  subtitle: '',
  address: '4-18 Harrington Gardens',
  services: [
    CampusService(
      id: 'sun',
      name: 'Sunday Service',
      day: 'Sunday',
      startTime: '10:00',
      endTime: '12:00',
    ),
  ],
);

/// `eventReminderServiceProvider` as the app builds it: the existing
/// permission flow, and events resolved the way the event screen does.
void main() {
  late FakeCacheService cache;
  late FakeReminderNotifications notifications;
  // Wednesday 11 November 2026, 09:00.
  late DateTime now;

  final prayerNight = Event(
    id: 'evt-prayer',
    title: 'Prayer Night',
    startTime: DateTime(2026, 11, 13, 19),
    location: 'Kharis Centre',
  );

  /// The Sunday service event the Events tab generates for London.
  final sundayService = Event(
    id: 'service:london:sun',
    title: 'Sunday Service',
    startTime: DateTime(2026, 11, 15, 10),
    endTime: DateTime(2026, 11, 15, 12),
    recurrenceDays: const [0],
  );

  ProviderContainer container({
    required NotificationPermission permission,
    required _Prompt prompt,
    List<bool>? answers,
    Map<String, Event> studio = const {},
    Stream<List<Branch>>? branches,
  }) {
    final c = ProviderContainer(
      overrides: [
        cacheServiceProvider.overrideWithValue(cache),
        clockProvider.overrideWithValue(() => now),
        reminderNotificationsProvider.overrideWithValue(notifications),
        notificationPermissionProvider.overrideWith((ref) async => permission),
        notificationServiceProvider.overrideWithValue(prompt),
        notificationPermissionAnsweredProvider.overrideWithValue(
          (granted) async => answers?.add(granted),
        ),
        eventRepositoryProvider.overrideWithValue(_Events(studio)),
        branchesProvider.overrideWith(
          (ref) => branches ?? Stream.value(const [_london]),
        ),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  setUp(() {
    cache = FakeCacheService();
    notifications = FakeReminderNotifications();
    now = DateTime(2026, 11, 11, 9);
  });

  group('permission', () {
    test('already granted: the reminder goes on without a prompt', () async {
      final prompt = _Prompt(answer: false);
      final c = container(
        permission: NotificationPermission.granted,
        prompt: prompt,
      );

      final outcome = await c
          .read(eventReminderServiceProvider)
          .enable(prayerNight);

      expect(outcome, ReminderOutcome.on);
      expect(prompt.asked, 0);
    });

    test(
      'not granted: the app\'s prompt is shown; allowed turns it on',
      () async {
        final prompt = _Prompt(answer: true);
        final answers = <bool>[];
        final c = container(
          permission: NotificationPermission.askable,
          prompt: prompt,
          answers: answers,
        );

        final outcome = await c
            .read(eventReminderServiceProvider)
            .enable(prayerNight);

        expect(outcome, ReminderOutcome.on);
        expect(prompt.asked, 1);
        expect(answers, [true], reason: 'the shared follow-up ran');
        expect(
          notifications.scheduled.values.single.at,
          DateTime(2026, 11, 13, 18),
        );
      },
    );

    test('refused: the reminder stays off', () async {
      final prompt = _Prompt(answer: false);
      final answers = <bool>[];
      final c = container(
        permission: NotificationPermission.askable,
        prompt: prompt,
        answers: answers,
      );

      final outcome = await c
          .read(eventReminderServiceProvider)
          .enable(prayerNight);

      expect(outcome, ReminderOutcome.permissionRefused);
      expect(answers, [false]);
      expect(c.read(remindedEventIdsProvider), isEmpty);
      expect(notifications.scheduled, isEmpty);
    });

    test('blocked in system settings: the reminder stays off', () async {
      final prompt = _Prompt(answer: false);
      final c = container(
        permission: NotificationPermission.blocked,
        prompt: prompt,
      );

      final outcome = await c
          .read(eventReminderServiceProvider)
          .enable(prayerNight);

      expect(outcome, ReminderOutcome.permissionRefused);
    });
  });

  group('looking events up at launch', () {
    test('a Studio event is read from the events list', () async {
      final c = container(
        permission: NotificationPermission.granted,
        prompt: _Prompt(answer: true),
        studio: {
          'evt-prayer': Event(
            id: 'evt-prayer',
            title: 'Prayer Night',
            startTime: DateTime(2026, 11, 13, 20),
            location: 'Kharis Centre',
          ),
        },
      );
      final reminders = c.read(eventReminderServiceProvider);
      await reminders.enable(prayerNight);

      await reminders.sync();

      expect(
        notifications.scheduled.values.single.at,
        DateTime(2026, 11, 13, 19),
        reason: 'the Studio moved it an hour later',
      );
    });

    test('a branch service is read from the branches list', () async {
      final c = container(
        permission: NotificationPermission.granted,
        prompt: _Prompt(answer: true),
      );
      final reminders = c.read(eventReminderServiceProvider);
      await reminders.enable(sundayService);

      // Opened again the Monday after: the next service is the 22nd.
      now = DateTime(2026, 11, 16, 8);
      await reminders.sync();

      final reminder = notifications.scheduled.values.single;
      expect(reminder.at, DateTime(2026, 11, 22, 9));
      expect(reminder.title, 'Sunday Service');
      expect(reminder.body, 'Starts at 10:00 · 4-18 Harrington Gardens');
    });

    test(
      'a branch service that was removed is kept until it is stale',
      () async {
        final c = container(
          permission: NotificationPermission.granted,
          prompt: _Prompt(answer: true),
          branches: Stream.value(const []),
        );
        final reminders = c.read(eventReminderServiceProvider);
        await reminders.enable(sundayService);

        now = DateTime(2026, 11, 16, 8);
        await reminders.sync();

        expect(reminders.isReminded('service:london:sun'), isTrue);
        expect(
          notifications.scheduled.values.single.at,
          DateTime(2026, 11, 15, 9),
          reason: 'not moved on: the service is no longer listed',
        );
      },
    );
  });
}
