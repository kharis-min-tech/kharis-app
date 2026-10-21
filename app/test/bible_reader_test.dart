import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kharis_app/core/constants/bible_books.dart';
import 'package:kharis_app/features/home/data/bible_reference.dart';
import 'package:kharis_app/features/home/data/bible_repository.dart';
import 'package:kharis_app/features/home/data/daily_content_repository.dart';
import 'package:kharis_app/features/home/presentation/screens/bible_books_screen.dart';
import 'package:kharis_app/features/home/presentation/screens/reading_screen.dart';
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
    BibleVersion(id: 3034, abbreviation: 'BSB', title: 'Berean Standard'),
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

Future<(_FakeBibleRepository, SharedPreferences)> _pumpReader(
  WidgetTester tester, {
  DailyContent? today,
  bool nothingToday = false,
  Map<String, Object> prefs = const {},
  bool booksHang = false,
  Set<String> missing = const {},
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final sharedPrefs = await SharedPreferences.getInstance();
  final repo = _FakeBibleRepository()
    ..booksHang = booksHang
    ..missing.addAll(missing);
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPrefs),
        bibleRepositoryProvider.overrideWithValue(repo),
        dailyContentProvider.overrideWith(
          (ref) =>
              Stream.value(nothingToday ? null : today ?? _today('John', 3)),
        ),
      ],
      child: const MaterialApp(home: ReadingScreen()),
    ),
  );
  await tester.pumpAndSettle();
  return (repo, sharedPrefs);
}

