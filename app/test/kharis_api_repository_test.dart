import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kharis_app/features/messages/data/kharis_api_sermon_repository.dart';

/// Serves a fixed JSON body for every request, so the repository can be tested
/// without touching the network.
class _FixtureAdapter implements HttpClientAdapter {
  _FixtureAdapter(this.body);
  final String body;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      body,
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

const _fixture = {
  'count': 1,
  'next': null,
  'previous': null,
  'results': [
    {
      'id': 97840,
      'title': 'Riding On Divine Assignment',
      'time': '10:00:00',
      'date': '2026-07-12',
      'passages': ['Acts 27:27-44'],
      'series': {
        'id': 4394,
        'name': 'Book of Acts',
        'url': 'yetanothersermon.host/_/kc/series/4394/book-of-acts/',
      },
      'preachers': [
        {
          'id': 1880,
          'name': 'David Antwi',
          'url': 'yetanothersermon.host/_/kc/preachers/1880/david-antwi/',
        },
      ],
      'audio_link': {
        'id': 95676,
        'duration': 2046,
        'filesize': 32754211,
        'download_url': 'yetanothersermon.host/_/kc/media/mp3/95676.mp3',
        'name': 'x.mp3',
      },
      'video_link': 'https://www.youtube.com/watch?v=6Y15Ja9E2hw&t=860s',
      'image': 'https://yash.b-cdn.net/media/images/Kharis.jpeg?width=256',
      'description': 'Feeling overwhelmed by life\'s storms?',
    },
  ],
};

void main() {
  KharisApiSermonRepository repo() {
    final dio = Dio()
      ..httpClientAdapter = _FixtureAdapter(jsonEncode(_fixture));
    return KharisApiSermonRepository(dio: dio);
  }

  test('maps API JSON into the Sermon model', () async {
    final sermons = (await repo().fetchPage()).sermons;
    expect(sermons, isNotEmpty);
    final s = sermons.first;
    expect(s.title, 'Riding On Divine Assignment');
    expect(s.speaker, 'David Antwi');
    expect(s.series, 'Book of Acts');
    expect(s.duration, const Duration(seconds: 2046));
  });

  test('prepends https:// to the scheme-less audio download_url', () async {
    final s = ((await repo().fetchPage()).sermons).first;
    expect(
      s.audioUrl,
      'https://yetanothersermon.host/_/kc/media/mp3/95676.mp3',
    );
  });

  test('extracts the YouTube id from video_link (ignoring &t=)', () async {
    final s = ((await repo().fetchPage()).sermons).first;
    expect(s.videoId, '6Y15Ja9E2hw');
  });

  test('requests a larger artwork width than the default 256', () async {
    final s = ((await repo().fetchPage()).sermons).first;
    expect(s.artworkUrl, contains('width=512'));
  });

  // ── Pagination ─────────────────────────────────────────────────────────────

  Map<String, dynamic> pagedFixture({
    required int id,
    required String title,
    String? next,
    int count = 2,
  }) {
    final item =
        Map<String, dynamic>.from((_fixture['results']! as List).first as Map)
          ..['id'] = id
          ..['title'] = title;
    return {
      'count': count,
      'next': next,
      'previous': null,
      'results': [item],
    };
  }

  KharisApiSermonRepository routedRepo(Map<String, String> routes) {
    final dio = Dio(BaseOptions(baseUrl: 'https://x.test/api/'))
      ..httpClientAdapter = _RoutingAdapter(routes);
    return KharisApiSermonRepository(dio: dio);
  }

  test('fetchPage surfaces next link and total count', () async {
    final repo = routedRepo({
      'sermons/': jsonEncode(
        pagedFixture(
          id: 1,
          title: 'Page One',
          next: 'https://x.test/api/sermons/?page=2',
        ),
      ),
    });
    final page = await repo.fetchPage();
    expect(page.sermons.single.title, 'Page One');
    expect(page.nextUrl, 'https://x.test/api/sermons/?page=2');
    expect(page.totalCount, 2);
    expect(page.hasMore, isTrue);
  });

  test('fetchPage follows an absolute next URL to the second page', () async {
    final repo = routedRepo({
      'sermons/': jsonEncode(
        pagedFixture(
          id: 1,
          title: 'Page One',
          next: 'https://x.test/api/sermons/?page=2',
        ),
      ),
      'sermons/?page=2': jsonEncode(pagedFixture(id: 2, title: 'Page Two')),
    });
    final first = await repo.fetchPage();
    final second = await repo.fetchPage(url: first.nextUrl);
    expect(second.sermons.single.title, 'Page Two');
    expect(second.nextUrl, isNull);
    expect(second.hasMore, isFalse);
  });

  test('fetchPage passes the search query to the server', () async {
    final repo = routedRepo({
      'sermons/?search=grace': jsonEncode(
        pagedFixture(id: 3, title: 'Grace Hit', count: 1),
      ),
    });
    final page = await repo.fetchPage(search: 'grace');
    expect(page.sermons.single.title, 'Grace Hit');
  });

  // ── Mapping ────────────────────────────────────────────────────────────────

  Map<String, dynamic> record({
    Object? audio = const {'download_url': 'yetanothersermon.host/a.mp3'},
    String? video,
    String title = 'Grace To Continue',
    String? series,
  }) => {
    'id': 7,
    'title': title,
    'date': '2025-06-25',
    'time': null,
    'series': series == null ? null : {'name': series},
    'preachers': const [],
    'audio_link': audio,
    'video_link': video,
    'image': null,
    'description': null,
  };

  test('category is the topic, never the series name', () {
    final s = mapApiSermon(record(series: 'June Fast 2025'));
    expect(s.series, 'June Fast 2025');
    expect(s.category, 'Grace & Salvation');
  });

  test('video-only and media-less records are kept, not dropped', () {
    final videoOnly = mapApiSermon(
      record(audio: null, video: 'https://www.youtube.com/watch?v=Htl4RmpLSCI'),
    );
    expect(videoOnly.hasAudio, isFalse);
    expect(videoOnly.videoId, 'Htl4RmpLSCI');

    final none = mapApiSermon(record(audio: null, video: ''));
    expect(none.hasAudio || none.hasVideo, isFalse);
    expect(none.id, '7');
  });

  test('t= on the video link becomes videoStart', () {
    final s = mapApiSermon(
      record(video: 'https://www.youtube.com/watch?v=6Y15Ja9E2hw&t=860s'),
    );
    expect(s.videoStart, const Duration(seconds: 860));
  });

  group('youTubeVideoId', () {
    const id = 'L2Ji3skMKV0';
    for (final link in [
      'https://www.youtube.com/watch?v=$id',
      'https://www.youtube.com/watch?v=$id&t=487s',
      'https://m.youtube.com/watch?feature=share&v=$id',
      'https://youtu.be/$id',
      'https://youtu.be/$id?si=abc&t=30',
      'https://www.youtube.com/live/$id?si=x',
      'https://www.youtube.com/shorts/$id',
      'https://www.youtube.com/embed/$id?start=12',
      'https://www.youtube-nocookie.com/embed/$id',
      'https://www.youtube.com/$id?si=WOcnaYH4LKM9kWf9',
      'youtube.com/watch?v=$id',
    ]) {
      test(link, () => expect(youTubeVideoId(link), id));
    }

    for (final bad in [
      null,
      '',
      'https://vimeo.com/12345678901',
      'https://www.youtube.com/watch?v=short',
      'https://www.youtube.com/channel/UC4l8WmdF9ivMDQHHVOdYKqQ',
      'https://www.youtube.com/',
    ]) {
      test('rejects $bad', () => expect(youTubeVideoId(bad), isNull));
    }
  });

  group('youTubeStart', () {
    test('seconds forms', () {
      expect(
        youTubeStart('https://youtu.be/x?t=860s'),
        const Duration(seconds: 860),
      );
      expect(
        youTubeStart('https://youtu.be/x?t=860'),
        const Duration(seconds: 860),
      );
      expect(
        youTubeStart('https://www.youtube.com/embed/x?start=12'),
        const Duration(seconds: 12),
      );
    });

    test('h/m/s form', () {
      expect(
        youTubeStart('https://www.youtube.com/watch?v=x&t=1h2m3s'),
        const Duration(hours: 1, minutes: 2, seconds: 3),
      );
    });

    test('absent or zero is null', () {
      expect(youTubeStart('https://youtu.be/x'), isNull);
      expect(youTubeStart('https://youtu.be/x?t=0'), isNull);
      expect(youTubeStart(null), isNull);
    });
  });
}

/// Routes requests by path+query so multi-page flows can be scripted.
class _RoutingAdapter implements HttpClientAdapter {
  _RoutingAdapter(this.routes);

  /// Keys are `path?query` relative to the base URL (or any suffix thereof).
  final Map<String, String> routes;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final uri = options.uri.toString();
    final key = routes.keys.firstWhere(
      uri.endsWith,
      orElse: () => throw StateError('no route for $uri'),
    );
    return ResponseBody.fromString(
      routes[key]!,
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
