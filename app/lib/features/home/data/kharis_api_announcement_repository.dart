import 'package:dio/dio.dart';
import 'package:kharis_app/core/constants/api_config.dart';

import 'news_repository.dart';

/// Fetches announcements from the Kharis Cloud Functions API
/// (`getAnnouncements` on the Kharis backend) and maps them to [NewsItem].
///
/// Branch scoping happens server-side: passing [branch] returns that campus's
/// announcements plus all-campus ones, so a branch notice can never be pushed
/// off the end of a global page. Falls back to a one-shot Firestore read when
/// the API is unreachable, applying the same scope in memory.
class KharisApiAnnouncementRepository {
  KharisApiAnnouncementRepository({Dio? dio, NewsRepository? fallback})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 12),
              receiveTimeout: const Duration(seconds: 15),
            ),
          ),
      _fallback = fallback ?? NewsRepository();

  static const String _url = ApiConfig.getAnnouncements;

  final Dio _dio;
  final NewsRepository _fallback;

  Future<List<NewsItem>> getAnnouncements({
    int limit = 20,
    String? branch,
  }) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        _url,
        queryParameters: {
          'limit': limit,
          if (branch != null && branch.isNotEmpty) 'branch': branch,
        },
      );
      final raw = (res.data?['announcements'] as List?) ?? const [];
      return raw
          .whereType<Map<String, dynamic>>()
          .map(_map)
          .whereType<NewsItem>()
          .toList();
    } catch (_) {
      // Offline / API down → last-known Firestore snapshot, same scope.
      return _fallback.watchNews(limit: limit, branch: branch).first;
    }
  }

  NewsItem? _map(Map<String, dynamic> j) {
    final id = j['id'] as String?;
    final title = j['title'] as String?;
    if (id == null || title == null) return null;
    // The API sends UTC ISO strings; members read local wall-clock dates.
    final ts = j['publishedAt'] as String?;
    final expiry = j['expiresAt'] as String?;
    final linkUrl = _text(j['linkUrl']);
    return NewsItem(
      id: id,
      title: title,
      type: NewsItem.normaliseType(j['type'] as String?),
      publishedAt:
          (ts != null ? DateTime.tryParse(ts) : null)?.toLocal() ??
          DateTime.now(),
      body: j['body'] as String?,
      imageUrl: j['imageUrl'] as String?,
      // Blank means all-campus, exactly like null.
      branch: _text(j['branch']),
      expiresAt: expiry != null ? DateTime.tryParse(expiry)?.toLocal() : null,
      eventId: _text(j['eventId']),
      linkUrl: linkUrl,
      ctaLabel: linkUrl == null ? null : (_text(j['ctaLabel']) ?? 'Learn more'),
    );
  }

  /// Trimmed string, or `null` when absent, not a string, or blank.
  static String? _text(Object? raw) {
    if (raw is! String) return null;
    final value = raw.trim();
    return value.isEmpty ? null : value;
  }
}
