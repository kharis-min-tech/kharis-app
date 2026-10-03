import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show compute, kIsWeb;

import 'package:kharis_app/core/constants/api_config.dart';
import 'package:kharis_app/core/constants/http_constants.dart';
import 'package:kharis_app/core/utils/sermon_categorizer.dart';
import 'package:kharis_app/shared/models/sermon.dart';
import 'sermon_repository_base.dart';
import 'sermon_repository.dart';

/// Reads sermons from the Kharis public API (yetanothersermon.host).
///
/// Notes on the upstream API:
/// - The host is behind Cloudflare bot protection, so a browser
///   [kBrowserUserAgent] is required or requests 403.
/// - The host sends no CORS headers, so web builds go through the
///   `sermonApiProxy` Cloud Function ([ApiConfig.sermonApiBase]).
/// - `audio_link.download_url` is **scheme-less** (`yetanothersermon.host/...`);
///   we prepend `https://`. It 302-redirects to a time-limited signed CDN URL,
///   so the player must follow redirects and send the same UA.
/// - The API has no topic field, and its `series` / `preacher` query filters
///   are ignored server-side, so topics and series filtering are client-side.
class KharisApiSermonRepository extends AbstractSermonRepository {
  KharisApiSermonRepository({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: ApiConfig.sermonApiBase,
              // Browsers refuse to set a User-Agent, and the proxy sends
              // its own; only native clients need the header.
              headers: kIsWeb ? null : const {'User-Agent': kBrowserUserAgent},
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 20),
            ),
          );

  final Dio _dio;

  /// Fetches one page of the sermon archive.
  ///
  /// [url] is the absolute `next` link returned by the previous page (`null`
  /// fetches page 1). [search] applies the server-side `?search=` filter to
  /// page 1; its `next` link carries the query on.
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
      // Categorising runs hundreds of regexes per record; keep it off the UI
      // isolate, which is scrolling while the archive drains.
      sermons: results.isEmpty
          ? const []
          : await compute(mapApiSermons, results, debugLabel: 'mapApiSermons'),
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
}

/// Maps one page of API sermon records. Top-level so [compute] can run it in
/// a background isolate.
List<Sermon> mapApiSermons(List<dynamic> results) => [
  for (final r in results) mapApiSermon(r as Map<String, dynamic>),
];

/// Maps one API sermon record.
///
/// Every record is kept, so the library matches the API's count year for
/// year. Video-only records play in video mode; the four records with no
/// recording at all still list (and the player explains there is nothing to
/// play) rather than silently vanishing.
Sermon mapApiSermon(Map<String, dynamic> j) {
  final audio = j['audio_link'] as Map<String, dynamic>?;
  final audioUrl = _absolutise(audio?['download_url'] as String?);
  final videoLink = j['video_link'] as String?;
  final videoId = youTubeVideoId(videoLink);

  final preachers = (j['preachers'] as List?) ?? const [];
  final speaker = preachers
      .map((p) => (p as Map<String, dynamic>)['name'] as String? ?? '')
      .where((n) => n.isNotEmpty)
      .join(', ');

  final series = (j['series'] as Map<String, dynamic>?)?['name'] as String?;
  final title = (j['title'] as String? ?? '').trim();
  final description = (j['description'] as String?)?.trim();
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
    series: (series == null || series.trim().isEmpty) ? null : series.trim(),
    description: description,
    artworkColor: id % 10,
    // The topic, never the series: series get their own rail and filter, and
    // a series name here hid those sermons from every topic chip.
    category: sermonCategory(title, description: description),
    videoId: videoId,
    videoStart: youTubeStart(videoLink),
    source: 'kharis-api',
  );
}

/// Prepends `https://` to the API's scheme-less URLs.
String _absolutise(String? url) {
  if (url == null || url.isEmpty) return '';
  if (url.startsWith('http')) return url;
  return 'https://${url.replaceFirst(RegExp(r'^/+'), '')}';
}

/// Bumps the CDN thumbnail from `?width=256` to a sharper-but-light `512`.
String? _biggerImage(String? url) {
  if (url == null || url.isEmpty) return null;
  return url.contains('width=')
      ? url.replaceAll(RegExp(r'width=\d+'), 'width=512')
      : url;
}

DateTime? _parseDate(String? date, String? time) {
  if (date == null || date.isEmpty) return null;
  final t = (time == null || time.isEmpty) ? '00:00:00' : time;
  return DateTime.tryParse('${date}T$t');
}

final RegExp _youTubeIdPattern = RegExp(r'^[\w-]{11}$');

/// Extracts the 11-character YouTube id from any common link form:
/// `watch?v=`, `youtu.be/<id>`, `/live/<id>`, `/shorts/<id>`, `/embed/<id>`,
/// `/v/<id>` and the bare `youtube.com/<id>` the API sometimes stores.
/// Returns null for empty, non-YouTube or malformed links.
String? youTubeVideoId(String? link) {
  final raw = link?.trim();
  if (raw == null || raw.isEmpty) return null;
  final uri = Uri.tryParse(raw.contains('://') ? raw : 'https://$raw');
  if (uri == null) return null;
  final host = uri.host.toLowerCase();
  final isShort = host == 'youtu.be' || host.endsWith('.youtu.be');
  final isLong =
      host == 'youtube.com' ||
      host.endsWith('.youtube.com') ||
      host == 'youtube-nocookie.com' ||
      host.endsWith('.youtube-nocookie.com');
  if (!isShort && !isLong) return null;

  String? candidate;
  final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
  if (isShort) {
    candidate = segments.firstOrNull;
  } else if (uri.queryParameters['v'] case final v? when v.isNotEmpty) {
    candidate = v;
  } else if (segments.length >= 2 &&
      const {'live', 'shorts', 'embed', 'v', 'e'}.contains(segments[0])) {
    candidate = segments[1];
  } else if (segments.length == 1) {
    candidate = segments[0];
  }
  if (candidate == null || !_youTubeIdPattern.hasMatch(candidate)) return null;
  return candidate;
}

/// The start offset in a YouTube link (`t=860s`, `t=860`, `t=1h2m3s`,
/// `start=860`), or null when absent or zero.
Duration? youTubeStart(String? link) {
  final raw = link?.trim();
  if (raw == null || raw.isEmpty) return null;
  final uri = Uri.tryParse(raw.contains('://') ? raw : 'https://$raw');
  if (uri == null) return null;
  final value =
      uri.queryParameters['t'] ??
      uri.queryParameters['start'] ??
      // `#t=1m30s` fragments are used by some share links.
      Uri.splitQueryString(uri.fragment)['t'];
  if (value == null || value.isEmpty) return null;
  final plain = int.tryParse(value.replaceFirst(RegExp(r's$'), ''));
  if (plain != null) return plain > 0 ? Duration(seconds: plain) : null;
  final m = RegExp(r'^(?:(\d+)h)?(?:(\d+)m)?(?:(\d+)s)?$').firstMatch(value);
  if (m == null) return null;
  final seconds =
      (int.tryParse(m.group(1) ?? '') ?? 0) * 3600 +
      (int.tryParse(m.group(2) ?? '') ?? 0) * 60 +
      (int.tryParse(m.group(3) ?? '') ?? 0);
  return seconds > 0 ? Duration(seconds: seconds) : null;
}
