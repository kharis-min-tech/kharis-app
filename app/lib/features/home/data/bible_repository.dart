import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:kharis_app/core/constants/bible_books.dart';

/// Fetches Bible passage text and version metadata from the YouVersion
/// Platform API.
///
/// The app key is injected at build time via --dart-define (never committed):
///   flutter build web --dart-define-from-file=env.json
/// License set (June 2026): 20 English versions incl. NIV11 (111),
/// AMP (1588), NASB2020 (2692), BSB (3034), ASV (12).
class BibleRepository {
  /// [appKey] defaults to the build-time `YOUVERSION_API_KEY` define.
  BibleRepository({Dio? dio, String? appKey})
    : _dio = dio ?? Dio(),
      _key = appKey ?? _appKey;

  static const _base = 'https://api.youversion.com/v1';
  static const _appKey = String.fromEnvironment('YOUVERSION_API_KEY');

  final String _key;

  /// NIV 2011 - the default reading translation.
  static const defaultBibleId = 111;
  static const defaultBibleAbbreviation = 'NIV';

  final Dio _dio;

  final _passageCache = <String, BiblePassage>{};
  final _booksCache = <int, List<BibleBook>>{};
  List<BibleVersion>? _biblesCache;

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

  /// Lists the Bible versions licensed for this app key.
  Future<List<BibleVersion>> getBibles() async {
    if (_biblesCache != null) return _biblesCache!;
    final response = await _dio.get<Map<String, dynamic>>(
      '$_base/bibles',
      queryParameters: {'language_ranges[]': 'en', 'page_size': 50},
      options: _options,
    );
    final data = (response.data?['data'] as List? ?? const [])
        .cast<Map<String, dynamic>>();
    _biblesCache = [
      for (final b in data)
        BibleVersion(
          id: (b['id'] as num).toInt(),
          abbreviation:
              (b['localized_abbreviation'] ?? b['abbreviation'] ?? '?')
                  as String,
          title: (b['localized_title'] ?? b['title'] ?? '') as String,
        ),
    ];
    return _biblesCache!;
  }

  /// Books of [bibleId] in canonical order, with each book's chapters and
  /// verse counts. Versions differ (NT-only, partial OT, deuterocanon), so
  /// navigation and reference search use this rather than a fixed table.
  Future<List<BibleBook>> getBooks(int bibleId) async {
    final cached = _booksCache[bibleId];
    if (cached != null) return cached;

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
          usfm: b['id'] as String,
          title: (b['title'] ?? b['id']) as String,
          testament: switch (b['canon']) {
            'old_testament' => Testament.old,
            'new_testament' => Testament.newTestament,
            _ => Testament.other,
          },
          chapters: chapters,
          verseCounts: verseCounts,
        ),
      );
    }
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

    final response = await _withRetry(
      () => _dio.get<Map<String, dynamic>>(
        '$_base/bibles/$bibleId/passages/$usfmId',
        queryParameters: {'format': 'html', 'include_headings': 'true'},
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

      var cursor = 0;
      int? pendingVerse;
      for (final v in _verseLabelRe.allMatches(body)) {
        final before = body.substring(cursor, v.start);
        final text = _clean(before);
        if (text.isNotEmpty) {
          segments.add(PassageSegment(verse: pendingVerse, text: text));
          pendingVerse = null;
        }
        pendingVerse = int.tryParse(v.group(1) ?? '');
        cursor = v.end;
      }
      final tailText = _clean(body.substring(cursor));
      if (tailText.isNotEmpty || pendingVerse != null) {
        segments.add(PassageSegment(verse: pendingVerse, text: tailText));
      }

      if (segments.isEmpty) continue;
      blocks.add(
        PassageBlock(styleClass: cls.split(' ').first, segments: segments),
      );
    }
    return blocks;
  }

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
  const PassageSegment({required this.text, this.verse});

  final int? verse;
  final String text;
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
