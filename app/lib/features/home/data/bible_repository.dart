import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:kharis_app/core/constants/bible_books.dart';
import 'package:kharis_app/features/home/data/bundled_bible.dart';

/// Fetches Bible passage text and version metadata from the YouVersion
/// Platform API.
///
/// The app key is injected at build time via --dart-define (never committed):
///   flutter build web --dart-define-from-file=env.json
/// License set (June 2026): 20 English versions incl. NIV11 (111),
/// AMP (1588), NASB2020 (2692), BSB (3034), ASV (12).
///
/// The public-domain KJV ([BundledBible.kjv]) ships with the app and is
/// served from the bundle, offline, unless YouVersion lists it for the key.
class BibleRepository {
  /// [appKey] defaults to the build-time `YOUVERSION_API_KEY` define;
  /// [bundled] to [BundledBible.kjv].
  BibleRepository({Dio? dio, String? appKey, BundledBible? bundled})
    : _dio = dio ?? Dio(_dioOptions),
      _key = appKey ?? _appKey,
      _bundled = bundled ?? BundledBible.kjv;

  /// Bounds every request so a stalled connection ends in the reader's
  /// error view with Retry instead of a spinner that never resolves.
  static final BaseOptions _dioOptions = BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 20),
  );

  static const _base = 'https://api.youversion.com/v1';
  static const _appKey = String.fromEnvironment('YOUVERSION_API_KEY');

  final String _key;

  /// NIV 2011 - the default reading translation.
  static const defaultBibleId = 111;
  static const defaultBibleAbbreviation = 'NIV';

  /// Translations the church has approved (26 Oct 2026), by YouVersion id.
  /// Only these are ever offered. KJV (1) is bundled with the app (public
  /// domain), so it is always offered; YouVersion serves it instead if it
  /// ever licenses it. Ids not yet licensed for this app key (NKJV 114,
  /// ESV 59, AMPC 8, MSG 97, RSV 2020) appear on their own once YouVersion
  /// licenses them.
  static const approvedBibleIds = <int>{
    111, // NIV 2011
    12, // ASV
    1588, // AMP
    2692, // NASB 2020
    1, // KJV
    114, // NKJV
    59, // ESV
    8, // AMPC
    97, // MSG
    2020, // RSV
  };
  final Dio _dio;
  final BundledBible _bundled;

  /// Whether the last versions list from YouVersion included the bundled
  /// version's id. Until a list arrives the bundle serves it (offline first).
  bool _bundledOnYouVersion = false;

  final _passageCache = <String, BiblePassage>{};
  final _booksCache = <int, List<BibleBook>>{};
  List<BibleVersion>? _biblesCache;

  bool _servesBundled(int bibleId) =>
      bibleId == _bundled.id && !_bundledOnYouVersion;

  Options get _options {
    if (_key.isEmpty) {
      throw StateError(
        'YOUVERSION_API_KEY missing. Build with '
        '--dart-define-from-file=env.json (see env.example.json).',
      );
    }
    return Options(
      headers: {'x-yvp-app-key': _key, 'Accept': 'application/json'},
    );
  }

  /// Lists the church-approved Bible versions licensed for this app key,
  /// plus the bundled KJV when YouVersion does not list it.
  Future<List<BibleVersion>> getBibles() async {
    if (_biblesCache != null) return _biblesCache!;
    final response = await _dio.get<Map<String, dynamic>>(
      '$_base/bibles',
      queryParameters: {'language_ranges[]': 'en', 'page_size': 99},
      options: _options,
    );
    final data = (response.data?['data'] as List? ?? const [])
        .cast<Map<String, dynamic>>();
    // An empty answer (an error-shaped 200) is a failure, not a fact to keep
    // for the session: Retry must ask again.
    if (data.isEmpty) throw StateError('No Bible versions returned');
    final versions = [
      for (final b in data)
        if (approvedBibleIds.contains((b['id'] as num).toInt()))
          BibleVersion(
            id: (b['id'] as num).toInt(),
            abbreviation:
                (b['localized_abbreviation'] ?? b['abbreviation'] ?? '?')
                    as String,
            title: (b['localized_title'] ?? b['title'] ?? '') as String,
          ),
    ];
    final onYouVersion = versions.any((v) => v.id == _bundled.id);
    if (onYouVersion != _bundledOnYouVersion) {
      // The source for that id changed: drop what the other one served.
      _booksCache.remove(_bundled.id);
      _passageCache.removeWhere((key, _) => key.startsWith('${_bundled.id}/'));
      _bundledOnYouVersion = onYouVersion;
    }
    _biblesCache = [
      ...versions,
      if (!onYouVersion)
        BibleVersion(
          id: _bundled.id,
          abbreviation: _bundled.abbreviation,
          title: _bundled.title,
        ),
    ];
    return _biblesCache!;
  }

  /// Books of [bibleId] that belong to the 66-book Protestant canon, in
  /// canonical order, with each book's chapters and verse counts. Versions
  /// differ (NT-only, partial OT), so navigation and reference search use
  /// this rather than a fixed table. Books outside the canon (deuterocanon,
  /// apocrypha) are dropped: the app never shows them.
  Future<List<BibleBook>> getBooks(int bibleId) async {
    final cached = _booksCache[bibleId];
    if (cached != null) return cached;
    if (_servesBundled(bibleId)) {
      return _booksCache[bibleId] = await _bundledBooks();
    }

    final response = await _withRetry(
      () => _dio.get<Map<String, dynamic>>(
        '$_base/bibles/$bibleId/books',
        options: _options,
      ),
    );
    final data = (response.data?['data'] as List? ?? const [])
        .cast<Map<String, dynamic>>();
    final books = <BibleBook>[];
    for (final b in data) {
      final canon = _canonByUsfm[b['id']];
      if (canon == null) continue;
      final chapters = <int>[];
      final verseCounts = <int, int>{};
      for (final c
          in (b['chapters'] as List? ?? const [])
              .cast<Map<String, dynamic>>()) {
        // Skips non-numeric ids such as Psalm 151's "1_1".
        final number = int.tryParse('${c['id']}');
        if (number == null) continue;
        chapters.add(number);
        var lastVerse = 0;
        for (final v
            in (c['verses'] as List? ?? const [])
                .cast<Map<String, dynamic>>()) {
          final n = int.tryParse('${v['id']}');
          if (n != null && n > lastVerse) lastVerse = n;
        }
        if (lastVerse > 0) verseCounts[number] = lastVerse;
      }
      if (chapters.isEmpty) continue;
      books.add(
        BibleBook(
          usfm: canon.book.usfm,
          title: (b['title'] ?? canon.book.name) as String,
          testament: canon.book.testament,
          chapters: chapters,
          verseCounts: verseCounts,
        ),
      );
    }
    books.sort(
      (a, b) =>
          _canonByUsfm[a.usfm]!.order.compareTo(_canonByUsfm[b.usfm]!.order),
    );
    if (books.isEmpty) throw StateError('No books for Bible $bibleId');
    return _booksCache[bibleId] = books;
  }

  /// Fetches a passage (chapter or verse) by USFM id, e.g. 'PSA.23',
  /// parsed into structured blocks with verse numbers.
  Future<BiblePassage> getPassage(
    String usfmId, {
    int bibleId = defaultBibleId,
    String abbreviation = defaultBibleAbbreviation,
  }) async {
    final cacheKey = '$bibleId/$usfmId';
    final cached = _passageCache[cacheKey];
    if (cached != null) return cached;
    if (_servesBundled(bibleId)) {
      return _passageCache[cacheKey] = await _bundledPassage(usfmId);
    }

    final response = await _withRetry(
      () => _dio.get<Map<String, dynamic>>(
        '$_base/bibles/$bibleId/passages/$usfmId',
        queryParameters: {
          'format': 'html',
          'include_headings': 'true',
          'include_notes': 'true',
        },
        options: _options,
      ),
    );

    final data = response.data ?? const {};
    final blocks = _parseHtml(data['content'] as String? ?? '');
    if (blocks.isEmpty) {
      throw StateError('Empty passage content for $usfmId');
    }
    final passage = BiblePassage(
      reference: data['reference'] as String? ?? usfmId,
      blocks: blocks,
      copyright: data['copyright'] as String?,
      bibleAbbreviation: abbreviation,
    );
    _passageCache[cacheKey] = passage;
    return passage;
  }

  /// One retry, after a short pause, for failures that never reached the
  /// server (dropped connection, DNS blip, timeout). A real answer such as a
  /// 404 for a chapter that does not exist is returned to the caller at once.
  static Future<T> _withRetry<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on DioException catch (e) {
      if (e.response != null) rethrow;
      await Future<void>.delayed(retryDelay);
      return request();
    }
  }

  /// Pause before the single transient retry. Tests shorten it.
  @visibleForTesting
  static Duration retryDelay = const Duration(milliseconds: 800);

  // ── Bundled version ─────────────────────────────────────────────────────────

  Future<List<BibleBook>> _bundledBooks() async {
    final text = await _bundled.load();
    return [
      for (final canon in kCanonBooks)
        if (text[canon.usfm] case final chapters?)
          BibleBook(
            usfm: canon.usfm,
            title: canon.name,
            testament: canon.testament,
            chapters: [for (var c = 1; c <= chapters.length; c++) c],
            verseCounts: {
              for (final (i, verses) in chapters.indexed) i + 1: verses.length,
            },
          ),
    ];
  }

  /// `JHN.3`, `JHN.3.16`, `JHN.3.16-18` or `JHN.3.16-JHN.3.18`, the passage
  /// ids the YouVersion passages endpoint takes.
  static final _passageIdRe = RegExp(
    r'^([1-3A-Z]{3})\.(\d+)(?:\.(\d+)(?:-(?:\1\.\2\.)?(\d+))?)?$',
  );

  /// One `p` block of numbered verse segments, shaped like a parsed
  /// YouVersion chapter. An id outside the text fails like the API's 404.
  Future<BiblePassage> _bundledPassage(String usfmId) async {
    final text = await _bundled.load();
    final m = _passageIdRe.firstMatch(usfmId);
    final canon = _canonByUsfm[m?[1]]?.book;
    final chapters = text[m?[1]];
    final chapter = int.parse(m?[2] ?? '0');
    if (m == null ||
        canon == null ||
        chapters == null ||
        chapter < 1 ||
        chapter > chapters.length) {
      throw StateError('No passage $usfmId in ${_bundled.abbreviation}');
    }
    final verses = chapters[chapter - 1];
    final first = int.tryParse(m[3] ?? '') ?? 1;
    final last =
        int.tryParse(m[4] ?? '') ?? (m[3] == null ? verses.length : first);
    if (first < 1 || last < first || last > verses.length) {
      throw StateError('No passage $usfmId in ${_bundled.abbreviation}');
    }
    final range = m[3] == null
        ? ''
        : first == last
        ? ':$first'
        : ':$first-$last';
    return BiblePassage(
      reference: '${canon.name} $chapter$range',
      blocks: [
        PassageBlock(
          styleClass: 'p',
          segments: [
            for (var v = first; v <= last; v++)
              PassageSegment(verse: v, text: verses[v - 1]),
          ],
        ),
      ],
      copyright: _bundled.copyright,
      bibleAbbreviation: _bundled.abbreviation,
    );
  }

  // ── HTML parsing ────────────────────────────────────────────────────────────
  //
  // The platform returns regular markup:
  //   <div class="q1"><span class="yv-v" v="1"></span>
  //   <span class="yv-vlbl">1</span>The Lord is my shepherd...</div>
  // Block classes: p/m prose, q1..q3 poetry indents, d superscription,
  // s/s1/s2 headings. Verse labels arrive as yv-vlbl spans.

  static final _blockRe = RegExp(
    r'<div class="([^"]*)">(.*?)</div>',
    dotAll: true,
  );
  static final _verseLabelRe = RegExp(r'<span class="yv-vlbl">(\d+)</span>');
  static final _tagRe = RegExp(r'<[^>]+>');

  List<PassageBlock> _parseHtml(String html) {
    final blocks = <PassageBlock>[];
    for (final m in _blockRe.allMatches(html)) {
      final cls = m.group(1) ?? '';
      final body = m.group(2) ?? '';
      final segments = <PassageSegment>[];

      // Footnotes come inline as nested spans; lift them out first so they
      // neither leak into the verse text nor end its block early.
      final (body: text, :notes) = _liftNotes(body);
      var cursor = 0;
      int? pendingVerse;
      void add(String fragment) {
        final noteIds = [
          for (final n in _noteMarkRe.allMatches(fragment)) int.parse(n[1]!),
        ];
        final clean = _clean(fragment.replaceAll(_noteMarkRe, ''));
        if (clean.isEmpty && noteIds.isEmpty && pendingVerse == null) return;
        if (clean.isEmpty &&
            noteIds.isNotEmpty &&
            segments.isNotEmpty &&
            pendingVerse == null) {
          final last = segments.removeLast();
          segments.add(last.withNotes([for (final i in noteIds) notes[i]]));
          return;
        }
        segments.add(
          PassageSegment(
            verse: pendingVerse,
            text: clean,
            notes: [for (final i in noteIds) notes[i]],
          ),
        );
        pendingVerse = null;
      }

      for (final v in _verseLabelRe.allMatches(text)) {
        final before = text.substring(cursor, v.start);
        if (_clean(before.replaceAll(_noteMarkRe, '')).isNotEmpty ||
            _noteMarkRe.hasMatch(before)) {
          add(before);
        }
        pendingVerse = int.tryParse(v.group(1) ?? '');
        cursor = v.end;
      }
      final tail = text.substring(cursor);
      if (_clean(tail.replaceAll(_noteMarkRe, '')).isNotEmpty ||
          _noteMarkRe.hasMatch(tail) ||
          pendingVerse != null) {
        add(tail);
      }

      if (segments.isEmpty) continue;
      blocks.add(
        PassageBlock(styleClass: cls.split(' ').first, segments: segments),
      );
    }
    return blocks;
  }

  static final _noteMarkRe = RegExp('\u0001(\\d+)\u0002');
  static final _noteOpenRe = RegExp(r'<span class="yv-n[^"]*">');
  static final _spanRe = RegExp(r'<(/?)span\b[^>]*>');
  static final _noteLabelRe = RegExp(r'<span class="fr">.*?</span>');

  /// Replaces each footnote span with a marker and returns the notes' text
  /// ("Or *in Christ Jesus, who do not walk…*"), its own "8:1" label dropped.
  static ({String body, List<String> notes}) _liftNotes(String html) {
    final notes = <String>[];
    final out = StringBuffer();
    var at = 0;
    for (;;) {
      final open = _noteOpenRe.firstMatch(html.substring(at));
      if (open == null) break;
      final start = at + open.start;
      var depth = 0;
      var end = html.length;
      for (final t in _spanRe.allMatches(html, start)) {
        depth += t[1] == '/' ? -1 : 1;
        if (depth == 0) {
          end = t.end;
          break;
        }
      }
      out.write(html.substring(at, start));
      final note = _cleanStatic(
        html.substring(start, end).replaceAll(_noteLabelRe, ''),
      );
      if (note.isNotEmpty) {
        out.write('\u0001${notes.length}\u0002');
        notes.add(note);
      }
      at = end;
    }
    out.write(html.substring(at));
    return (body: out.toString(), notes: notes);
  }

  static String _cleanStatic(String fragment) => fragment
      .replaceAll(_tagRe, '')
      .replaceAll('&nbsp;', ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  String _clean(String fragment) => fragment
      .replaceAll(_tagRe, '')
      .replaceAll('&nbsp;', ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

// ── Models ─────────────────────────────────────────────────────────────────────

class BibleVersion {
  const BibleVersion({
    required this.id,
    required this.abbreviation,
    required this.title,
  });

  final int id;
  final String abbreviation;
  final String title;
}

class BiblePassage {
  const BiblePassage({
    required this.reference,
    required this.blocks,
    required this.bibleAbbreviation,
    this.copyright,
  });

  final String reference;
  final List<PassageBlock> blocks;
  final String bibleAbbreviation;
  final String? copyright;
}

class PassageBlock {
  const PassageBlock({required this.styleClass, required this.segments});

  /// USFM-style block class: p, m, q1, q2, q3, d, s, s1, s2...
  final String styleClass;
  final List<PassageSegment> segments;

  bool get isHeading => styleClass.startsWith('s');
  bool get isSuperscription => styleClass == 'd';
  int get poetryIndent => switch (styleClass) {
    'q2' => 1,
    'q3' => 2,
    _ => 0,
  };
}

class PassageSegment {
  const PassageSegment({required this.text, this.verse, this.notes = const []});

  final int? verse;
  final String text;

  /// The translation's own footnotes at the end of this text, from the API.
  final List<String> notes;

  PassageSegment withNotes(List<String> more) =>
      PassageSegment(text: text, verse: verse, notes: [...notes, ...more]);
}

/// A book as one Bible version has it.
class BibleBook {
  const BibleBook({
    required this.usfm,
    required this.title,
    required this.testament,
    required this.chapters,
    this.verseCounts = const {},
  });

  /// The bundled canon entry, used when the version's own list is unreachable.
  BibleBook.canon(CanonBook book)
    : usfm = book.usfm,
      title = book.name,
      testament = book.testament,
      chapters = [for (var c = 1; c <= book.chapters; c++) c],
      verseCounts = const {};

  final String usfm;
  final String title;
  final Testament testament;

  /// Chapter numbers in order (1..n for every known version).
  final List<int> chapters;

  /// Last verse per chapter; empty when unknown (bundled fallback).
  final Map<int, int> verseCounts;

  bool hasChapter(int chapter) => chapters.contains(chapter);
}

/// A place in the Bible: a chapter, optionally a verse or verse range to
/// scroll to and highlight.
@immutable
class BibleLocation {
  const BibleLocation(
    this.usfm,
    this.chapter, {
    this.verseStart,
    this.verseEnd,
  });

  final String usfm;
  final int chapter;
  final int? verseStart;

  /// Last highlighted verse; equals [verseStart] for a single verse.
  final int? verseEnd;

  /// Chapter passage id for the passages endpoint, e.g. `JHN.3`.
  String get passageId => '$usfm.$chapter';

  bool sameChapter(BibleLocation other) =>
      usfm == other.usfm && chapter == other.chapter;

  /// The chapter itself, without a verse selection.
  BibleLocation get wholeChapter => BibleLocation(usfm, chapter);

  @override
  bool operator ==(Object other) =>
      other is BibleLocation &&
      other.usfm == usfm &&
      other.chapter == chapter &&
      other.verseStart == verseStart &&
      other.verseEnd == verseEnd;

  @override
  int get hashCode => Object.hash(usfm, chapter, verseStart, verseEnd);

  @override
  String toString() => verseStart == null
      ? passageId
      : '$passageId.$verseStart${verseEnd != verseStart ? '-$verseEnd' : ''}';
}

/// The books of one version, plus chapter-to-chapter navigation.
class BibleIndex {
  const BibleIndex(this.books, {this.isFallback = false});

  /// The bundled 66-book canon, for when the version's list cannot load.
  factory BibleIndex.bundled() => BibleIndex([
    for (final b in kCanonBooks) BibleBook.canon(b),
  ], isFallback: true);

  final List<BibleBook> books;

  /// True when built from the bundled table rather than the API.
  final bool isFallback;

  BibleBook? book(String usfm) {
    for (final b in books) {
      if (b.usfm == usfm) return b;
    }
    return null;
  }

  /// Human label, e.g. "John 3", "John 3:16" or "1 Corinthians 13:4-7".
  String label(BibleLocation at) {
    final name =
        book(at.usfm)?.title ??
        kCanonBooks
            .where((b) => b.usfm == at.usfm)
            .map((b) => b.name)
            .firstOrNull ??
        at.usfm;
    final start = at.verseStart;
    if (start == null) return '$name ${at.chapter}';
    final end = at.verseEnd;
    return end == null || end == start
        ? '$name ${at.chapter}:$start'
        : '$name ${at.chapter}:$start-$end';
  }

  /// The chapter after [at], continuing into the next book; null at the end
  /// of the Bible or when [at] is not in this version.
  BibleLocation? next(BibleLocation at) => _step(at, 1);

  /// The chapter before [at], continuing into the previous book; null at the
  /// start of the Bible or when [at] is not in this version.
  BibleLocation? previous(BibleLocation at) => _step(at, -1);

  BibleLocation? _step(BibleLocation at, int delta) {
    final bookIndex = books.indexWhere((b) => b.usfm == at.usfm);
    if (bookIndex < 0) return null;
    final chapters = books[bookIndex].chapters;
    final chapterIndex = chapters.indexOf(at.chapter);
    if (chapterIndex < 0) return null;
    final target = chapterIndex + delta;
    if (target >= 0 && target < chapters.length) {
      return BibleLocation(at.usfm, chapters[target]);
    }
    final otherIndex = bookIndex + delta;
    if (otherIndex < 0 || otherIndex >= books.length) return null;
    final other = books[otherIndex];
    return BibleLocation(
      other.usfm,
      delta > 0 ? other.chapters.first : other.chapters.last,
    );
  }
}

/// The 66-book canon by USFM id, with each book's canonical position.
final Map<String, ({int order, CanonBook book})> _canonByUsfm = {
  for (final (i, b) in kCanonBooks.indexed) b.usfm: (order: i, book: b),
};
