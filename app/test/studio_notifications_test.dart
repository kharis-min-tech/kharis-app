import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kharis_app/core/services/notification_service.dart';
import 'package:kharis_app/features/calendar/data/event_repository.dart';
import 'package:kharis_app/features/home/data/news_repository.dart';
import 'package:kharis_app/features/home/data/studio_notification_repository.dart';
import 'package:kharis_app/features/home/presentation/screens/notifications_screen.dart';
import 'package:kharis_app/shared/providers/branch_provider.dart';
import 'package:kharis_app/shared/providers/notification_feed_provider.dart';
import 'package:kharis_app/shared/providers/onboarding_provider.dart';
import 'package:kharis_app/shared/providers/sermon_provider.dart';

StudioNotification _sent(
  String id,
  String title,
  DateTime sentAt, {
  String? link,
}) => StudioNotification(
  id: id,
  title: title,
  body: '$title body',
  link: link,
  audience: const NotificationAudience.all(),
  status: StudioNotificationStatus.sent,
  sentAt: sentAt,
);

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('StudioNotificationRepository', () {
    late FakeFirebaseFirestore db;
    late StudioNotificationRepository repo;

    setUp(() {
      db = FakeFirebaseFirestore();
      repo = StudioNotificationRepository(firestore: db);
    });

    test('send now: trimmed fields, scheduled, server-stamped times', () async {
      final id = await repo.schedule(
        title: '  Prayer night  ',
        body: ' Friday at 8pm. ',
        link: '/e/ev1',
        audience: const NotificationAudience.branch('North'),
        createdBy: 'uid-1',
        createdByName: 'Pastor Ade',
      );
      final data = (await db.collection('notifications').doc(id).get()).data()!;
      expect(data['title'], 'Prayer night');
      expect(data['body'], 'Friday at 8pm.');
      expect(data['link'], '/e/ev1');
      expect(data['audience'], {'type': 'branch', 'branch': 'North'});
      expect(data['status'], 'scheduled');
      expect(data['createdBy'], 'uid-1');
      expect(data['createdByName'], 'Pastor Ade');
      for (final key in ['sendAt', 'createdAt', 'updatedAt']) {
        expect(data[key], isA<Timestamp>(), reason: key);
      }
      expect(
        data.keys.toSet(),
        containsAll(<String>{'title', 'body', 'audience', 'status'}),
      );
      expect(data.containsKey('sentAt'), isFalse);
      expect(data.containsKey('result'), isFalse);
    });

    test('schedule keeps the chosen time; no link means no field', () async {
      final at = DateTime.utc(2026, 12, 24, 18);
      final id = await repo.schedule(
        title: 'Carols',
        body: 'Tonight at 6pm.',
        audience: const NotificationAudience.all(),
        createdBy: 'uid-1',
        sendAt: at,
      );
      final data = (await db.collection('notifications').doc(id).get()).data()!;
      expect((data['sendAt'] as Timestamp).toDate().toUtc(), at);
      expect(data.containsKey('link'), isFalse);
      expect(data.containsKey('createdByName'), isFalse);
    });

    test('cancel sets cancelled', () async {
      final id = await repo.schedule(
        title: 't',
        body: 'b',
        audience: const NotificationAudience.test(),
        createdBy: 'uid-1',
        sendAt: DateTime.utc(2030),
      );
      await repo.cancel(id);
      final doc = await db.collection('notifications').doc(id).get();
      expect(doc.data()!['status'], 'cancelled');
      expect(StudioNotification.fromDoc(doc)!.status.cancellable, isFalse);
    });

    test(
      'watchSent reads only sent docs for the audience, newest first',
      () async {
        Future<void> add(
          String id,
          String status,
          Map<String, Object> audience,
          int day,
        ) => db.collection('notifications').doc(id).set({
          'title': id,
          'body': 'b',
          'audience': audience,
          'status': status,
          'sentAt': Timestamp.fromDate(DateTime.utc(2026, 10, day)),
        });
        await add('old', 'sent', {'type': 'all'}, 1);
        await add('new', 'sent', {'type': 'all'}, 3);
        await add('north', 'sent', {'type': 'branch', 'branch': 'North'}, 2);
        await add('south', 'sent', {'type': 'branch', 'branch': 'South'}, 2);
        await add('test', 'sent', {'type': 'test'}, 4);
        await add('queued', 'scheduled', {'type': 'all'}, 5);

        final all = await repo
            .watchSent(const NotificationAudience.all())
            .first;
        expect(all.map((n) => n.id), ['new', 'old']);
        final north = await repo
            .watchSent(const NotificationAudience.branch('North'))
            .first;
        expect(north.map((n) => n.id), ['north']);
      },
    );
  });

  test('inbox merge: deduped, newest first', () {
    final a = _sent('a', 'A', DateTime.utc(2026, 10, 1));
    final b = _sent('b', 'B', DateTime.utc(2026, 10, 3));
    final c = _sent('c', 'C', DateTime.utc(2026, 10, 2));
    expect(
      mergeSentNotifications([
        [b, a],
        [c, a],
      ]).map((n) => n.id),
      ['b', 'c', 'a'],
    );
  });

  group('link targets', () {
    test('app paths open in the app; tab roots switch, others push', () {
      expect(
        notificationLinkTarget('/giving'),
        const NotificationTarget('/giving'),
      );
      expect(
        notificationLinkTarget('/m/abc?t=30'),
        const NotificationTarget('/m/abc?t=30', overlay: true),
      );
      expect(
        notificationLinkTarget('/reading'),
        const NotificationTarget('/reading', overlay: true),
      );
      expect(
        notificationLinkTarget('https://kharis-app-47c49.web.app/e/ev1'),
        const NotificationTarget('/e/ev1', overlay: true),
      );
      expect(notificationLinkTarget('//evil.example/x'), isNull);
      expect(notificationLinkTarget('https://kharis.org/give'), isNull);
    });

    test('other web addresses open in the browser', () {
      expect(
        externalNotificationUri('https://kharis.org/give'),
        Uri.parse('https://kharis.org/give'),
      );
      expect(externalNotificationUri('/giving'), isNull);
      expect(externalNotificationUri('javascript:alert(1)'), isNull);
    });

    test('a studio push opens its link, or the inbox without one', () {
      expect(
        notificationTargetFor({'type': 'studio', 'link': '/e/ev1'}),
        const NotificationTarget('/e/ev1', overlay: true),
      );
      expect(
        notificationTargetFor({'type': 'studio', 'notificationId': 'n1'}),
        const NotificationTarget('/notifications', overlay: true),
      );
    });
  });

  testWidgets(
    'Notifications screen merges sent notifications with the feed, newest '
    'first, hides dismissed ones and opens the link',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'notifications_dismissed_ids': ['studio:gone'],
      });
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      final news = NewsItem(
        id: 'n1',
        title: 'Harvest service',
        body: 'Bring a gift',
        type: 'General',
        publishedAt: now.subtract(const Duration(hours: 2)),
      );
      final router = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, _) => const NotificationsScreen()),
          GoRoute(
            path: '/giving',
            builder: (_, _) => const Scaffold(body: Text('Giving screen')),
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            currentBranchProvider.overrideWith((ref) => Stream.value('North')),
            newsProvider.overrideWith((ref, branch) async => [news]),
            upcomingEventsProvider.overrideWith(
              (ref, branch) => Stream.value(const <Event>[]),
            ),
            inboxNotificationsProvider.overrideWithValue(
              AsyncData([
                _sent(
                  'fresh',
                  'Give online this week',
                  now.subtract(const Duration(hours: 1)),
                  link: '/giving',
                ),
                _sent(
                  'older',
                  'Choir rehearsal moved',
                  now.subtract(const Duration(hours: 3)),
                ),
                _sent('gone', 'Dismissed one', now),
              ]),
            ),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      final fresh = tester.getTopLeft(find.text('Give online this week')).dy;
      final harvest = tester.getTopLeft(find.text('Harvest service')).dy;
      final older = tester.getTopLeft(find.text('Choir rehearsal moved')).dy;
      expect(fresh, lessThan(harvest));
      expect(harvest, lessThan(older));
      expect(find.text('Dismissed one'), findsNothing);

      await tester.tap(find.text('Give online this week'));
      await tester.pumpAndSettle();
      expect(find.text('Giving screen'), findsOneWidget);
    },
  );
}
