import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:dio/dio.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kharis_app/features/admin/data/content_config_repository.dart';
import 'package:kharis_app/features/admin/data/london_time.dart';
import 'package:kharis_app/features/calendar/data/event_repository.dart';
import 'package:kharis_app/features/home/data/daily_content_repository.dart';
import 'package:kharis_app/features/home/data/news_repository.dart';

/// The getEvents API is unreachable, so the Firestore path is what is tested.
class _OfflineAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    throw DioException.connectionError(
      requestOptions: options,
      reason: 'offline',
    );
  }

  @override
  void close({bool force = false}) {}
}

// Plain `test`s: Firestore snapshot streams do not deliver under flutter_test's
// FakeAsync zone (see announcements_home_pipeline_test.dart).
void main() {
  group('EventRepository', () {
    late FakeFirebaseFirestore firestore;
    late EventRepository repo;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      repo = EventRepository(
        firestore: firestore,
        dio: Dio()..httpClientAdapter = _OfflineAdapter(),
      );
    });

    test('getEventById maps venue, address and blank branch', () async {
      await firestore.collection('events').doc('e1').set({
        'title': 'Prayer Night',
        'location': 'Kensington Town Hall',
        'address': 'Hornton St, London W8 7NX',
        'branch': '',
        'startTime': Timestamp.fromDate(DateTime.utc(2026, 10, 9, 18)),
      });

      final event = await repo.getEventById('e1');

      expect(event?.title, 'Prayer Night');
      expect(event?.location, 'Kensington Town Hall');
      expect(event?.address, 'Hornton St, London W8 7NX');
      expect(event?.branch, isNull, reason: 'blank branch is all-campus');
      expect(await repo.getEventById('missing'), isNull);
    });

    test('partial updateEvent keeps branch, imageUrl and isFeatured', () async {
      await firestore.collection('events').doc('e1').set({
        'title': 'Prayer Night',
        'branch': null,
        'imageUrl': 'https://kharis.org/banner.jpg',
        'isFeatured': true,
        'startTime': Timestamp.fromDate(DateTime.utc(2026, 10, 9, 18)),
        'endTime': Timestamp.fromDate(DateTime.utc(2026, 10, 9, 20)),
      });

      await repo.updateEvent(
        'e1',
        title: 'Prayer & Worship Night',
        location: 'Main Hall',
        address: '1 High St',
      );

      final data = (await firestore.collection('events').doc('e1').get())
          .data()!;
      expect(data['title'], 'Prayer & Worship Night');
      expect(data['location'], 'Main Hall');
      expect(data['address'], '1 High St');
      expect(data.containsKey('branch'), isTrue);
      expect(data['branch'], isNull, reason: 'still all-campus');
      expect(data['imageUrl'], 'https://kharis.org/banner.jpg');
      expect(data['isFeatured'], isTrue);
    });

    test("updateEvent clears an optional field only when given ''", () async {
      await firestore.collection('events').doc('e1').set({
        'title': 'Night',
        'branch': 'Chatham',
        'address': 'Old',
        'startTime': Timestamp.fromDate(DateTime.utc(2026, 10, 9, 18)),
      });

      await repo.updateEvent('e1', branch: '', address: '');

      final data = (await firestore.collection('events').doc('e1').get())
          .data()!;
      expect(data['branch'], isNull);
      expect(data['address'], isNull);
      expect(data['title'], 'Night');
    });

    test(
      'upcoming stream scopes keyless all-campus events into a branch',
      () async {
        final soon = Timestamp.fromDate(
          DateTime.now().add(const Duration(days: 3)),
        );
        final events = firestore.collection('events');
        await events.doc('own').set({
          'title': 'Own',
          'branch': 'Chatham',
          'startTime': soon,
        });
        await events.doc('keyless').set({
          'title': 'Keyless',
          'startTime': soon,
        });
        await events.doc('null').set({
          'title': 'Null',
          'branch': null,
          'startTime': soon,
        });
        await events.doc('other').set({
          'title': 'Other',
          'branch': 'Reading',
          'startTime': soon,
        });

        final ids = (await repo.watchUpcomingEvents(branch: 'Chatham').first)
            .map((e) => e.id)
            .toSet();

        expect(ids, {'own', 'keyless', 'null'});
      },
    );
  });

  group('NewsRepository', () {
    test(
      'scheduled announcements stay hidden from members, not from admins',
      () async {
        final firestore = FakeFirebaseFirestore();
        final news = firestore.collection('news');
        await news.doc('live').set({
          'title': 'Live',
          'publishedAt': Timestamp.fromDate(
            DateTime.now().subtract(const Duration(hours: 1)),
          ),
        });
        await news.doc('scheduled').set({
          'title': 'Scheduled',
          'publishedAt': Timestamp.fromDate(
            DateTime.now().add(const Duration(days: 1)),
          ),
        });
        final repo = NewsRepository(firestore: firestore);

        final member = await repo.watchNews().first;
        final admin = await repo.watchNews(includeExpired: true).first;

        expect(member.map((n) => n.id), ['live']);
        expect(admin.map((n) => n.id), containsAll(['live', 'scheduled']));
        expect(
          admin.firstWhere((n) => n.id == 'scheduled').isScheduled,
          isTrue,
        );
      },
    );

    test('addNews writes schedule, expiry, event link and CTA', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = NewsRepository(firestore: firestore);
      final publishAt = DateTime.utc(2026, 10, 10, 8);
      final expiresAt = londonEndOfDay(DateTime(2026, 10, 12));

      await repo.addNews(
        title: 'Harvest',
        type: 'Announcement',
        branch: '',
        publishAt: publishAt,
        expiresAt: expiresAt,
        eventId: 'web_21670',
        linkUrl: 'https://kharis.org/harvest',
      );

      final data = (await firestore.collection('news').get()).docs.single
          .data();
      expect((data['publishedAt'] as Timestamp).toDate().toUtc(), publishAt);
      expect(
        (data['expiresAt'] as Timestamp).toDate().toUtc(),
        DateTime.utc(2026, 10, 12, 22, 59, 59, 999),
      );
      expect(data['branch'], isNull);
      expect(data['eventId'], 'web_21670');
      expect(data['linkUrl'], 'https://kharis.org/harvest');
      expect(data['ctaLabel'], 'Learn more');
    });
  });

  group('ContentConfigRepository', () {
    test('featured mode defaults to auto and round-trips pinned', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = ContentConfigRepository(firestore: firestore);

      expect(await repo.watchFeaturedMode().first, FeaturedMode.auto);
      await repo.setFeaturedMode(FeaturedMode.pinned);
      expect(await repo.watchFeaturedMode().first, FeaturedMode.pinned);
      final doc = await firestore.collection('config').doc('featured').get();
      expect(doc.data()?['mode'], 'pinned');
    });

    test(
      'MOTD schedule writes by local date, lists upcoming, clears',
      () async {
        final firestore = FakeFirebaseFirestore();
        final repo = ContentConfigRepository(firestore: firestore);

        await repo.scheduleMotd(
          date: DateTime(2026, 10, 3),
          sermonId: '101897',
          title: 'Christ',
        );
        await repo.scheduleMotd(
          date: DateTime(2026, 10, 5),
          sermonId: 'yt_abc',
          title: 'Hope',
        );
        await repo.scheduleMotd(
          date: DateTime(2026, 9, 30),
          sermonId: '1',
          title: 'Past',
        );

        final upcoming = await repo
            .watchSchedule(from: DateTime(2026, 10, 3))
            .first;
        expect(upcoming.map((e) => e.dateKey), ['2026-10-03', '2026-10-05']);
        expect(upcoming.first.sermonId, '101897');

        await repo.clearMotd(DateTime(2026, 10, 3));
        final after = await repo
            .watchSchedule(from: DateTime(2026, 10, 3))
            .first;
        expect(after.map((e) => e.dateKey), ['2026-10-05']);
      },
    );

    test(
      'legacy config/messageOfTheDay migrates into an empty today and is removed',
      () async {
        final firestore = FakeFirebaseFirestore();
        final repo = ContentConfigRepository(firestore: firestore);
        await firestore.collection('config').doc('messageOfTheDay').set({
          'sermonId': 'yt_old',
          'title': 'Old pick',
        });

        expect(
          await repo.migrateLegacyMotd(today: DateTime(2026, 10, 3)),
          isTrue,
        );

        final slot = await firestore
            .collection('motdSchedule')
            .doc('2026-10-03')
            .get();
        expect(slot.data()?['sermonId'], 'yt_old');
        expect(
          (await firestore.collection('config').doc('messageOfTheDay').get())
              .exists,
          isFalse,
        );
        expect(
          await repo.migrateLegacyMotd(today: DateTime(2026, 10, 3)),
          isFalse,
        );
      },
    );

    test(
      'migration never overwrites a day that is already scheduled',
      () async {
        final firestore = FakeFirebaseFirestore();
        final repo = ContentConfigRepository(firestore: firestore);
        await repo.scheduleMotd(
          date: DateTime(2026, 10, 3),
          sermonId: 'new',
          title: 'New',
        );
        await firestore.collection('config').doc('messageOfTheDay').set({
          'sermonId': 'old',
        });

        await repo.migrateLegacyMotd(today: DateTime(2026, 10, 3));

        final slot = await firestore
            .collection('motdSchedule')
            .doc('2026-10-03')
            .get();
        expect(slot.data()?['sermonId'], 'new');
      },
    );
  });

  group('London time', () {
    test('end of day is 23:59:59.999 London in BST and GMT', () {
      expect(
        londonEndOfDay(DateTime(2026, 7, 1)),
        DateTime.utc(2026, 7, 1, 22, 59, 59, 999),
      );
      expect(
        londonEndOfDay(DateTime(2026, 12, 1)),
        DateTime.utc(2026, 12, 1, 23, 59, 59, 999),
      );
      // 25 Oct 2026: clocks go back at 01:00 UTC, so the evening is GMT.
      expect(
        londonEndOfDay(DateTime(2026, 10, 25)),
        DateTime.utc(2026, 10, 25, 23, 59, 59, 999),
      );
      expect(
        londonWallTime(DateTime(2026, 3, 29), 9),
        DateTime.utc(2026, 3, 29, 8),
      );
      expect(
        toLondonWallClock(DateTime.utc(2026, 7, 4, 23, 30)),
        DateTime.utc(2026, 7, 5, 0, 30),
      );
    });
  });

  group('DailyContentRepository', () {
    test(
      'a plan day past the book is bounded and carries its plan day',
      () async {
        final firestore = FakeFirebaseFirestore();
        final start = DateTime.now().subtract(const Duration(days: 15));
        await firestore.collection('readingPlans').doc('p').set({
          'title': '2 Corinthians',
          'book': '2 Corinthians',
          'startDate':
              '${start.year.toString().padLeft(4, '0')}-'
              '${start.month.toString().padLeft(2, '0')}-'
              '${start.day.toString().padLeft(2, '0')}',
          'days': 20,
          'mode': 'chapter',
          'startChapter': 1,
        });
        final repo = DailyContentRepository(firestore: firestore);
        final now = DateTime.now();
        final key =
            '${now.year.toString().padLeft(4, '0')}-'
            '${now.month.toString().padLeft(2, '0')}-'
            '${now.day.toString().padLeft(2, '0')}';

        final resolved = await repo.resolveForDate(key);

        expect(resolved.content.reading.reference, '2 Corinthians 13');
        expect(resolved.content.planDay, 16);
        expect(resolved.content.planDays, 20);
      },
    );
  });
}
