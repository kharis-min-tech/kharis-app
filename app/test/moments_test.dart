import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kharis_app/features/messages/data/moments_repository.dart';

void main() {
  late FakeFirebaseFirestore db;

  /// A document as `syncYouTube` writes it.
  Future<void> upload(
    String videoId, {
    required String title,
    required int seconds,
    required DateTime published,
    String source = 'youtube',
    String? thumbnail,
  }) => db.collection('sermons').doc('yt_$videoId').set({
    'videoId': videoId,
    'title': title,
    'duration': seconds,
    'publishedAt': Timestamp.fromDate(published),
    'source': source,
    'type': 'video',
    'speaker': 'David Antwi',
    'thumbnailUrl':
        thumbnail ?? 'https://i.ytimg.com/vi/$videoId/hqdefault.jpg',
  });

  Future<List<Moment>> moments() => MomentsRepository(db).latest();

  setUp(() => db = FakeFirebaseFirestore());

  test('a video under three minutes is a Moment', () async {
    await upload(
      'short1',
      title: 'TRY THE BIBLE...it will change your life!',
      seconds: 50,
      published: DateTime(2026, 10, 23),
    );

    final moment = (await moments()).single;
    expect(moment.videoId, 'short1');
    expect(moment.title, 'TRY THE BIBLE...it will change your life!');
    expect(moment.duration, const Duration(seconds: 50));
    expect(moment.thumbnailUrl, 'https://i.ytimg.com/vi/short1/hqdefault.jpg');
    expect(moment.publishedAt, DateTime(2026, 10, 23));
    expect(moment.youtubeUrl, 'https://www.youtube.com/shorts/short1');
  });

  test('a full message is not a Moment', () async {
    await upload(
      'full1',
      title: 'Sunday Service | David Antwi',
      seconds: 5400,
      published: DateTime(2026, 11, 1),
    );
    await upload(
      'edge',
      title: 'Exactly three minutes',
      seconds: 180,
      published: DateTime(2026, 10, 30),
    );

    expect(await moments(), isEmpty);
  });

  test(
    'a video tagged #shorts is a Moment when its length is unknown',
    () async {
      await upload(
        'tagged',
        title: 'Beauty of Christianity #shorts #christianity',
        seconds: 0,
        published: DateTime(2025, 9, 24),
      );

      final moment = (await moments()).single;
      expect(moment.videoId, 'tagged');
      expect(moment.duration, isNull);
    },
  );

  test('a video of unknown length with no tag is left out', () async {
    await upload(
      'unknown',
      title: 'Morning Session',
      seconds: 0,
      published: DateTime(2026, 9, 18),
    );

    expect(await moments(), isEmpty);
  });

  test('newest first', () async {
    await upload(
      'older',
      title: 'Older',
      seconds: 30,
      published: DateTime(2026, 9, 1),
    );
    await upload(
      'newest',
      title: 'Newest',
      seconds: 45,
      published: DateTime(2026, 10, 27),
    );
    await upload(
      'middle',
      title: 'Middle',
      seconds: 60,
      published: DateTime(2026, 10, 6),
    );

    expect(
      [for (final m in await moments()) m.videoId],
      ['newest', 'middle', 'older'],
    );
  });

  test('hand-added audio sermons are never Moments', () async {
    await upload(
      'cms',
      title: 'A short audio word',
      seconds: 90,
      published: DateTime(2026, 10, 1),
      source: 'admin',
    );

    expect(await moments(), isEmpty);
  });

  test('HTML entities in a title are decoded', () async {
    await upload(
      'amp',
      title: 'IT&#39;S YOUR SEASON &amp; IT&#39;S YOUR TIME!',
      seconds: 64,
      published: DateTime(2026, 10, 27),
    );

    expect(
      (await moments()).single.title,
      "IT'S YOUR SEASON & IT'S YOUR TIME!",
    );
  });

  test('a missing thumbnail falls back to YouTube\'s own still', () async {
    await upload(
      'nothumb',
      title: 'No thumbnail',
      seconds: 20,
      published: DateTime(2026, 10, 2),
      thumbnail: '',
    );

    expect(
      (await moments()).single.thumbnailUrl,
      'https://i.ytimg.com/vi/nothumb/hqdefault.jpg',
    );
  });

  test('a document with no video id is skipped', () async {
    await db.collection('sermons').doc('yt_broken').set({
      'title': 'Broken',
      'duration': 20,
      'publishedAt': Timestamp.fromDate(DateTime(2026, 10, 2)),
      'source': 'youtube',
    });

    expect(await moments(), isEmpty);
  });

  test('only the newest uploads are read', () async {
    for (var i = 0; i < MomentsRepository.uploadWindow + 5; i++) {
      await upload(
        'clip$i',
        title: 'Clip $i',
        seconds: 30,
        published: DateTime(2026, 1, 1).add(Duration(days: i)),
      );
    }

    final list = await moments();
    expect(list, hasLength(MomentsRepository.uploadWindow));
    expect(list.first.videoId, 'clip${MomentsRepository.uploadWindow + 4}');
  });
}
