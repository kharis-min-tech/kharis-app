import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kharis_app/core/constants/bible_books.dart';
import 'package:kharis_app/core/services/notification_service.dart';
import 'package:kharis_app/features/home/data/bible_reference.dart';
import 'package:kharis_app/features/home/data/bible_repository.dart';
import 'package:kharis_app/features/home/data/daily_content_repository.dart';
import 'package:kharis_app/features/bible/presentation/bible_routes.dart';
import 'package:kharis_app/features/bible/presentation/reader_layout_provider.dart';
import 'package:kharis_app/features/bible/presentation/screens/reading_screen.dart';
import 'package:kharis_app/shared/models/sermon.dart';
import 'package:kharis_app/shared/providers/cache_provider.dart';
import 'package:kharis_app/shared/providers/last_read_provider.dart';
import 'package:kharis_app/shared/providers/streaks_provider.dart';
import 'package:kharis_app/shared/providers/verse_marks_provider.dart';
import 'package:kharis_app/ui/components/components.dart';

import 'support/fake_cache_service.dart';
import 'package:kharis_app/shared/providers/bible_provider.dart';
import 'package:kharis_app/shared/providers/onboarding_provider.dart';
import 'package:kharis_app/shared/providers/sermon_provider.dart';

// ── Fixtures ──────────────────────────────────────────────────────────────────

/// The bundled canon with real verse counts for John 3 (36 verses).
BibleIndex _indexWithVerses() => BibleIndex([
  for (final b in kCanonBooks)
    b.usfm == 'JHN'
        ? BibleBook(
            usfm: b.usfm,
            title: b.name,
            testament: b.testament,
            chapters: [for (var c = 1; c <= b.chapters; c++) c],
            verseCounts: const {3: 36},
          )
        : BibleBook.canon(b),
]);

/// New Testament only, like TCENT.
BibleIndex _ntOnly() => BibleIndex([
  for (final b in kCanonBooks)
    if (b.testament == Testament.newTestament) BibleBook.canon(b),
]);

BibleLocation _found(String input, [BibleIndex? index]) {
  final result = parseBibleReference(input, index ?? BibleIndex.bundled());
  if (result is! ReferenceFound) {
    fail('"$input" did not parse: ${(result as ReferenceError).message}');
  }
  return result.location;
}

String _error(String input, [BibleIndex? index]) {
  final result = parseBibleReference(input, index ?? BibleIndex.bundled());
  if (result is! ReferenceError) {
    fail(
      '"$input" unexpectedly parsed to ${(result as ReferenceFound).location}',
    );
  }
  return result.message;
}

/// Answers from memory and records what the reader asked for.
class _FakeBibleRepository extends BibleRepository {
  _FakeBibleRepository() : super(appKey: 'test');

  final passageRequests = <String>[];
  bool offline = false;

  /// `bibleId/usfm` passages the version does not have (a 404).
  final missing = <String>{};

  /// When set, the version's book list never arrives (a stalled request).
  bool booksHang = false;

  @override
  Future<List<BibleVersion>> getBibles() async => const [
    BibleVersion(id: 111, abbreviation: 'NIV', title: 'New International'),
    BibleVersion(id: 2692, abbreviation: 'NASB2020', title: 'NASB 2020'),
  ];

  @override
  Future<List<BibleBook>> getBooks(int bibleId) => booksHang
      ? Completer<List<BibleBook>>().future
      : Future.value(_indexWithVerses().books);

  @override
  Future<BiblePassage> getPassage(
    String usfmId, {
    int bibleId = BibleRepository.defaultBibleId,
    String abbreviation = BibleRepository.defaultBibleAbbreviation,
  }) async {
    passageRequests.add('$bibleId/$usfmId');
    if (offline) {
      throw DioException.connectionError(
        requestOptions: RequestOptions(path: usfmId),
        reason: 'offline',
      );
    }
    if (missing.contains('$bibleId/$usfmId')) {
      final request = RequestOptions(path: usfmId);
      throw DioException.badResponse(
        statusCode: 404,
        requestOptions: request,
        response: Response(requestOptions: request, statusCode: 404),
      );
    }
    return BiblePassage(
      reference: usfmId,
      bibleAbbreviation: abbreviation,
      blocks: [
        PassageBlock(
          styleClass: 'p',
          segments: [
            for (var v = 1; v <= 36; v++)
              PassageSegment(
                verse: v,
                text: 'Verse $v of $usfmId in $abbreviation.',
                notes: v == 1 ? const ['Or in the beginning'] : const [],
              ),
          ],
        ),
      ],
    );
  }
}

