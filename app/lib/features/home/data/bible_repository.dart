import 'package:dio/dio.dart';

/// Fetches Bible passage text and version metadata from the YouVersion
/// Platform API.
///
/// The app key is injected at build time via --dart-define (never committed):
///   flutter build web --dart-define-from-file=env.json
/// License set (June 2026): 20 English versions incl. NIV11 (111),
/// AMP (1588), NASB2020 (2692), BSB (3034), ASV (12).
class BibleRepository {
  BibleRepository({Dio? dio}) : _dio = dio ?? Dio();

  static const _base = 'https://api.youversion.com/v1';
  static const _appKey = String.fromEnvironment('YOUVERSION_API_KEY');

  /// NIV 2011 - the default reading translation.
  static const defaultBibleId = 111;
  static const defaultBibleAbbreviation = 'NIV';

  final Dio _dio;

  final _passageCache = <String, BiblePassage>{};
  List<BibleVersion>? _biblesCache;

  Options get _options {
    if (_appKey.isEmpty) {
      throw StateError(
        'YOUVERSION_API_KEY missing. Build with '
        '--dart-define-from-file=env.json (see env.example.json).',
      );
    }
    return Options(headers: {
      'x-yvp-app-key': _appKey,
      'Accept': 'application/json',
    });
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
          abbreviation: (b['localized_abbreviation'] ??
              b['abbreviation'] ??
              '?') as String,
          title: (b['localized_title'] ?? b['title'] ?? '') as String,
        ),
    ];
    return _biblesCache!;
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

    final response = await _dio.get<Map<String, dynamic>>(
      '$_base/bibles/$bibleId/passages/$usfmId',
      queryParameters: {'format': 'html', 'include_headings': 'true'},
      options: _options,
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

  // ── HTML parsing ────────────────────────────────────────────────────────────
  //
  // The platform returns regular markup:
  //   <div class="q1"><span class="yv-v" v="1"></span>
  //   <span class="yv-vlbl">1</span>The Lord is my shepherd...</div>
  // Block classes: p/m prose, q1..q3 poetry indents, d superscription,
  // s/s1/s2 headings. Verse labels arrive as yv-vlbl spans.

  static final _blockRe =
      RegExp(r'<div class="([^"]*)">(.*?)</div>', dotAll: true);
  static final _verseLabelRe =
      RegExp(r'<span class="yv-vlbl">(\d+)</span>');
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
      blocks.add(PassageBlock(
        styleClass: cls.split(' ').first,
        segments: segments,
      ));
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
