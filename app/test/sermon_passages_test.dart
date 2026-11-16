import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kharis_app/core/services/cache_service.dart';
import 'package:kharis_app/features/messages/data/kharis_api_sermon_repository.dart';
import 'package:kharis_app/shared/models/sermon.dart';

const _base = Sermon(
  id: '100513',
  title: 'The Book of Acts Continues',
  speaker: 'David Antwi',
  audioUrl: 'https://cdn.example/100513.mp3',
);

void main() {
  group('Sermon.passages', () {
    test('is empty unless given', () {
      expect(_base.passages, isEmpty);
    });

    test('survives the JSON round trip and copyWith', () {
      final s = _base.copyWith(passages: ['Luke 24:27', 'Acts 2:41-42']);
      final back = Sermon.fromJson(
        jsonDecode(jsonEncode(s.toJson())) as Map<String, dynamic>,
      );
      expect(back, s);
      expect(back.passages, ['Luke 24:27', 'Acts 2:41-42']);
      expect(back.copyWith(title: 'x').passages, [
        'Luke 24:27',
        'Acts 2:41-42',
      ]);
    });

    test('entries cached before the field existed load with none', () {
      final legacy = {'id': '1', 'title': 'T', 'speaker': 'S', 'audioUrl': ''};
      final s = Sermon.fromJson(legacy);
      expect(s.passages, isEmpty);
      // An empty list is not written, so old and new cache entries match.
      expect(s.toJson().keys, isNot(contains('passages')));
    });

    test('a malformed cached value loads as none', () {
      Sermon load(Object? passages) => Sermon.fromJson({
        'id': '1',
        'title': 'T',
        'speaker': 'S',
        'audioUrl': '',
        'passages': passages,
      });
      expect(load('Acts 2:1').passages, isEmpty);
      expect(load(null).passages, isEmpty);
      expect(load(['Acts 2:1', '', 4, ' John 3:16 ']).passages, [
        'Acts 2:1',
        'John 3:16',
      ]);
    });

    test('is part of equality and the hash', () {
      final a = _base.copyWith(passages: ['Acts 2:1']);
      final b = _base.copyWith(passages: ['Acts 2:1']);
      final c = _base.copyWith(passages: ['Acts 2:2']);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
      expect(a, isNot(_base));
    });
  });

  test('the archive cache keeps passages, and reads archives without them', () {
    final fetchedAt = DateTime.utc(2026, 11, 15, 9);
    final restored = decodeSermonArchive(
      encodeSermonArchive(
        SermonArchiveSnapshot(
          fetchedAt: fetchedAt,
          sermons: [
            _base.copyWith(passages: ['Acts 20:17-38']),
            _base.copyWith(id: '2'),
          ],
        ),
      ),
    )!;
    expect(restored.sermons.first.passages, ['Acts 20:17-38']);
    expect(restored.sermons.last.passages, isEmpty);

    // An archive written by a build that did not know the field.
    final legacy = decodeSermonArchive(
      jsonEncode({
        'v': 2,
        'fetchedAt': fetchedAt.toIso8601String(),
        'sermons': [
          {'id': '1', 'title': 'T', 'speaker': 'S', 'audioUrl': ''},
        ],
      }),
    )!;
    expect(legacy.sermons.single.passages, isEmpty);
  });

  test('every record of the recorded API page maps its passages', () {
    final records =
        jsonDecode(File('test/fixtures/sermons_sample.json').readAsStringSync())
            as List;
    final sermons = mapApiSermons(records);
    expect(sermons, hasLength(records.length));
    for (var i = 0; i < records.length; i++) {
      expect(
        sermons[i].passages,
        (records[i] as Map<String, dynamic>)['passages'],
        reason: 'record ${sermons[i].id}',
      );
    }
    expect(sermons.first.passages, [
      'Luke 24:27',
      'Luke 24:44-49',
      'Acts 2:41-42',
    ]);
    expect(sermons.any((s) => s.passages.isEmpty), isTrue);
  });
}
