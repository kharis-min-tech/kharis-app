import 'package:dio/dio.dart';

import 'package:kharis_app/core/constants/http_constants.dart';
import 'package:kharis_app/core/utils/sermon_categorizer.dart';
import 'package:kharis_app/shared/models/sermon.dart';
import 'sermon_repository_base.dart';
import 'sermon_repository.dart';

/// Reads sermons from the Kharis public API (yetanothersermon.host).
///
/// Notes on the upstream API (see change-request list in the integration
/// report):
/// - The host is behind Cloudflare bot protection → a browser [kBrowserUserAgent]
///   is required or requests 403.
/// - `audio_link.download_url` is **scheme-less** (`yetanothersermon.host/...`);
///   we prepend `https://`. It 302-redirects to a time-limited signed CDN URL,
///   so the player must follow redirects and send the same UA.
/// - `series` / `preacher` query filters are currently ignored server-side, so
///   category/series filtering happens client-side after fetch.
class KharisApiSermonRepository extends AbstractSermonRepository {
  KharisApiSermonRepository({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: 'https://yetanothersermon.host/_/kc/public-api/v1/',
                headers: const {'User-Agent': kBrowserUserAgent},
                connectTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(seconds: 20),
              ),
            );

  final Dio _dio;

  /// Depth of the eager [getSermons] fetch. The full archive (~30 pages) is
  /// reached incrementally through [fetchPage] as the user scrolls.
  static const int _maxEagerPages = 4;

  @override
  Future<List<Sermon>> getSermons() async {
    // Follow the server's `next` links instead of guessing page numbers, so
    // the fetch stops exactly where the archive does.
    final out = <Sermon>[];
    String? url;
    for (var i = 0; i < _maxEagerPages; i++) {
      final page = await fetchPage(url: url);
      out.addAll(page.sermons);
      url = page.nextUrl;
      if (url == null) break;
    }
    return out;
  }

  /// Fetches one page of the sermon archive.
  ///
  /// [url] is the absolute `next` link returned by the previous page (`null`
  /// fetches page 1). [search] applies the server-side `?search=` filter.
  /// Errors propagate to the caller — a paging UI must distinguish "archive
  /// ended" from "request failed", so nothing is swallowed here.
  @override
  Future<SermonPage> fetchPage({String? url, String? search}) async {
    final resp = await _dio.get<Map<String, dynamic>>(
      url ?? 'sermons/',
      queryParameters: url == null && search != null && search.isNotEmpty
          ? {'search': search}
          : null,
    );
    final data = resp.data ?? const <String, dynamic>{};
    final results = (data['results'] as List?) ?? const [];
    return SermonPage(
      sermons: [
        for (final r in results) ?_mapSermon(r as Map<String, dynamic>),
      ],
      nextUrl: _nullableAbsolute(data['next'] as String?),
      totalCount: (data['count'] as num?)?.toInt() ?? 0,
    );
  }

  /// `next` links normally carry a scheme, but the API serves other URLs
  /// scheme-less, so absolutise defensively.
  static String? _nullableAbsolute(String? url) {
    if (url == null || url.isEmpty) return null;
    return _absolutise(url);
  }

  /// Offline fallback: the bundled archive, never the network.
  @override
  Future<List<Sermon>> loadCatalogue() => SermonRepository().loadCatalogue();

  // ── Mapping ────────────────────────────────────────────────────────────────

  Sermon? _mapSermon(Map<String, dynamic> j) {
    final audio = j['audio_link'] as Map<String, dynamic>?;
    final audioUrl = _absolutise(audio?['download_url'] as String?);
    final videoId = _youTubeId(j['video_link'] as String?);
    // The library is the audio catalogue: a record with only a `video_link`
    // has nothing to stream (and an empty URL wedges the player), so it is
    // dropped here. Video content reaches the app through the YouTube feed.
    if (audioUrl.isEmpty) return null;

    final preachers = (j['preachers'] as List?) ?? const [];
    final speaker = preachers
        .map((p) => (p as Map<String, dynamic>)['name'] as String? ?? '')
        .where((n) => n.isNotEmpty)
        .join(', ');

    final series = j['series'] as Map<String, dynamic>?;
    final title = (j['title'] as String? ?? '').trim();
    final id = (j['id'] as num).toInt();

    return Sermon(
      id: id.toString(),
      title: title,
      speaker: speaker,
      audioUrl: audioUrl,
      artworkUrl: _biggerImage(j['image'] as String?),
      duration: audio?['duration'] != null
          ? Duration(seconds: (audio!['duration'] as num).toInt())
          : null,
      publishedAt: _parseDate(j['date'] as String?, j['time'] as String?),
      series: series?['name'] as String?,
      description: (j['description'] as String?)?.trim(),
      artworkColor: id % 10,
      // API has no topic/category field — fall back to series, else derive from
      // the title so the Messages category chips have something to group on.
      category: series?['name'] as String? ?? sermonCategory(title),
      videoId: videoId,
      source: 'kharis-api',
    );
  }

  /// Prepends `https://` to the API's scheme-less URLs.
  static String _absolutise(String? url) {
    if (url == null || url.isEmpty) return '';
    if (url.startsWith('http')) return url;
    return 'https://${url.replaceFirst(RegExp(r'^/+'), '')}';
  }

  /// Bumps the CDN thumbnail from `?width=256` to a sharper-but-light `512`.
  static String? _biggerImage(String? url) {
    if (url == null || url.isEmpty) return null;
    return url.contains('width=')
        ? url.replaceAll(RegExp(r'width=\d+'), 'width=512')
        : url;
  }

  /// Extracts the YouTube id from a watch/`youtu.be` URL; `""`/null → null.
  static String? _youTubeId(String? link) {
    if (link == null || link.isEmpty) return null;
    final uri = Uri.tryParse(link);
    if (uri == null) return null;
    final v = uri.queryParameters['v'];
    if (v != null && v.isNotEmpty) return v;
    if (uri.host.contains('youtu.be') && uri.pathSegments.isNotEmpty) {
      return uri.pathSegments.first;
    }
    return null;
  }

  static DateTime? _parseDate(String? date, String? time) {
    if (date == null || date.isEmpty) return null;
    final t = (time == null || time.isEmpty) ? '00:00:00' : time;
    return DateTime.tryParse('${date}T$t');
  }
}
