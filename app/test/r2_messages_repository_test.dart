import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kharis_app/core/constants/http_constants.dart';
import 'package:kharis_app/features/messages/data/kharis_api_sermon_repository.dart';
import 'package:kharis_app/features/messages/data/r2_messages_repository.dart';
import 'package:kharis_app/features/messages/data/sermon_repository_base.dart';
import 'package:kharis_app/shared/models/sermon.dart';

Map<String, dynamic> _record(String id, {String? transcript, String? audio}) =>
    {
      'id': id,
      'title': 'Sermon $id',
      'speaker': 'David Antwi',
      'date_preached': '2026-09-${id.padLeft(2, '0')}',
      'audio_url': audio ?? 'https://x.test/$id.mp3',
      'transcript_url': transcript,
    };

Sermon _apiSermon(String id) => Sermon(
  id: id,
  title: 'Sermon $id',
  speaker: 'David Antwi',
  audioUrl: 'https://x.test/$id.mp3',
);

/// The live API: scripted page 1, plus a record of every call.
class _FakeApi extends KharisApiSermonRepository {
  _FakeApi({this.head = const [], this.fail = false});

  final List<Sermon> head;
  final bool fail;
  final calls = <(String?, String?)>[];

  @override
  Future<SermonPage> fetchPage({String? url, String? search}) async {
    calls.add((url, search));
    if (fail) throw StateError('api down');
    return SermonPage(
      sermons: head,
      nextUrl: 'https://x.test/sermons/?page=2',
      totalCount: 1489,
    );
  }
}

/// A Dio whose every request answers with [messages] (or fails).
(Dio, List<String>) _bucket({List<Map<String, dynamic>>? messages}) {
  final hits = <String>[];
  final dio = Dio()
    ..interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          hits.add(options.uri.toString());
          if (messages == null) {
            handler.reject(
              DioException(requestOptions: options, message: 'r2 down'),
            );
          } else {
            handler.resolve(
              Response(requestOptions: options, data: {'messages': messages}),
            );
          }
        },
      ),
    );
  return (dio, hits);
}

void main() {
  test('page 1 is the whole mirror headed by newer API arrivals, '
      'with R2 transcripts carried onto API rows', () async {
    final (dio, _) = _bucket(
      messages: [
        _record('20', transcript: 'transcripts/20.txt'),
        _record('19'),
      ],
    );
    final repo = R2MessagesRepository(
      dio: dio,
      api: _FakeApi(head: [_apiSermon('21'), _apiSermon('20')]),
    );

    final page = await repo.fetchPage();

    expect(page.sermons.map((s) => s.id), ['21', '20', '19']);
    expect(
      page.sermons[1].transcriptUrl,
      '$kR2BucketBaseUrl/transcripts/20.txt',
    );
    expect(page.hasMore, isFalse, reason: 'the archive is already complete');
    expect(page.totalCount, 3);
  });

  test(
    'the mirror alone still serves the archive when the API is down',
    () async {
      final (dio, _) = _bucket(messages: [_record('20'), _record('19')]);
      final repo = R2MessagesRepository(dio: dio, api: _FakeApi(fail: true));

      final page = await repo.fetchPage();

      expect(page.sermons.map((s) => s.id), ['20', '19']);
      expect(page.hasMore, isFalse);
    },
  );

  test(
    'an unreachable or empty bucket falls back to the paged API walk',
    () async {
      for (final messages in [null, const <Map<String, dynamic>>[]]) {
        final (dio, _) = _bucket(messages: messages);
        final repo = R2MessagesRepository(
          dio: dio,
          api: _FakeApi(head: [_apiSermon('21')]),
        );

        final page = await repo.fetchPage();

        expect(page.sermons.map((s) => s.id), ['21']);
        expect(page.nextUrl, 'https://x.test/sermons/?page=2');
        expect(page.totalCount, 1489);
      }
    },
  );

  test('both sources down propagates the failure', () async {
    final (dio, _) = _bucket();
    final repo = R2MessagesRepository(dio: dio, api: _FakeApi(fail: true));

    expect(repo.fetchPage(), throwsA(isA<StateError>()));
  });

  test('searches and next links go to the API, never the bucket', () async {
    final (dio, hits) = _bucket(messages: [_record('20')]);
    final api = _FakeApi(head: [_apiSermon('21')]);
    final repo = R2MessagesRepository(dio: dio, api: api);

    await repo.fetchPage(search: 'grace');
    await repo.fetchPage(url: 'https://x.test/sermons/?page=2');

    expect(hits, isEmpty);
    expect(api.calls, [
      (null, 'grace'),
      ('https://x.test/sermons/?page=2', null),
    ]);
  });

  test('mirror records map like API records', () {
    final s = mapR2Message({
      ..._record('7', audio: ''),
      'series': {'id': '4394', 'name': ' Book of Acts '},
      'video_url': 'https://www.youtube.com/watch?v=VdGcMD4Rwy8&t=487s',
      'image_url': 'https://cdn.test/a.jpeg?width=256',
    })!;

    // A video-only record stays listed, as the API mapping keeps it.
    expect(s.audioUrl, isEmpty);
    expect(s.videoId, 'VdGcMD4Rwy8');
    expect(s.videoStart, const Duration(seconds: 487));
    expect(s.series, 'Book of Acts');
    // The topic, never the series name.
    expect(s.category, isNot('Book of Acts'));
    expect(s.artworkUrl, 'https://cdn.test/a.jpeg?width=512');
    expect(mapR2Message({'title': 'no id'}), isNull);
  });
}