DailyContent _today(String book, int chapter) => DailyContent(
  reading: DailyEntry(title: '$book $chapter', reference: '$book $chapter'),
  prayer: const DailyEntry(title: 'Lord, teach me.'),
);

/// A message preached from John 3:16, for the related-message marker.
const _sermon = Sermon(
  id: 'm1',
  title: 'For God so loved',
  speaker: 'Pastor David',
  audioUrl: 'https://example.org/m1.mp3',
  passages: ['John 3:16'],
);

List<Override> _overrides({
  required SharedPreferences prefs,
  required _FakeBibleRepository repo,
  required FakeCacheService cache,
  DailyContent? today,
  bool nothingToday = false,
}) => [
  sharedPreferencesProvider.overrideWithValue(prefs),
  cacheServiceProvider.overrideWithValue(cache),
  bibleRepositoryProvider.overrideWithValue(repo),
  sermonsProvider.overrideWith((ref) async => const [_sermon]),
  // A fixed day: the real one checks the clock on a timer.
  todayProvider.overrideWithValue(DateTime(2026, 11, 15)),
  dailyContentProvider.overrideWith(
    (ref) => Stream.value(nothingToday ? null : today ?? _today('John', 3)),
  ),
];

typedef _Reader = ({
  _FakeBibleRepository repo,
  SharedPreferences prefs,
  ProviderContainer container,
});

Future<_Reader> _pumpReader(
  WidgetTester tester, {
  DailyContent? today,
  bool nothingToday = false,
  Map<String, Object> prefs = const {},
  bool booksHang = false,
  Set<String> missing = const {},
  BibleLocation? location,
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final sharedPrefs = await SharedPreferences.getInstance();
  final repo = _FakeBibleRepository()
    ..booksHang = booksHang
    ..missing.addAll(missing);
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final container = ProviderContainer(
    overrides: _overrides(
      prefs: sharedPrefs,
      repo: repo,
      cache: FakeCacheService(),
      today: today,
      nothingToday: nothingToday,
    ),
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: KharisTheme.light(),
        home: ReadingScreen(location: location),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (repo: repo, prefs: sharedPrefs, container: container);
}

/// The Bible tab's routes, with `/reading` and `/highlights` redirecting in,
/// opened at [open].
Future<(GoRouter, _FakeBibleRepository)> _pumpRoutes(
  WidgetTester tester, {
  required String open,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final repo = _FakeBibleRepository();
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    initialLocation: open,
    routes: [bibleTabRoute, ...bibleRedirectRoutes],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: _overrides(
        prefs: prefs,
        repo: repo,
        cache: FakeCacheService(),
      ),
      child: MaterialApp.router(
        theme: KharisTheme.light(),
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (router, repo);
}

/// Opens the passage picker from the reader toolbar.
Future<void> _openPicker(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('bible-reference')));
  await tester.pumpAndSettle();
}

/// In the open picker: the book [usfm], then chapter [chapter] when given.
Future<void> _chooseBook(
  WidgetTester tester,
  String usfm, [
  int? chapter,
]) async {
  final book = find.byKey(Key('bible-book-$usfm'));
  await tester.ensureVisible(book);
  await tester.tap(book);
  await tester.pumpAndSettle();
  if (chapter != null) {
    final cell = find.byKey(Key('bible-chapter-$chapter'));
    await tester.ensureVisible(cell);
    await tester.tap(cell);
    await tester.pumpAndSettle();
  }
}

Finder _title(String label) => find.descendant(
  of: find.byKey(const Key('bible-chapter-title')),
  matching: find.text(label),
  matchRoot: true,
);

Iterable<KVersePart> _parts(WidgetTester tester) =>
    tester.widgetList<KVerse>(find.byType(KVerse)).expand((v) => v.parts);

/// The verses marked as searched for.
List<int?> _marked(WidgetTester tester) => [
  for (final p in _parts(tester))
    if (p.marked) p.number,
];

Future<void> _search(WidgetTester tester, String input) async {
  await tester.tap(find.byKey(const Key('bible-search')));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const Key('bible-search-field')), input);
  await tester.tap(find.byKey(const Key('bible-search-go')));
  await tester.pumpAndSettle();
}

Future<void> _tapNext(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(const Key('bible-next')));
  await tester.tap(find.byKey(const Key('bible-next')));
  await tester.pumpAndSettle();
}

Future<void> _tapVerse(WidgetTester tester, int verse) async {
  _parts(tester).firstWhere((p) => p.number == verse).onTap!();
  await tester.pumpAndSettle();
}

