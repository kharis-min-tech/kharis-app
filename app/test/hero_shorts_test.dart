import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kharis_app/features/home/data/hero_shorts_repository.dart';

final _now = DateTime(2026, 10, 20);

HeroShort _short(
  String id, {
  int seconds = 45,
  int views = 1000,
  int daysOld = 10,
  bool pastor = true,
}) => HeroShort(
  videoId: id,
  title: 'Short $id',
  seconds: seconds,
  views: views,
  publishedAt: _now.subtract(Duration(days: daysOld)),
  thumbnailUrl: 'https://i.ytimg.com/vi/$id/hqdefault.jpg',
  bySeniorPastor: pastor,
);

/// The two YouTube Data API answers for a Shorts playlist of [shorts].
String _answer(String url, List<(String, int, int, String)> shorts) {
  if (url.contains('/playlistItems')) {
    return jsonEncode({
      'items': [
        for (final (id, _, _, title) in shorts)
          {
            'contentDetails': {'videoId': id},
            'snippet': {'title': title},
          },
      ],
    });
  }
  return jsonEncode({
    'items': [
      for (final (id, secs, views, title) in shorts)
        {
          'id': id,
          'contentDetails': {'duration': 'PT${secs}S'},
          'statistics': {'viewCount': '$views'},
          'snippet': {
            'title': title,
            'publishedAt': _now
                .subtract(const Duration(days: 5))
                .toIso8601String(),
          },
        },
    ],
  });
}

void main() {
  group('pickHeroShorts', () {
    test('drops clips under 30 s and older than 180 days, however popular', () {
      final picks = pickHeroShorts([
        _short('viral', seconds: 12, views: 4000000),
        _short('old', daysOld: 400, views: 90000),
        _short('ok'),
      ], now: _now);
      expect(picks.map((s) => s.videoId), ['ok']);
    });

    test('a longer saying by the Senior Pastor outranks a busier generic '
        'clip of similar reach', () {
      final picks = pickHeroShorts([
        _short('generic', seconds: 31, views: 5000, pastor: false),
        _short('saying', seconds: 85, views: 3000),
      ], now: _now);
      expect(picks.first.videoId, 'saying');
    });

    test('keeps the best three', () {
      final picks = pickHeroShorts([
        for (var i = 0; i < 6; i++) _short('s$i', views: 1000 * (i + 1)),
      ], now: _now);
      expect(picks.map((s) => s.videoId), ['s5', 's4', 's3']);
    });
  });

  test('titles lose their hashtags', () {
    expect(
      cleanShortTitle('Have you tried fasting? #shorts #davidantwi #fasting'),
      'Have you tried fasting?',
    );
    expect(
      cleanShortTitle('HAVE YOU PRAYED? #shorts #pray'),
      'HAVE YOU PRAYED?',
    );
  });

  group('HeroShortsRepository', () {
    late SharedPreferences prefs;
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    test('reads the Shorts from YouTube, then serves them from the cache '
        'for six hours', () async {
      var calls = 0;
      var now = _now;
      final repo = HeroShortsRepository(
        prefs: () => prefs,
        apiKey: 'key',
        clock: () => now,
        fetch: (url) async {
          calls++;
          return _answer(url, [
            ('a1', 60, 900, 'Have you prayed? #shorts #davidantwi'),
            ('b2', 15, 9000, 'Quick clip #shorts'),
          ]);
        },
      );

      final first = await repo.getShorts();
      expect(first.map((s) => s.videoId), ['a1'], reason: 'b2 is too short');
      expect(first.single.title, 'Have you prayed?');
      expect(first.single.bySeniorPastor, isTrue);
      expect(calls, 2, reason: 'playlist, then lengths and views');

      now = now.add(const Duration(hours: 5));
      await repo.getShorts();
      expect(calls, 2, reason: 'inside six hours: no quota spent');

      now = now.add(const Duration(hours: 2));
      await repo.getShorts();
      expect(calls, 4, reason: 'stale: refreshed');
    });

    test(
      'offline: the last picks are kept rather than an empty hero',
      () async {
        var now = _now;
        var online = true;
        final repo = HeroShortsRepository(
          prefs: () => prefs,
          apiKey: 'key',
          clock: () => now,
          fetch: (url) async {
            if (!online) throw Exception('offline');
            return _answer(url, [('a1', 60, 900, 'Have you prayed?')]);
          },
        );
        await repo.getShorts();
        online = false;
        now = now.add(const Duration(days: 1));
        expect((await repo.getShorts()).map((s) => s.videoId), ['a1']);
      },
    );

    test('no API key: nothing is fetched', () async {
      var calls = 0;
      final repo = HeroShortsRepository(
        prefs: () => prefs,
        apiKey: '',
        fetch: (_) async {
          calls++;
          return '{}';
        },
      );
      expect(await repo.getShorts(), isEmpty);
      expect(calls, 0);
    });
  });
}
