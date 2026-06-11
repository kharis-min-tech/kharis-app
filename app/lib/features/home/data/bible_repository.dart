import 'package:dio/dio.dart';

/// Fetches Bible passage text from the YouVersion Platform API.
///
/// The app key is injected at build time via --dart-define (never committed):
///   flutter build web --dart-define-from-file=env.json
/// or
///   flutter build web --dart-define=YOUVERSION_API_KEY=$YOUVERSION_API_KEY
/// License set includes NIV11 (id 111), NASB1995 (100), NIrV (110), ASV (12).
class BibleRepository {
  BibleRepository({Dio? dio}) : _dio = dio ?? Dio();

  static const _base = 'https://api.youversion.com/v1';
  static const _appKey = String.fromEnvironment('YOUVERSION_API_KEY');

  /// NIV 2011 - the default reading translation.
  static const defaultBibleId = 111;
  static const defaultBibleAbbreviation = 'NIV';

  final Dio _dio;

  final _cache = <String, BiblePassage>{};

  /// Fetches a passage (chapter or verse) by USFM id, e.g. 'PSA.23'.
  Future<BiblePassage> getPassage(
    String usfmId, {
    int bibleId = defaultBibleId,
  }) async {
    if (_appKey.isEmpty) {
      throw StateError(
        'YOUVERSION_API_KEY missing. Build with '
        '--dart-define-from-file=env.json (see env.example.json).',
      );
    }
    final cacheKey = '$bibleId/$usfmId';
    final cached = _cache[cacheKey];
    if (cached != null) return cached;

    final response = await _dio.get<Map<String, dynamic>>(
      '$_base/bibles/$bibleId/passages/$usfmId',
      queryParameters: {'format': 'text', 'include_headings': 'true'},
      options: Options(headers: {
        'x-yvp-app-key': _appKey,
        'Accept': 'application/json',
      }),
    );

    final data = response.data ?? const {};
    final passage = BiblePassage(
      reference: data['reference'] as String? ?? usfmId,
      content: (data['content'] as String? ?? '').trim(),
      copyright: data['copyright'] as String?,
      bibleAbbreviation: defaultBibleAbbreviation,
    );
    if (passage.content.isEmpty) {
      throw StateError('Empty passage content for $usfmId');
    }
    _cache[cacheKey] = passage;
    return passage;
  }
}

class BiblePassage {
  const BiblePassage({
    required this.reference,
    required this.content,
    required this.bibleAbbreviation,
    this.copyright,
  });

  final String reference;
  final String content;
  final String bibleAbbreviation;
  final String? copyright;
}
