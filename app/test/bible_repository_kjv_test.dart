import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kharis_app/features/home/data/bible_repository.dart';

/// Answers YouVersion requests by path and records every path asked for.
class _FakeYouVersion {
  _FakeYouVersion(this.responses);

  final Map<String, Object> responses;
  final paths = <String>[];

  Dio get dio => Dio()
    ..interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final path = options.uri.path;
          paths.add(path);
          final body = responses[path];
          if (body == null) {
            handler.reject(
              DioException.badResponse(
                statusCode: 404,
                requestOptions: options,
                response: Response(requestOptions: options, statusCode: 404),
              ),
            );
            return;
          }
          handler.resolve(Response(requestOptions: options, data: body));
        },
      ),
    );
}

const _licensed = {
  'data': [
    {'id': 111, 'abbreviation': 'NIV11', 'title': 'New International Version'},
    {'id': 12, 'abbreviation': 'ASV', 'title': 'American Standard Version'},
    {'id': 3034, 'abbreviation': 'BSB', 'title': 'Berean Standard Bible'},
  ],
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the bundled KJV is offered after the licensed versions', () async {
    final api = _FakeYouVersion({'/v1/bibles': _licensed});
    final versions = await BibleRepository(
      dio: api.dio,
      appKey: 'test',
    ).getBibles();

    expect(versions.map((v) => v.id), [111, 12, 1]);
    expect(versions.last.abbreviation, 'KJV');
    expect(versions.last.title, 'King James Version');
  });

  test('KJV books come from the bundle: 66 books, Psalm 119 has 176 '
      'verses', () async {
    final api = _FakeYouVersion({});
    // No app key: the bundled text needs neither a key nor the network.
    final books = await BibleRepository(dio: api.dio, appKey: '').getBooks(1);

    expect(books, hasLength(66));
    expect(books.first.usfm, 'GEN');
    expect(books.last.usfm, 'REV');
    final psalms = books.firstWhere((b) => b.usfm == 'PSA');
    expect(psalms.title, 'Psalms');
    expect(psalms.chapters, hasLength(150));
    expect(psalms.verseCounts[119], 176);
    expect(books.firstWhere((b) => b.usfm == 'JHN').verseCounts[3], 36);
    expect(api.paths, isEmpty);
  });

  test('a KJV chapter is one paragraph of numbered verses', () async {
    final api = _FakeYouVersion({});
    final passage = await BibleRepository(
      dio: api.dio,
      appKey: '',
    ).getPassage('JHN.3', bibleId: 1, abbreviation: 'KJV');

    expect(passage.reference, 'John 3');
    expect(passage.bibleAbbreviation, 'KJV');
    expect(passage.copyright, 'Public domain');
    expect(passage.blocks.single.styleClass, 'p');
    final segments = passage.blocks.single.segments;
    expect(segments.map((s) => s.verse), [for (var v = 1; v <= 36; v++) v]);
    expect(segments[15].text, startsWith('For God so loved the world'));
    expect(api.paths, isEmpty);
  });

  test('KJV verse and range ids return just those verses', () async {
    final repo = BibleRepository(dio: _FakeYouVersion({}).dio, appKey: '');

    final verse = await repo.getPassage('JHN.3.16', bibleId: 1);
    expect(verse.reference, 'John 3:16');
    expect(verse.blocks.single.segments.single.verse, 16);

    final range = await repo.getPassage('PSA.23.1-3', bibleId: 1);
    expect(range.reference, 'Psalms 23:1-3');
    expect(range.blocks.single.segments.map((s) => s.verse), [1, 2, 3]);
    expect(
      range.blocks.single.segments.first.text,
      'The LORD is my shepherd; I shall not want.',
    );

    await expectLater(
      repo.getPassage('JHN.22', bibleId: 1),
      throwsA(isA<StateError>()),
    );
  });

  test('when YouVersion lists KJV it is used, with no duplicate', () async {
    final api = _FakeYouVersion({
      '/v1/bibles': {
        'data': [
          ..._licensed['data']!,
          {'id': 1, 'abbreviation': 'KJV', 'title': 'King James Version (YV)'},
        ],
      },
      '/v1/bibles/1/passages/JHN.3': {
        'reference': 'John 3',
        'copyright': 'YouVersion',
        'content':
            '<div class="p"><span class="yv-vlbl">16</span>'
            'For God so loved the world (from YouVersion)</div>',
      },
    });
    final repo = BibleRepository(dio: api.dio, appKey: 'test');

    final versions = await repo.getBibles();
    expect(versions.where((v) => v.id == 1), hasLength(1));
    expect(versions.map((v) => v.id), [111, 12, 1]);
    expect(versions.last.title, 'King James Version (YV)');

    final passage = await repo.getPassage('JHN.3', bibleId: 1);
    expect(api.paths, contains('/v1/bibles/1/passages/JHN.3'));
    expect(passage.copyright, 'YouVersion');
    expect(
      passage.blocks.single.segments.single.text,
      'For God so loved the world (from YouVersion)',
    );
  });
}