void main() {
  group('reference parser', () {
    test('book names, abbreviations, chapters and verses', () {
      expect(
        _found('John 3:16'),
        const BibleLocation('JHN', 3, verseStart: 16, verseEnd: 16),
      );
      expect(_found('Jn 3'), const BibleLocation('JHN', 3));
      expect(_found('Psalm 23'), const BibleLocation('PSA', 23));
      expect(_found('Psalms 23'), const BibleLocation('PSA', 23));
      expect(_found('ps 23'), const BibleLocation('PSA', 23));
      expect(
        _found('1 Cor 13:4-7'),
        const BibleLocation('1CO', 13, verseStart: 4, verseEnd: 7),
      );
      expect(_found('2 Corinthians 13'), const BibleLocation('2CO', 13));
      expect(_found('Deut 6:4').usfm, 'DEU');
      expect(_found('Matt 5'), const BibleLocation('MAT', 5));
      expect(_found('Phil 4:6').usfm, 'PHP');
      expect(_found('Phlm 1').usfm, 'PHM');
      expect(_found('Rev 22'), const BibleLocation('REV', 22));
      expect(_found('Song of Songs 2'), const BibleLocation('SNG', 2));
      expect(_found('Song of Solomon 2'), const BibleLocation('SNG', 2));
      expect(_found('Genesis'), const BibleLocation('GEN', 1));
      expect(_found('deu 6').usfm, 'DEU', reason: 'unique start of a name');
      expect(_found('Philippi 2').usfm, 'PHP');
    });

    test('numbered books in every common spelling', () {
      for (final input in [
        '1 Corinthians 13',
        '1Cor 13',
        '1cor13',
        '1 Co 13',
        'I Corinthians 13',
        'First Corinthians 13',
        '1st Cor 13',
        '1 Cor. 13',
      ]) {
        expect(_found(input), const BibleLocation('1CO', 13), reason: input);
      }
      expect(_found('2 Sam 7').usfm, '2SA');
      expect(_found('II Kings 2').usfm, '2KI');
      expect(_found('1 Jn 4:8').usfm, '1JN');
      expect(_found('III John 1').usfm, '3JN');
      expect(_found('2 Tim 3:16').usfm, '2TI');
      expect(_found('1 Thess 5').usfm, '1TH');
      expect(_found('1 Pet 2').usfm, '1PE');
      expect(_found('2 Chron 7:14').usfm, '2CH');
    });

    test('loose punctuation and spacing', () {
      const john316 = BibleLocation('JHN', 3, verseStart: 16, verseEnd: 16);
      expect(_found('  JOHN   3 : 16 '), john316);
      expect(_found('john 3.16'), john316);
      expect(_found('Jn. 3:16'), john316);
      expect(
        _found('1 Corinthians 13:4\u20137'),
        const BibleLocation('1CO', 13, verseStart: 4, verseEnd: 7),
        reason: 'en dash range',
      );
    });

    test('single-chapter books read a lone number as a verse', () {
      expect(
        _found('Jude 3'),
        const BibleLocation('JUD', 1, verseStart: 3, verseEnd: 3),
      );
      expect(_found('Jude 1'), const BibleLocation('JUD', 1));
      expect(_found('Obadiah'), const BibleLocation('OBA', 1));
    });

    test('verse ranges are checked against the chapter when known', () {
      final index = _indexWithVerses();
      expect(_error('John 3:40', index), 'John 3 has 36 verses.');
      expect(
        _found('John 3:34-50', index),
        const BibleLocation('JHN', 3, verseStart: 34, verseEnd: 36),
        reason: 'a range running past the end stops at the last verse',
      );
      expect(_error('John 3:18-16', index), contains('runs backwards'));
      expect(_error('John 3:0', index), 'John 3 has 36 verses.');
    });

    test('bad input explains itself', () {
      expect(_error(''), contains('Type a reference'));
      expect(_error('   '), contains('Type a reference'));
      expect(
        _error('Hezekiah 3'),
        'We couldn\u2019t find a book called \u201cHezekiah\u201d.',
      );
      expect(_error('John 22'), 'John has 21 chapters.');
      expect(_error('Psalm 151'), 'Psalms has 150 chapters.');
      expect(_error('2 Corinthians 17'), '2 Corinthians has 13 chapters.');
      expect(_error('Obadiah 1:0'), contains('no verse 0'));
      expect(
        _error('Jo 3'),
        '\u201cJo\u201d could be Joshua, Job, Joel, Jonah or John. '
        'Type a little more of the name.',
      );
      expect(_error('3:16'), contains('couldn\u2019t read'));
      expect(_error('John 3:16-4:2'), contains('couldn\u2019t read'));
      expect(_error('John three'), contains('couldn\u2019t'));
    });

    test('numbers too long for an int are explained, not thrown', () {
      const huge = '99999999999999999999';
      expect(_error('John $huge'), 'John has 21 chapters.');
      expect(
        _error('John 3:$huge', _indexWithVerses()),
        'John 3 has 36 verses.',
      );
      expect(
        _found('John 3:16-$huge', _indexWithVerses()),
        const BibleLocation('JHN', 3, verseStart: 16, verseEnd: 36),
      );
    });

    test('a book missing from the version says so', () {
      expect(
        _error('Psalm 23', _ntOnly()),
        'Psalms isn\u2019t in this translation. Try another version.',
      );
      expect(_found('John 3', _ntOnly()), const BibleLocation('JHN', 3));
    });

    test('daily-reading book names resolve to USFM', () {
      expect(resolveBookUsfm('Psalms'), 'PSA');
      expect(resolveBookUsfm('Psalm'), 'PSA');
      expect(resolveBookUsfm('Song of Songs'), 'SNG');
      expect(resolveBookUsfm('2 Corinthians'), '2CO');
      expect(resolveBookUsfm('Hezekiah'), isNull);
    });
  });

  group('book and chapter navigation', () {
    final index = BibleIndex.bundled();

    test('next and previous step through a book', () {
      expect(
        index.next(const BibleLocation('JHN', 3)),
        const BibleLocation('JHN', 4),
      );
      expect(
        index.previous(const BibleLocation('JHN', 3)),
        const BibleLocation('JHN', 2),
      );
    });

    test('crossing book boundaries both ways', () {
      expect(
        index.next(const BibleLocation('JHN', 21)),
        const BibleLocation('ACT', 1),
      );
      expect(
        index.next(const BibleLocation('MAL', 4)),
        const BibleLocation('MAT', 1),
      );
      expect(
        index.previous(const BibleLocation('MAT', 1)),
        const BibleLocation('MAL', 4),
      );
      expect(
        index.previous(const BibleLocation('ACT', 1)),
        const BibleLocation('JHN', 21),
      );
      expect(
        index.next(const BibleLocation('OBA', 1)),
        const BibleLocation('JON', 1),
      );
    });

    test('a verse selection steps to whole chapters', () {
      expect(
        index.next(const BibleLocation('JHN', 3, verseStart: 16, verseEnd: 16)),
        const BibleLocation('JHN', 4),
      );
    });

    test('bounds: nothing before Genesis 1 or after Revelation 22', () {
      expect(index.previous(const BibleLocation('GEN', 1)), isNull);
      expect(index.next(const BibleLocation('REV', 22)), isNull);
      expect(index.previous(const BibleLocation('MAT', 1)), isNotNull);
      expect(_ntOnly().previous(const BibleLocation('MAT', 1)), isNull);
      expect(_ntOnly().next(const BibleLocation('PSA', 23)), isNull);
      expect(index.next(const BibleLocation('JHN', 99)), isNull);
    });

    test('labels', () {
      expect(index.label(const BibleLocation('1CO', 13)), '1 Corinthians 13');
      expect(
        index.label(
          const BibleLocation('JHN', 3, verseStart: 16, verseEnd: 16),
        ),
        'John 3:16',
      );
      expect(
        index.label(const BibleLocation('1CO', 13, verseStart: 4, verseEnd: 7)),
        '1 Corinthians 13:4-7',
      );
    });

    test('the bundled table covers the 66-book canon', () {
      expect(index.books, hasLength(66));
      expect(kBibleBooks['Psalms'], 150);
      expect(
        index.books.where((b) => b.testament == Testament.old),
        hasLength(39),
      );
    });
  });

  group('repository versions', () {
    test('offers only the translations the church approved', () async {
      final dio = Dio()
        ..httpClientAdapter = _JsonAdapter(
          () =>
              '{"data":['
              '{"id":111,"abbreviation":"NIV11","title":"NIV"},'
              '{"id":3034,"abbreviation":"BSB","title":"Berean"},'
              '{"id":1849,"abbreviation":"TPT","title":"Passion"},'
              '{"id":42,"abbreviation":"CPDV","title":"Catholic"},'
              '{"id":2692,"abbreviation":"NASB2020","title":"NASB"},'
              '{"id":100,"abbreviation":"NASB1995","title":"NASB 1995"},'
              '{"id":113,"abbreviation":"NIVUK11","title":"NIV UK"}]}',
        );
      final versions = await BibleRepository(
        dio: dio,
        appKey: 'test',
      ).getBibles();
      expect(versions.map((v) => v.id), [111, 2692]);
    });
  });

  group('repository books', () {
    test('parses books, chapters and verse counts once per version', () async {
      var calls = 0;
      final dio = Dio()
        ..httpClientAdapter = _JsonAdapter(() {
          calls++;
          return '{"data":['
              '{"id":"GEN","title":"Genesis","canon":"old_testament",'
              '"chapters":[{"id":"1","verses":[{"id":"1"},{"id":"31"}]},'
              '{"id":"2","verses":[{"id":"1"},{"id":"25"}]}]},'
              '{"id":"MAT","title":"Matthew","canon":"new_testament",'
              '"chapters":[{"id":"1","verses":[{"id":"25"}]}]}]}';
        });
      final repo = BibleRepository(dio: dio, appKey: 'test');

      final books = await repo.getBooks(206);
      expect(books.map((b) => b.usfm), ['GEN', 'MAT']);
      expect(books.first.chapters, [1, 2]);
      expect(books.first.verseCounts, {1: 31, 2: 25});
      expect(books.first.testament, Testament.old);
      expect(books.last.testament, Testament.newTestament);

      await repo.getBooks(206);
      expect(calls, 1, reason: 'cached per version');
    });

    test('books outside the 66-book canon are never shown, searched or '
        'stepped into', () async {
      // Like engWEBUS: the Apocrypha sits between Malachi and Matthew.
      final dio = Dio()
        ..httpClientAdapter = _JsonAdapter(
          () =>
              '{"data":['
              '{"id":"MAL","title":"Malachi","canon":"old_testament",'
              '"chapters":[{"id":"1"},{"id":"2"},{"id":"3"},{"id":"4"}]},'
              '{"id":"TOB","title":"Tobit","canon":"deuterocanon",'
              '"chapters":[{"id":"1","verses":[{"id":"22"}]}]},'
              '{"id":"JDT","title":"Judith","canon":"deuterocanon",'
              '"chapters":[{"id":"1"}]},'
              '{"id":"1MA","title":"1 Maccabees","canon":"deuterocanon",'
              '"chapters":[{"id":"1"}]},'
              '{"id":"SIR","title":"Sirach","canon":"deuterocanon",'
              '"chapters":[{"id":"1"}]},'
              '{"id":"PS2","title":"Psalm 151","canon":"deuterocanon",'
              '"chapters":[{"id":"1_1","verses":[]}]},'
              '{"id":"MAT","title":"Matthew","canon":"new_testament",'
              '"chapters":[{"id":"1"},{"id":"2"}]},'
              '{"id":"GEN","title":"Genesis","canon":"old_testament",'
              '"chapters":[{"id":"1"}]}]}',
        );
      final books = await BibleRepository(
        dio: dio,
        appKey: 'test',
      ).getBooks(206);
      expect(books.map((b) => b.usfm), [
        'GEN',
        'MAL',
        'MAT',
      ], reason: 'canon books only, in canonical order');

      final index = BibleIndex(books);
      expect(
        index.next(const BibleLocation('MAL', 4)),
        const BibleLocation('MAT', 1),
      );
      expect(
        index.previous(const BibleLocation('MAT', 1)),
        const BibleLocation('MAL', 4),
      );
      expect(parseBibleReference('Tobit 1', index), isA<ReferenceError>());
      expect(parseBibleReference('Sirach 1', index), isA<ReferenceError>());
      expect(parseReadingReferences('Judith 1; Malachi 4', index), [
        const BibleLocation('MAL', 4),
      ]);
    });
  });

  group('translation choice', () {
    test('defaults to NIV and is remembered across launches', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final controller = SelectedBibleController(prefs);
      expect(controller.state.id, 111);
      expect(controller.state.abbreviation, 'NIV');

      await controller.select(
        const BibleVersion(id: 2692, abbreviation: 'NASB2020', title: 'NASB'),
      );
      final relaunch = SelectedBibleController(prefs);
      expect(relaunch.state.id, 2692);
      expect(relaunch.state.abbreviation, 'NASB2020');
      expect(relaunch.state.title, 'NASB');
    });
  });

  group('reading references', () {
    final index = BibleIndex.bundled();

    test('a reading can name several passages; bare numbers keep the book', () {
      final parts = parseReadingReferences(
        'Romans 8:1-11; 9:1-5 and Psalm 23\nJohn 3',
        index,
      );
      expect(
        [for (final p in parts) index.label(p)],
        ['Romans 8:1-11', 'Romans 9:1-5', 'Psalms 23', 'John 3'],
      );
      expect(
        parseReadingReferences('Not a reference; also not', index),
        isEmpty,
      );
    });
  });

  group('reader', () {
    testWidgets('a translation footnote opens from its marker', (tester) async {
      await _pumpReader(tester);
      final verse = tester.widget<KVerse>(find.byType(KVerse).first);
      verse.parts.first.footnotes.single.onTap();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('bible-note-text')), findsOneWidget);
      expect(find.text('Or in the beginning'), findsOneWidget);
    });

    testWidgets('a reading with several passages offers each, opening its '
        'whole chapter', (tester) async {
      final r = await _pumpReader(
        tester,
        today: const DailyContent(
          reading: DailyEntry(
            title: 'Two passages',
            reference: 'Romans 8:1-11; Psalm 23',
          ),
        ),
      );
      expect(find.byKey(const Key('reading-parts')), findsOneWidget);
      expect(r.repo.passageRequests.last, endsWith('/ROM.8'));
      expect(_marked(tester), [for (var v = 1; v <= 11; v++) v]);
      expect(
        find.byKey(const Key('reading-mark-read')),
        findsNothing,
        reason: 'Mark as read ends the last passage',
      );
      await tester.tap(find.byKey(const Key('reading-part-1')));
      await tester.pumpAndSettle();
      expect(r.repo.passageRequests.last, endsWith('/PSA.23'));
      expect(find.byKey(const Key('reading-mark-read')), findsOneWidget);
    });

    testWidgets('opens on today\u2019s reading; Mark as read marks the day', (
      tester,
    ) async {
      final r = await _pumpReader(tester);

      expect(find.text('TODAY\u2019S READING'), findsOneWidget);
      expect(_title('John 3'), findsOneWidget);
      expect(find.byKey(const Key('bible-today')), findsNothing);
      expect(r.repo.passageRequests, ['111/JHN.3']);

      final mark = find.byKey(const Key('reading-mark-read'));
      await tester.ensureVisible(mark);
      await tester.tap(mark);
      await tester.pumpAndSettle();
      expect(r.container.read(readTodayProvider), isTrue);
      expect(find.text('Read today'), findsOneWidget);
    });

    testWidgets(
      'next/previous move chapters and Today\u2019s reading returns',
      (tester) async {
        await _pumpReader(tester);

        await _tapNext(tester);
        expect(_title('John 4'), findsOneWidget);
        expect(find.text('TODAY\u2019S READING'), findsNothing);
        expect(find.byKey(const Key('reading-mark-read')), findsNothing);

        await tester.tap(find.byKey(const Key('bible-today')));
        await tester.pumpAndSettle();
        expect(_title('John 3'), findsOneWidget);
        expect(find.text('TODAY\u2019S READING'), findsOneWidget);

        await tester.ensureVisible(find.byKey(const Key('bible-prev')));
        await tester.tap(find.byKey(const Key('bible-prev')));
        await tester.pumpAndSettle();
        expect(_title('John 2'), findsOneWidget);
      },
    );

    testWidgets('previous/next cross book boundaries', (tester) async {
      await _pumpReader(tester, today: _today('Malachi', 4));
      await _tapNext(tester);
      expect(_title('Matthew 1'), findsOneWidget);
    });

    testWidgets('the passage picker: book, then chapter', (tester) async {
      final r = await _pumpReader(tester);

      await _openPicker(tester);
      await _chooseBook(tester, 'ROM', 8);
      expect(find.byKey(const Key('bible-books')), findsNothing);
      expect(_title('Romans 8'), findsOneWidget);
      expect(r.repo.passageRequests.last, '111/ROM.8');
    });

    testWidgets('a one-chapter book opens straight away', (tester) async {
      await _pumpReader(tester);
      await _openPicker(tester);
      await _chooseBook(tester, 'JUD');
      expect(_title('Jude 1'), findsOneWidget);
    });

    testWidgets('search jumps to a verse and marks it', (tester) async {
      final r = await _pumpReader(tester, today: _today('Psalms', 23));
      expect(_marked(tester), isEmpty);

      await _search(tester, 'Jn 3:16');
      expect(_title('John 3'), findsOneWidget);
      expect(r.repo.passageRequests.last, '111/JHN.3');
      expect(_marked(tester), [16]);
      expect(find.byKey(const Key('bible-today')), findsOneWidget);
    });

    testWidgets('search and the picker work while the version\'s book list '
        'is still loading', (tester) async {
      await _pumpReader(tester, today: _today('Psalms', 23), booksHang: true);

      await _search(tester, 'John 3:16');
      expect(_title('John 3'), findsOneWidget);

      await _openPicker(tester);
      expect(find.byKey(const Key('bible-books')), findsOneWidget);
    });

    testWidgets('search explains an unknown book or chapter', (tester) async {
      await _pumpReader(tester);

      await _search(tester, 'Hezekiah 3');
      expect(
        find.text('We couldn\u2019t find a book called \u201cHezekiah\u201d.'),
        findsOneWidget,
      );
      await tester.enterText(
        find.byKey(const Key('bible-search-field')),
        'John 40',
      );
      await tester.tap(find.byKey(const Key('bible-search-go')));
      await tester.pumpAndSettle();
      expect(find.text('John has 21 chapters.'), findsOneWidget);
    });

    testWidgets('changing version reloads and is remembered', (tester) async {
      final r = await _pumpReader(tester);

      await _openPicker(tester);
      final version = find.byKey(const Key('bible-version-2692'));
      await tester.ensureVisible(version);
      await tester.tap(version);
      await tester.pumpAndSettle();

      expect(r.repo.passageRequests.last, '2692/JHN.3');
      expect(r.prefs.getInt(SelectedBibleController.idKey), 2692);
    });

    testWidgets('the layout toggle runs verses into paragraphs and is '
        'remembered', (tester) async {
      final r = await _pumpReader(tester);
      expect(find.byType(KVerse), findsNWidgets(36));

      await tester.tap(find.byKey(const Key('reader-layout-paragraphs')));
      await tester.pumpAndSettle();
      expect(find.byType(KVerse), findsOneWidget);
      expect(r.container.read(readerLayoutProvider), KReaderLayout.paragraphs);
    });

    testWidgets('offline shows Retry, and Retry loads the chapter', (
      tester,
    ) async {
      final r = await _pumpReader(tester);
      r.repo.offline = true;
      await _tapNext(tester);
      expect(find.text('Retry'), findsOneWidget);

      r.repo.offline = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('bible-text')), findsOneWidget);
      expect(r.repo.passageRequests.last, '111/JHN.4');
    });

    testWidgets('no reading today offers the picker', (tester) async {
      await _pumpReader(tester, nothingToday: true);
      expect(find.text('No reading today'), findsOneWidget);
      await tester.tap(find.text('Choose a passage'));
      await tester.pumpAndSettle();
      // Nothing open yet: the picker starts on the Old Testament.
      await _chooseBook(tester, 'PSA', 23);
      expect(_title('Psalms 23'), findsOneWidget);
    });

    testWidgets('a reading reference that does not parse shows the Studio '
        'text', (tester) async {
      await _pumpReader(
        tester,
        today: const DailyContent(
          reading: DailyEntry(
            title: 'Grace upon grace',
            reference: 'Not a passage',
            body: 'Read slowly today.',
          ),
        ),
      );
      expect(find.byKey(const Key('reading-today-text')), findsOneWidget);
      expect(find.text('Read slowly today.'), findsOneWidget);
    });

    testWidgets('a passage missing from the version offers another version', (
      tester,
    ) async {
      final r = await _pumpReader(
        tester,
        today: _today('Psalms', 23),
        missing: {'111/PSA.23'},
      );
      expect(find.text('This passage isn\u2019t available'), findsOneWidget);

      await tester.tap(find.byKey(const Key('bible-change-version')));
      await tester.pumpAndSettle();
      final version = find.byKey(const Key('bible-version-2692'));
      await tester.ensureVisible(version);
      await tester.tap(version);
      await tester.pumpAndSettle();
      expect(r.repo.passageRequests.last, '2692/PSA.23');
    });

    testWidgets('a verse preached from carries the marker, and its sheet '
        'lists the message', (tester) async {
      await _pumpReader(tester);
      expect(
        [
          for (final p in _parts(tester))
            if (p.related) p.number,
        ],
        [16],
      );

      await _tapVerse(tester, 16);
      expect(find.byKey(const Key('verse-related-m1')), findsOneWidget);
    });

    testWidgets('highlighting a verse tints it and lists it', (tester) async {
      final r = await _pumpReader(tester);
      await _tapVerse(tester, 3);
      await tester.tap(find.byKey(const Key('verse-highlight-1')));
      await tester.pumpAndSettle();

      final highlights = r.container.read(verseHighlightsProvider);
      expect(highlights.single.ref, const VerseRef('JHN', 3, 3));
      expect(highlights.single.version, 'NIV');
      expect(_parts(tester).firstWhere((p) => p.number == 3).highlight, 1);
    });

    testWidgets('opening a chapter is remembered for Continue reading', (
      tester,
    ) async {
      final r = await _pumpReader(
        tester,
        location: const BibleLocation('ROM', 8),
      );
      expect(_title('Romans 8'), findsOneWidget);
      expect(
        r.container.read(lastReadProvider)?.location,
        const BibleLocation('ROM', 8),
      );
    });
  });

  group('routes', () {
    testWidgets('/reading lands on today\u2019s reading in the Bible tab', (
      tester,
    ) async {
      final (router, _) = await _pumpRoutes(tester, open: '/reading');
      expect(
        router.routerDelegate.currentConfiguration.uri.path,
        kTodayReadingPath,
      );
      expect(_title('John 3'), findsOneWidget);
    });

    testWidgets('a daily reading push lands on today\u2019s reading in the '
        'Bible tab, not over Home', (tester) async {
      final (router, _) = await _pumpRoutes(tester, open: '/bible');
      openNotificationTarget(
        router,
        notificationTargetFor({'type': 'reading'}),
      );
      await tester.pumpAndSettle();
      final config = router.routerDelegate.currentConfiguration;
      expect(config.uri.path, kTodayReadingPath);
      expect(config.matches.first.matchedLocation, '/bible');
      expect(_title('John 3'), findsOneWidget);
    });

    testWidgets('/highlights lands on Highlights', (tester) async {
      await _pumpRoutes(tester, open: '/highlights');
      expect(find.byKey(const Key('highlights-empty')), findsOneWidget);
    });

    testWidgets('a reader path opens the chapter at its verse', (tester) async {
      final (_, repo) = await _pumpRoutes(
        tester,
        open: '/bible/JHN/3?verse=16',
      );
      expect(_title('John 3'), findsOneWidget);
      expect(_marked(tester), [16]);
      expect(repo.passageRequests, ['111/JHN.3']);
    });

    testWidgets('a chapter outside the canon opens the landing screen', (
      tester,
    ) async {
      await _pumpRoutes(tester, open: '/bible/JHN/40');
      expect(find.byKey(const Key('bible-landing-search')), findsOneWidget);
    });

    testWidgets('the landing screen searches into the reader and back', (
      tester,
    ) async {
      await _pumpRoutes(tester, open: '/bible');
      await tester.enterText(
        find.byKey(const Key('bible-landing-search')),
        'Romans 8:28',
      );
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(_title('Romans 8'), findsOneWidget);
      expect(_marked(tester), [28]);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('bible-landing-search')), findsOneWidget);
      expect(find.byKey(const Key('bible-continue')), findsOneWidget);
    });

    testWidgets('the landing screen explains a reference it cannot find', (
      tester,
    ) async {
      await _pumpRoutes(tester, open: '/bible');
      await tester.enterText(
        find.byKey(const Key('bible-landing-search')),
        'Hezekiah 3',
      );
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('bible-search-error')), findsOneWidget);
    });

    testWidgets('Daily reading opens today\u2019s reading', (tester) async {
      await _pumpRoutes(tester, open: '/bible');
      expect(find.text('Not read'), findsOneWidget);
      await tester.tap(find.byKey(const Key('bible-daily-reading')));
      await tester.pumpAndSettle();
      expect(find.text('TODAY\u2019S READING'), findsOneWidget);
    });

    testWidgets('My notes opens the note\u2019s verse with its sheet', (
      tester,
    ) async {
      await _pumpRoutes(tester, open: '/bible');
      final container = ProviderScope.containerOf(
        tester.element(find.byKey(const Key('bible-landing-search'))),
      );
      container
          .read(verseMarksRepositoryProvider)
          .saveNote(
            const VerseRef('JHN', 3, 16),
            'Whoever believes',
            text: 'For God so loved the world',
            version: 'NIV',
          );
      await tester.pumpAndSettle();
      expect(find.text('1 note'), findsOneWidget);

      await tester.tap(find.byKey(const Key('bible-notes')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('verse-note-JHN.3.16')));
      await tester.pumpAndSettle();
      expect(_title('John 3'), findsOneWidget);
      expect(find.byKey(const Key('verse-note-field')), findsOneWidget);
    });
  });
}

class _JsonAdapter implements HttpClientAdapter {
  _JsonAdapter(this.body);

  final String Function() body;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    body(),
    200,
    headers: {
      Headers.contentTypeHeader: ['application/json'],
    },
  );

  @override
  void close({bool force = false}) {}
}