/// The reader's `/reading` and `/bible` routes, pushed over a More stub (or
/// opened alone, as a cold-start push tap does), so Close and back can be
/// checked against what lies underneath.
Future<(GoRouter, _FakeBibleRepository)> _pumpRoutes(
  WidgetTester tester, {
  required String open,
  bool overMore = true,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final repo = _FakeBibleRepository();
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  Widget stub(String path) => Scaffold(body: Text('route:$path'));
  final router = GoRouter(
    initialLocation: overMore ? '/more' : open,
    routes: [
      GoRoute(path: '/more', builder: (_, _) => stub('/more')),
      GoRoute(path: '/home', builder: (_, _) => stub('/home')),
      GoRoute(path: '/reading', builder: (_, _) => const ReadingScreen()),
      GoRoute(
        path: '/bible',
        builder: (_, _) => const ReadingScreen(browse: true),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        bibleRepositoryProvider.overrideWithValue(repo),
        dailyContentProvider.overrideWith(
          (ref) => Stream.value(_today('John', 3)),
        ),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  if (overMore) {
    unawaited(router.push(open));
    await tester.pumpAndSettle();
  }
  return (router, repo);
}

/// Book list -> [book] -> chapter grid cell [chapter] (when it has one).
Future<void> _chooseBook(
  WidgetTester tester,
  String book, [
  int? chapter,
]) async {
  await tester.ensureVisible(find.text(book));
  await tester.tap(find.text(book));
  await tester.pumpAndSettle();
  if (chapter != null) {
    await tester.tap(find.byKey(Key('bible-chapter-$chapter')));
    await tester.pumpAndSettle();
  }
}

Finder _header(String label) => find.byWidgetPredicate(
  (w) => w is RichText && w.text.toPlainText().startsWith('$label\u00A0'),
  description: 'reader header "$label"',
);

bool _hasHighlight(WidgetTester tester) {
  for (final element in find.byType(RichText).evaluate()) {
    var lit = false;
    (element.widget as RichText).text.visitChildren((span) {
      if (span is TextSpan && span.style?.backgroundColor != null) lit = true;
      return !lit;
    });
    if (lit) return true;
  }
  return false;
}

Future<void> _search(WidgetTester tester, String input) async {
  await tester.tap(find.byKey(const Key('bible-search')));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const Key('bible-search-field')), input);
  await tester.tap(find.byKey(const Key('bible-search-go')));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

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
              '{"id":"PS2","title":"Psalm 151","canon":"deuterocanon",'
              '"chapters":[{"id":"1_1","verses":[]}]},'
              '{"id":"TOB","title":"Tobit","canon":"deuterocanon",'
              '"chapters":[{"id":"1","verses":[{"id":"22"}]}]},'
              '{"id":"MAT","title":"Matthew","canon":"new_testament",'
              '"chapters":[{"id":"1","verses":[{"id":"25"}]}]}]}';
        });
      final repo = BibleRepository(dio: dio, appKey: 'test');

      final books = await repo.getBooks(206);
      expect(books.map((b) => b.usfm), ['GEN', 'TOB', 'MAT']);
      expect(books.first.chapters, [1, 2]);
      expect(books.first.verseCounts, {1: 31, 2: 25});
      expect(books[1].testament, Testament.other);
      expect(books.last.testament, Testament.newTestament);

      await repo.getBooks(206);
      expect(calls, 1, reason: 'cached per version');

      expect(
        parseBibleReference('Tobit 1', BibleIndex(books)),
        isA<ReferenceFound>(),
        reason: 'extra books are searchable by their title',
      );
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
        const BibleVersion(id: 3034, abbreviation: 'BSB', title: 'Berean'),
      );
      final relaunch = SelectedBibleController(prefs);
      expect(relaunch.state.id, 3034);
      expect(relaunch.state.abbreviation, 'BSB');
      expect(relaunch.state.title, 'Berean');
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
      await tester.tap(find.byKey(const Key('bible-note-a')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('bible-note-text')), findsOneWidget);
      expect(find.text('Or in the beginning'), findsOneWidget);
    });

    testWidgets('a reading with several passages offers each, opening its '
        'whole chapter', (tester) async {
      final (repo, _) = await _pumpReader(
        tester,
        today: const DailyContent(
          reading: DailyEntry(
            title: 'Two passages',
            reference: 'Romans 8:1-11; Psalm 23',
          ),
        ),
      );
      expect(find.byKey(const Key('reading-parts')), findsOneWidget);
      expect(repo.passageRequests.last, endsWith('/ROM.8'));
      await tester.tap(find.byKey(const Key('reading-part-1')));
      await tester.pumpAndSettle();
      expect(repo.passageRequests.last, endsWith('/PSA.23'));
    });

    testWidgets('opens on today\u2019s reading', (tester) async {
      final (repo, _) = await _pumpReader(tester);

      expect(find.text('TODAY\u2019S READING'), findsOneWidget);
      expect(_header('John 3'), findsOneWidget);
      expect(find.text('Mark as read'), findsOneWidget);
      expect(find.byKey(const Key('bible-today')), findsNothing);
      expect(repo.passageRequests, ['111/JHN.3']);
    });

    testWidgets(
      'next/previous move chapters and Today\u2019s reading returns',
      (tester) async {
        await _pumpReader(tester);

        await tester.ensureVisible(find.byKey(const Key('bible-next')));
        await tester.tap(find.byKey(const Key('bible-next')));
        await tester.pumpAndSettle();
        expect(_header('John 4'), findsOneWidget);
        expect(find.text('TODAY\u2019S READING'), findsNothing);
        expect(find.text('Bible'), findsOneWidget, reason: 'app bar title');
        expect(find.text('Mark as read'), findsNothing);

        await tester.tap(find.byKey(const Key('bible-today')));
        await tester.pumpAndSettle();
        expect(_header('John 3'), findsOneWidget);
        expect(find.text('TODAY\u2019S READING'), findsOneWidget);

        await tester.ensureVisible(find.byKey(const Key('bible-prev')));
        await tester.tap(find.byKey(const Key('bible-prev')));
        await tester.pumpAndSettle();
        expect(_header('John 2'), findsOneWidget);
      },
    );

    testWidgets('previous/next cross book boundaries', (tester) async {
      await _pumpReader(tester, today: _today('Malachi', 4));

      expect(find.text('Matthew 1'), findsOneWidget, reason: 'next label');
      await tester.ensureVisible(find.byKey(const Key('bible-next')));
      await tester.tap(find.byKey(const Key('bible-next')));
      await tester.pumpAndSettle();
      expect(_header('Matthew 1'), findsOneWidget);
      expect(find.text('Malachi 4'), findsOneWidget, reason: 'previous label');
    });

    testWidgets('book list -> chapter grid -> chapter', (tester) async {
      final (repo, _) = await _pumpReader(tester);

      await tester.tap(find.byKey(const Key('bible-reference')));
      await tester.pumpAndSettle();
      expect(find.byType(BibleBooksScreen), findsOneWidget);
      expect(find.text('OLD TESTAMENT'), findsOneWidget);
      expect(find.text('NEW TESTAMENT'), findsOneWidget);

      await tester.ensureVisible(find.text('Romans'));
      await tester.tap(find.text('Romans'));
      await tester.pumpAndSettle();
      expect(find.byType(BibleChaptersScreen), findsOneWidget);

      await tester.tap(find.byKey(const Key('bible-chapter-8')));
      await tester.pumpAndSettle();
      expect(find.byType(BibleBooksScreen), findsNothing);
      expect(_header('Romans 8'), findsOneWidget);
      expect(repo.passageRequests.last, '111/ROM.8');
    });

    testWidgets('backing out of the book list keeps the chapter', (
      tester,
    ) async {
      await _pumpReader(tester);
      await tester.tap(find.byKey(const Key('bible-reference')));
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(_header('John 3'), findsOneWidget);
      expect(find.text('TODAY\u2019S READING'), findsOneWidget);
    });

    testWidgets('search jumps to a verse and highlights it', (tester) async {
      final (repo, _) = await _pumpReader(tester, today: _today('Psalms', 23));
      expect(_hasHighlight(tester), isFalse);

      await _search(tester, 'Jn 3:16');
      expect(_header('John 3:16'), findsOneWidget);
      expect(repo.passageRequests.last, '111/JHN.3');
      expect(_hasHighlight(tester), isTrue);
      expect(find.byKey(const Key('bible-today')), findsOneWidget);
    });

    testWidgets('search and the book list work while the version\'s book '
        'list is still loading', (tester) async {
      await _pumpReader(tester, today: _today('Psalms', 23), booksHang: true);

      await _search(tester, 'John 3:16');
      expect(_header('John 3:16'), findsOneWidget);

      await tester.tap(_header('John 3:16'));
      await tester.pumpAndSettle();
      expect(find.byType(BibleBooksScreen), findsOneWidget);
      expect(find.text('Genesis'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
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
      expect(_header('John 3'), findsOneWidget, reason: 'still on today');
    });

    testWidgets('changing translation reloads and is remembered', (
      tester,
    ) async {
      final (repo, prefs) = await _pumpReader(tester);

      await tester.tap(find.text('NIV'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('bible-version-3034')));
      await tester.pumpAndSettle();

      expect(repo.passageRequests.last, '3034/JHN.3');
      expect(find.text('BSB'), findsOneWidget);
      expect(prefs.getInt(SelectedBibleController.idKey), 3034);
    });

    testWidgets('a remembered translation is used on open', (tester) async {
      final (repo, _) = await _pumpReader(
        tester,
        prefs: {
          SelectedBibleController.idKey: 3034,
          SelectedBibleController.abbreviationKey: 'BSB',
          SelectedBibleController.titleKey: 'Berean Standard',
        },
      );
      expect(repo.passageRequests, ['3034/JHN.3']);
    });

    testWidgets('offline shows Retry, and Retry loads the chapter', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = _FakeBibleRepository()..offline = true;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            bibleRepositoryProvider.overrideWithValue(repo),
            dailyContentProvider.overrideWith(
              (ref) => Stream.value(_today('John', 3)),
            ),
          ],
          child: const MaterialApp(home: ReadingScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Couldn\u2019t load the passage'), findsOneWidget);
      expect(_header('John 3'), findsOneWidget, reason: 'header still there');

      repo.offline = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('Couldn\u2019t load the passage'), findsNothing);
      expect(find.textContaining('Verse 1 of JHN.3'), findsOneWidget);
    });

    testWidgets('searching an overlong chapter explains it and stays put', (
      tester,
    ) async {
      await _pumpReader(tester);
      await _search(tester, 'John 99999999999999999999');
      expect(tester.takeException(), isNull);
      expect(find.text('John has 21 chapters.'), findsOneWidget);
      expect(_header('John 3'), findsOneWidget);
    });

    for (final (book, chapter, missingStep, presentStep) in const [
      ('Genesis', 1, 'bible-prev', 'bible-next'),
      ('Revelation', 22, 'bible-next', 'bible-prev'),
    ]) {
      testWidgets('$book $chapter is an end of the Bible: only one step', (
        tester,
      ) async {
        await _pumpReader(tester, today: _today(book, chapter));
        expect(_header('$book $chapter'), findsOneWidget);
        expect(find.byKey(Key(missingStep)), findsNothing);
        expect(find.byKey(Key(presentStep)), findsOneWidget);
      });
    }

    testWidgets('no reading today offers Browse the Bible, and it works', (
      tester,
    ) async {
      final (repo, _) = await _pumpReader(tester, nothingToday: true);
      expect(find.text('No reading today'), findsOneWidget);
      expect(repo.passageRequests, isEmpty);

      await tester.tap(find.text('Browse the Bible'));
      await tester.pumpAndSettle();
      expect(find.byType(BibleBooksScreen), findsOneWidget);
      await _chooseBook(tester, 'Romans', 8);
      expect(_header('Romans 8'), findsOneWidget);
      expect(repo.passageRequests, ['111/ROM.8']);
    });

    testWidgets('a reading reference that does not parse shows the Studio '
        'text and the way into the Bible', (tester) async {
      await _pumpReader(
        tester,
        today: const DailyContent(
          reading: DailyEntry(
            title: 'Faith at work',
            reference: 'The Sermon on the Mount',
          ),
        ),
      );
      expect(find.byKey(const Key('reading-today-text')), findsOneWidget);
      expect(find.text('Faith at work'), findsOneWidget);

      await tester.tap(find.text('Browse the Bible'));
      await tester.pumpAndSettle();
      await _chooseBook(tester, 'Jude');
      expect(find.byType(BibleChaptersScreen), findsNothing);
      expect(_header('Jude 1'), findsOneWidget, reason: 'one chapter: no grid');
    });

    testWidgets('a passage missing from the version offers another version', (
      tester,
    ) async {
      final (repo, _) = await _pumpReader(
        tester,
        today: _today('Psalms', 23),
        missing: {'111/PSA.23'},
      );
      expect(find.text('This passage isn\u2019t available'), findsOneWidget);

      await tester.tap(find.text('Change version'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('bible-version-3034')));
      await tester.pumpAndSettle();
      expect(repo.passageRequests.last, '3034/PSA.23');
      expect(find.textContaining('Verse 1 of PSA.23 in BSB'), findsOneWidget);
    });

    testWidgets('switching version while browsing stays on that chapter', (
      tester,
    ) async {
      final (repo, _) = await _pumpReader(tester);
      await tester.ensureVisible(find.byKey(const Key('bible-next')));
      await tester.tap(find.byKey(const Key('bible-next')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('NIV'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('bible-version-3034')));
      await tester.pumpAndSettle();
      expect(repo.passageRequests.last, '3034/JHN.4');
      expect(_header('John 4'), findsOneWidget);
      expect(find.byKey(const Key('bible-today')), findsOneWidget);
    });
  });

  group('routes', () {
    testWidgets('More > Bible opens on the book list; Close and system back '
        'return straight to More', (tester) async {
      final (router, repo) = await _pumpRoutes(tester, open: '/bible');
      expect(find.byType(BibleBooksScreen), findsOneWidget);
      expect(find.text('TODAY\u2019S READING'), findsNothing);
      expect(repo.passageRequests, isEmpty);

      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(find.text('route:/more'), findsOneWidget);
      expect(find.byType(ReadingScreen), findsNothing);

      unawaited(router.push('/bible'));
      await tester.pumpAndSettle();
      // Into a book's chapters and back out keeps the list.
      await _chooseBook(tester, 'Romans');
      expect(find.byType(BibleChaptersScreen), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(BibleBooksScreen), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('route:/more'), findsOneWidget);
      expect(find.byType(ReadingScreen), findsNothing);
    });

    testWidgets('a chapter chosen from More > Bible offers today\u2019s '
        'reading, and Close returns to More', (tester) async {
      final (_, repo) = await _pumpRoutes(tester, open: '/bible');
      await _chooseBook(tester, 'Romans', 8);
      expect(find.byType(BibleBooksScreen), findsNothing);
      expect(_header('Romans 8'), findsOneWidget);
      expect(repo.passageRequests, ['111/ROM.8']);

      await tester.tap(find.byKey(const Key('bible-today')));
      await tester.pumpAndSettle();
      expect(_header('John 3'), findsOneWidget);
      expect(find.text('TODAY\u2019S READING'), findsOneWidget);

      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(find.text('route:/more'), findsOneWidget);
    });

    testWidgets('Close with nothing underneath (a cold-start push tap) goes '
        'Home', (tester) async {
      await _pumpRoutes(tester, open: '/reading', overMore: false);
      expect(_header('John 3'), findsOneWidget);
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(find.text('route:/home'), findsOneWidget);
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
