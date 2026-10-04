import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show compute;

import 'package:kharis_app/core/constants/http_constants.dart';
import 'package:kharis_app/core/utils/sermon_categorizer.dart';
import 'package:kharis_app/shared/models/sermon.dart';
import 'kharis_api_sermon_repository.dart';
import 'sermon_repository_base.dart';

/// Reads the sermon catalogue from `messages.json` in the Cloudflare R2
/// bucket the import Worker (`backend/cloudflare-worker/`) writes to.
///
/// The Worker mirrors the public API on a schedule (see its `wrangler.toml`
/// crons), so its copy can trail the API by a few days. Page 1 is therefore
/// the R2 archive headed by the live API's own page 1: one large request
/// brings the whole archive (plus transcript links, which only R2 has), and
/// the small API request brings anything uploaded since the Worker last ran.
///
/// Everything else delegates to [KharisApiSermonRepository]: searches, `next`
/// links, and page 1 itself whenever R2 is unreachable or empty, so a dead
/// bucket degrades to the paged API walk rather than an empty library.
class R2MessagesRepository extends AbstractSermonRepository {
  R2MessagesRepository({Dio? dio, KharisApiSermonRepository? api})
    : _dio = dio ?? Dio(),
      _api = api ?? KharisApiSermonRepository();

  final Dio _dio;
  final KharisApiSermonRepository _api;

  @override
  Future<SermonPage> fetchPage({String? url, String? search}) async {
    if (url != null || (search != null && search.isNotEmpty)) {
      return _api.fetchPage(url: url, search: search);
    }

    final apiHead = _api.fetchPage().then<SermonPage?>(
      (page) => page,
      onError: (Object _) => null,
    );
    final List<Sermon> mirror;
    try {
      mirror = await _fetchMirror();
    } catch (_) {
      // No mirror: the paged API walk, with its errors propagating so the
      // notifier can tell "failed" from "empty".
      final head = await apiHead;
      return head ?? _api.fetchPage();
    }

    final head = await apiHead;
    final transcripts = <String, String>{
      for (final s in mirror)
        if (s.hasTranscript) s.id: s.transcriptUrl!,
    };
    final seen = <String>{};
    final sermons = [
      // The API's newest arrivals lead, carrying any transcript R2 has.
      for (final s in head?.sermons ?? const <Sermon>[])
        if (seen.add(s.id))
          transcripts[s.id] == null
              ? s
              : s.copyWith(transcriptUrl: transcripts[s.id]),
      ...mirror.where((s) => seen.add(s.id)),
    ];
    // The whole archive is in hand, so there is no next page and the count
    // is what was merged: the mirror plus every newer arrival on page 1.
    return SermonPage(sermons: sermons, totalCount: sermons.length);
  }

  Future<List<Sermon>> _fetchMirror() async {
    final res = await _dio.get<Map<String, dynamic>>(
      kR2MessagesUrl,
      options: Options(receiveTimeout: const Duration(seconds: 20)),
    );
    final list = (res.data?['messages'] as List?) ?? const [];
    // Categorising runs hundreds of regexes per record; keep the ~1,500
    // records off the UI isolate.
    final sermons = list.isEmpty
        ? const <Sermon>[]
        : await compute(mapR2Messages, list, debugLabel: 'mapR2Messages');
    // An empty or malformed file is treated as a failed request: better the
    // known-good API than an empty library.
    if (sermons.isEmpty) throw StateError('empty messages.json');
    return sermons;
  }

  /// Offline fallback: the bundled archive, never the network.
  @override
  Future<List<Sermon>> loadCatalogue() => _api.loadCatalogue();
}

/// Maps `messages.json` records. Top-level so [compute] can run it in a
/// background isolate.
List<Sermon> mapR2Messages(List<dynamic> records) => [
  for (final r in records) ?mapR2Message(r as Map<String, dynamic>),
];

/// Maps one `messages.json` record with the same rules as [mapApiSermon], so
/// a sermon looks identical whichever source served it. Field names come
/// from the Worker's schema (`backend/cloudflare-worker/src/index.js`), not
/// the raw API shape. Only a record without an id is dropped.
Sermon? mapR2Message(Map<String, dynamic> m) {
  final id = '${m['id'] ?? ''}'.trim();
  if (id.isEmpty) return null;

  final title = (m['title'] as String? ?? '').trim();
  final description = (m['description'] as String?)?.trim();
  final series = (m['series'] as Map<String, dynamic>?)?['name'] as String?;
  final videoLink = m['video_url'] as String?;
  final numericId = int.tryParse(id);

  return Sermon(
    id: id,
    title: title,
    speaker: (m['speaker'] as String? ?? '').trim(),
    audioUrl: (m['audio_url'] as String? ?? '').trim(),
    artworkUrl: biggerSermonImage(m['image_url'] as String?),
    duration: m['duration'] is num
        ? Duration(seconds: (m['duration'] as num).toInt())
        : null,
    publishedAt: DateTime.tryParse(m['date_preached'] as String? ?? ''),
    series: (series == null || series.trim().isEmpty) ? null : series.trim(),
    description: description,
    artworkColor: (numericId ?? id.hashCode).abs() % 10,
    category: sermonCategory(title, description: description),
    videoId: youTubeVideoId(videoLink),
    videoStart: youTubeStart(videoLink),
    source: 'kharis-api',
    transcriptUrl: _absoluteTranscriptUrl(m['transcript_url'] as String?),
  );
}

/// `transcript_url` is bucket-relative (`transcripts/100239.txt`); resolve it
/// against the bucket `messages.json` came from.
String? _absoluteTranscriptUrl(String? relativePath) {
  if (relativePath == null || relativePath.isEmpty) return null;
  if (relativePath.startsWith('http')) return relativePath;
  return '$kR2BucketBaseUrl/${relativePath.replaceFirst(RegExp(r'^/+'), '')}';
}
