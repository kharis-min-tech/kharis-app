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
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
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
        }
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
    }
  ],
};

void main() {
  KharisApiSermonRepository repo() {
    final dio = Dio()..httpClientAdapter = _FixtureAdapter(jsonEncode(_fixture));
    return KharisApiSermonRepository(dio: dio);
  }

  test('maps API JSON into the Sermon model', () async {
    final sermons = await repo().getSermons();
    expect(sermons, isNotEmpty);
    final s = sermons.first;
    expect(s.title, 'Riding On Divine Assignment');
    expect(s.speaker, 'David Antwi');
    expect(s.series, 'Book of Acts');
    expect(s.duration, const Duration(seconds: 2046));
  });

  test('prepends https:// to the scheme-less audio download_url', () async {
    final s = (await repo().getSermons()).first;
    expect(s.audioUrl, 'https://yetanothersermon.host/_/kc/media/mp3/95676.mp3');
  });

  test('extracts the YouTube id from video_link (ignoring &t=)', () async {
    final s = (await repo().getSermons()).first;
    expect(s.videoId, '6Y15Ja9E2hw');
  });

  test('requests a larger artwork width than the default 256', () async {
    final s = (await repo().getSermons()).first;
    expect(s.artworkUrl, contains('width=512'));
  });
}
