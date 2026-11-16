import 'package:go_router/go_router.dart';

import 'package:kharis_app/core/constants/bible_books.dart';
import 'package:kharis_app/features/bible/presentation/screens/bible_screen.dart';
import 'package:kharis_app/features/bible/presentation/screens/highlights_screen.dart';
import 'package:kharis_app/features/bible/presentation/screens/reading_screen.dart';
import 'package:kharis_app/features/bible/presentation/screens/verse_notes_screen.dart';
import 'package:kharis_app/features/home/data/bible_repository.dart';

/// Today's reading in the reader.
const String kTodayReadingPath = '/bible/reading';

/// The member's verse highlights.
const String kHighlightsPath = '/bible/highlights';

/// The member's verse notes.
const String kVerseNotesPath = '/bible/notes';

/// The reader on [location]: `/bible/JHN/3`, with `?verse=16` (and
/// `&to=18`) when it names verses and `&note=1` to open the verse sheet.
String bibleReaderPath(BibleLocation location, {bool openVerse = false}) {
  final start = location.verseStart;
  final end = location.verseEnd;
  final query = [
    if (start != null) 'verse=$start',
    if (start != null && end != null && end != start) 'to=$end',
    if (openVerse && start != null) 'note=1',
  ];
  final path = '/bible/${location.usfm}/${location.chapter}';
  return query.isEmpty ? path : '$path?${query.join('&')}';
}

/// The chapter a reader route names, or null when it is not a chapter of the
/// 66-book canon.
BibleLocation? _locationOf(GoRouterState state) {
  final book = state.pathParameters['book']?.toUpperCase();
  final chapter = int.tryParse(state.pathParameters['chapter'] ?? '');
  final canon = kCanonBooks.where((b) => b.usfm == book).firstOrNull;
  if (canon == null || chapter == null || chapter < 1) return null;
  if (chapter > canon.chapters) return null;
  final query = state.uri.queryParameters;
  final start = int.tryParse(query['verse'] ?? '');
  final end = int.tryParse(query['to'] ?? '');
  if (start == null || start < 1) return BibleLocation(canon.usfm, chapter);
  return BibleLocation(
    canon.usfm,
    chapter,
    verseStart: start,
    verseEnd: end != null && end >= start ? end : start,
  );
}

/// The Bible tab's route: the landing screen, with today's reading, the
/// lists and the reader pushed on top inside the tab, so the nav stays and
/// swipe back returns to the landing screen.
final GoRoute bibleTabRoute = GoRoute(
  path: '/bible',
  builder: (context, state) => const BibleScreen(),
  routes: [
    GoRoute(
      path: 'reading',
      builder: (context, state) => const ReadingScreen(),
    ),
    GoRoute(
      path: 'highlights',
      builder: (context, state) => const HighlightsScreen(),
    ),
    GoRoute(
      path: 'notes',
      builder: (context, state) => const VerseNotesScreen(),
    ),
    GoRoute(
      path: ':book/:chapter',
      // A chapter outside the canon opens the Bible tab instead.
      redirect: (context, state) =>
          _locationOf(state) == null ? '/bible' : null,
      builder: (context, state) => ReadingScreen(
        location: _locationOf(state),
        openVerse: state.uri.queryParameters['note'] == '1',
      ),
    ),
  ],
);

/// Old and short paths kept for pushes, deep links and saved links: they
/// land on the Bible tab with the screen on top.
final List<GoRoute> bibleRedirectRoutes = [
  GoRoute(path: '/reading', redirect: (context, state) => kTodayReadingPath),
  GoRoute(path: '/highlights', redirect: (context, state) => kHighlightsPath),
];
