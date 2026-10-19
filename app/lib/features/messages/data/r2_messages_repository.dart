import 'dart:math' as math;

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
/// links, and page 1 itself whenever R2 is unreachable, empty or slower than
/// [mirrorDeadline], so a dead or stalled bucket degrades to the paged API
/// walk rather than an empty library.
class R2MessagesRepository extends AbstractSermonRepository {
  R2MessagesRepository({
    Dio? dio,
    KharisApiSermonRepository? api,
    this.mirrorDeadline = const Duration(seconds: 25),
  }) : _dio =
           dio ?? Dio(BaseOptions(connectTimeout: const Duration(seconds: 10))),
       _api = api ?? KharisApiSermonRepository();

  final Dio _dio;
  final KharisApiSermonRepository _api;

  /// Longest the whole mirror download may take. Dio's receive timeout only
  /// trips on silence, so on a lossy connection that trickles bytes the
  /// ~1.5 MB file could otherwise hold page 1 (and the library) for minutes.
  final Duration mirrorDeadline;

  /// How many sermons the mirror may trail the API's total by (records the
  /// mapper drops, deletions between the two reads) before it counts as
  /// truncated.
  static const mirrorCountTolerance = 5;

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
      mirror = await _fetchMirror().timeout(mirrorDeadline);
    } catch (_) {
      // No mirror: the paged API walk, with its errors propagating so the
      // notifier can tell "failed" from "empty".
      final head = await apiHead;
      return head ?? _api.fetchPage();
    }

    final head = await apiHead;
    final extras = {for (final s in mirror) s.id: s};
    final seen = <String>{};
    final sermons = [
      // The API's newest arrivals lead, carrying what only R2 has.
      for (final s in head?.sermons ?? const <Sermon>[])
        if (seen.add(s.id)) _withMirrorExtras(s, extras[s.id]),
      ...mirror.where((s) => seen.add(s.id)),
    ];
    // A truncated mirror (short upstream list, partial upload) must not pose
    // as the whole archive: it would be saved over the cached library. When
    // the live API counts clearly more, use the paged walk instead.
    if (head != null &&
        sermons.length + mirrorCountTolerance < head.totalCount) {
      return head;
    }
    // The whole archive is in hand, so there is no next page. The count never
    // drops below the API's own total, so a small shortfall still reads as a
    // gap for the notifier rather than a complete archive.
    return SermonPage(
      sermons: sermons,
      totalCount: math.max(sermons.length, head?.totalCount ?? 0),
    );
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
}

/// [api] with the fields only the mirror carries (transcript link, related
/// messages, tags) filled in from its [mirror] record.
Sermon _withMirrorExtras(Sermon api, Sermon? mirror) {
  if (mirror == null) return api;
  return api.copyWith(
    transcriptUrl: api.transcriptUrl ?? mirror.transcriptUrl,
    relatedIds: api.relatedIds.isEmpty ? mirror.relatedIds : null,
    tags: api.tags.isEmpty ? mirror.tags : null,
  );
}

/// Maps `messages.json` records, dropping malformed ones like
/// [mapApiSermons]. Top-level so [compute] can run it in a background isolate.
List<Sermon> mapR2Messages(List<dynamic> records) => [
  for (final r in records) ?tryMapSermon(r, mapR2Message),
];

/// Maps one `messages.json` record with the same rules as [mapApiSermon], so
/// a sermon looks identical whichever source served it. Field names come
/// from the Worker's schema (`backend/cloudflare-worker/src/index.js`), not
/// the raw API shape. A record without an id is dropped; a wrongly typed field
/// throws, and [mapR2Messages] drops that record.
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
    // Id strings scraped from the sermon site; numeric ids are tolerated.
    relatedIds: [
      for (final r in m['related_message_ids'] as List? ?? const [])
        if (r is String || r is num)
          if ('$r'.trim() case final rid when rid.isNotEmpty && rid != id) rid,
    ],
    tags: [
      for (final t in m['tags'] as List? ?? const [])
        if (t is String && t.trim().isNotEmpty) t.trim(),
    ],
  );
}

/// `transcript_url` is bucket-relative (`transcripts/100239.txt`); resolve it
/// against the bucket `messages.json` came from.
String? _absoluteTranscriptUrl(String? relativePath) {
  if (relativePath == null || relativePath.isEmpty) return null;
  if (relativePath.startsWith('http')) return relativePath;
  return '$kR2BucketBaseUrl/${relativePath.replaceFirst(RegExp(r'^/+'), '')}';
}
