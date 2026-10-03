import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kharis_app/shared/models/sermon.dart';
import 'package:kharis_app/shared/providers/branch_provider.dart';
import 'package:kharis_app/shared/providers/sermon_provider.dart';

import 'support/fake_sermon_repository.dart';

/// Contracts 1 (featured) and 2 (Message of the Day), read side.
///
/// Firestore is a [FakeFirebaseFirestore] holding the Studio's documents;
/// the API archive and the YouTube feed are scripted.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final today = DateTime(2026, 10, 3);

  /// YouTube uploads, deliberately out of order.
  List<Sermon> feed() => [
    for (var i = 0; i < 7; i++)
      testSermon(
        'vid$i-xxxxx',
        title: 'Upload $i',
        audioUrl: '',
        videoId: 'vid$i-xxxxx',
        publishedAt: DateTime(2026, 9, 20 - i * 2),
        source: 'youtube',
      ),
  ].reversed.toList();

  /// API archive: audio twins for uploads 0 and 2, plus older audio.
  List<Sermon> archive() => [
    testSermon(
      '101',
      title: 'Twin of 0',
      videoId: 'vid0-xxxxx',
      speaker: 'Pastor Twin',
      publishedAt: DateTime(2026, 9, 20),
    ),
    testSermon(
      '102',
      title: 'Twin of 2',
      videoId: 'vid2-xxxxx',
      publishedAt: DateTime(2026, 9, 16),
    ),
    for (var i = 0; i < 10; i++)
      testSermon('2$i', publishedAt: DateTime(2026, 8, 1 + i)),
    testSermon('old', publishedAt: DateTime(2024, 1, 1)),
  ];

  Future<ProviderContainer> settled({
    required FakeFirebaseFirestore db,
    List<Sermon>? library,
    List<Sermon>? videos,
    DateTime? date,
  }) async {
    final container = ProviderContainer(
      overrides: [
        firestoreProvider.overrideWithValue(db),
        sermonRepositoryProvider.overrideWithValue(
          FakePagedSermonRepository([library ?? archive()]),
        ),
        sermonArchiveAutoHydrateProvider.overrideWithValue(false),
        cmsSermonsProvider.overrideWith(
          (ref) => Stream.value(const <Sermon>[]),
        ),
        videosProvider.overrideWith((ref) async => videos ?? feed()),
        todayProvider.overrideWithValue(date ?? today),
      ],
    );
    addTearDown(container.dispose);
    container.listen(featuredSermonsProvider, (_, _) {});
    container.listen(motdSermonProvider, (_, _) {});
    container.listen(sermonsProvider, (_, _) {});
    await container.read(sermonLibraryProvider.notifier).firstLoad;
    await container.read(videosProvider.future);
    for (var i = 0; i < 50; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    return container;
  }

  Future<void> star(
    FakeFirebaseFirestore db,
    String id,
    DateTime when, {
    String? videoId,
    String source = 'youtube',
  }) {
    return db.collection('sermons').doc(id).set({
      'title': 'Doc $id',
      'speaker': 'David Antwi',
      'audioUrl': '',
      'videoId': videoId,
      'source': source,
      'publishedAt': Timestamp.fromDate(when),
      'isFeatured': true,
    });
  }

  group('featured (contract 1)', () {
    test(
      'auto by default: newest 5 uploads, mapped to their audio twins',
      () async {
        final c = await settled(db: FakeFirebaseFirestore());
        final featured = c.read(featuredSermonsProvider);
        expect(featured.map((s) => s.id), [
          '101',
          'vid1-xxxxx',
          '102',
          'vid3-xxxxx',
          'vid4-xxxxx',
        ]);
        final twin = featured.first;
        expect(twin.hasAudio, isTrue, reason: 'Audio must be available');
        expect(twin.speaker, 'Pastor Twin', reason: 'speaker from the twin');
        expect(twin.videoId, 'vid0-xxxxx');
      },
    );

    test(
      'pinned: starred docs newest first, capped at 5, twins applied',
      () async {
        final db = FakeFirebaseFirestore();
        await db.collection('config').doc('featured').set({'mode': 'pinned'});
        for (var i = 0; i < 6; i++) {
          await star(db, 'doc$i', DateTime(2026, 5, 1 + i));
        }
        await star(
          db,
          'yt_vid2-xxxxx',
          DateTime(2026, 9, 16),
          videoId: 'vid2-xxxxx',
        );
        await db.collection('sermons').doc('plain').set({
          'title': 'Not starred',
          'publishedAt': Timestamp.fromDate(DateTime(2026, 9, 30)),
          'isFeatured': false,
        });

        final c = await settled(db: db);
        final featured = c.read(featuredSermonsProvider);
        expect(
          featured.map((s) => s.id),
          ['102', 'doc5', 'doc4', 'doc3', 'doc2'],
          reason: 'yt_ mirror becomes its twin; unstarred never shows',
        );
      },
    );

    test('pinned with nothing starred falls back to auto', () async {
      final db = FakeFirebaseFirestore();
      await db.collection('config').doc('featured').set({'mode': 'pinned'});
      final c = await settled(db: db);
      expect(c.read(featuredSermonsProvider).first.id, '101');
      expect(c.read(featuredSermonsProvider), hasLength(5));
    });

    test('auto ignores starred docs', () async {
      final db = FakeFirebaseFirestore();
      await db.collection('config').doc('featured').set({'mode': 'auto'});
      await star(db, 'doc0', DateTime(2026, 9, 1));
      final c = await settled(db: db);
      expect(
        c.read(featuredSermonsProvider).map((s) => s.id),
        isNot(contains('doc0')),
      );
    });
  });

  group('Message of the Day (contract 2)', () {
    test("today's scheduled sermon wins", () async {
      final db = FakeFirebaseFirestore();
      await db.collection('motdSchedule').doc('2026-10-03').set({
        'sermonId': 'old',
        'title': 'Message old',
      });
      final c = await settled(db: db);
      expect(c.read(motdSermonProvider)?.id, 'old');
    });

    test('a scheduled yt_ mirror resolves to its audio twin', () async {
      final db = FakeFirebaseFirestore();
      await db.collection('motdSchedule').doc('2026-10-03').set({
        'sermonId': 'yt_vid0-xxxxx',
      });
      final c = await settled(db: db);
      final motd = c.read(motdSermonProvider);
      expect(motd?.id, '101');
      expect(motd?.hasAudio, isTrue);
    });

    test('no schedule: deterministic pick from the last 90 days', () async {
      final a = await settled(db: FakeFirebaseFirestore());
      final b = await settled(
        db: FakeFirebaseFirestore(),
        library: archive().reversed.toList(),
      );
      final pick = a.read(motdSermonProvider);
      expect(pick, isNotNull);
      expect(
        pick!.id,
        b.read(motdSermonProvider)?.id,
        reason: 'same for everyone on a date, whatever the load order',
      );
      expect(today.difference(pick.publishedAt!).inDays, lessThanOrEqualTo(90));
      expect(pick.hasAudio, isTrue);
      expect(pick.id, isNot('old'));
    });

    test('a schedule for another day or a dangling id is ignored', () async {
      final db = FakeFirebaseFirestore();
      await db.collection('motdSchedule').doc('2026-10-02').set({
        'sermonId': 'old',
      });
      final c = await settled(db: db);
      expect(c.read(motdSermonProvider)?.id, isNot('old'));

      final db2 = FakeFirebaseFirestore();
      await db2.collection('motdSchedule').doc('2026-10-03').set({
        'sermonId': 'gone',
      });
      final c2 = await settled(db: db2);
      expect(c2.read(motdSermonProvider), isNotNull);
      expect(c2.read(motdSermonProvider)!.id, isNot('gone'));
    });

    test('nothing in 90 days: the newest audio sermon', () async {
      final c = await settled(
        db: FakeFirebaseFirestore(),
        library: [
          testSermon('a', publishedAt: DateTime(2025, 1, 1)),
          testSermon('b', publishedAt: DateTime(2025, 3, 1)),
          testSermon(
            'v',
            audioUrl: '',
            videoId: 'v0000000000',
            publishedAt: DateTime(2025, 4, 1),
          ),
        ],
      );
      expect(c.read(motdSermonProvider)?.id, 'b');
    });

    test('dailyMotdPick varies with the date but not with list order', () {
      final library = archive();
      final picks = {
        for (var d = 1; d <= 20; d++)
          dailyMotdPick(library, DateTime(2026, 9, d))!.id,
      };
      expect(picks.length, greaterThan(1));
      expect(
        dailyMotdPick(library.reversed.toList(), today)!.id,
        dailyMotdPick(library, today)!.id,
      );
    });
  });
}
