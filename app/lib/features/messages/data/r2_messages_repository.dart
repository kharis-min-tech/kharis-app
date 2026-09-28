import 'package:dio/dio.dart';

import 'package:kharis_app/core/constants/http_constants.dart';
import 'package:kharis_app/core/utils/sermon_categorizer.dart';
import 'package:kharis_app/shared/models/sermon.dart';
import 'kharis_api_sermon_repository.dart';
import 'sermon_repository_base.dart';

/// Reads the sermon catalogue from `messages.json` in the Cloudflare R2
/// bucket the import Worker (`backend/cloudflare-worker/`) writes to.
///
/// [kR2MessagesUrl] is a placeholder until that Worker is actually deployed,
/// so every request here currently fails (host doesn't resolve, or 404) and
/// [getSermons] falls straight through to [KharisApiSermonRepository] — the
/// live source the app already uses. That fallback is deliberate, not just
/// a safety net for once this is live: R2 is meant to eventually replace
/// scraping the API directly on-device, but this repository is wired in
/// ahead of the Worker existing so the switch is just filling in the real
/// URL — nothing else in the app needs to change on deploy day.
class R2MessagesRepository extends AbstractSermonRepository {
  R2MessagesRepository({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;
  final _fallback = KharisApiSermonRepository();

  @override
  Future<List<Sermon>> getSermons() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        kR2MessagesUrl,
        options: Options(receiveTimeout: const Duration(seconds: 10)),
      );
      final list = (res.data?['messages'] as List?) ?? const [];
      final sermons = list
          .map((m) => _mapMessage(m as Map<String, dynamic>))
          .whereType<Sermon>()
          .toList();
      // Treat an empty/malformed response the same as a failed request —
      // better to fall back to the known-good API than show an empty library.
      if (sermons.isEmpty) throw StateError('empty messages.json');
      return sermons;
    } catch (_) {
      return _fallback.getSermons();
    }
  }

  /// Offline fallback: same bundled archive the API repository uses.
  @override
  Future<List<Sermon>> loadCatalogue() => _fallback.loadCatalogue();

  // ── Mapping ────────────────────────────────────────────────────────────────
  // messages.json field names come from the Worker's own schema
  // (backend/cloudflare-worker/src/index.js), not the raw Kharis API shape.

  Sermon? _mapMessage(Map<String, dynamic> m) {
    final audioUrl = (m['audio_url'] as String? ?? '').trim();
    // Same rule as the API repository: no audio, no place in the library.
    if (audioUrl.isEmpty) return null;

    final id = (m['id'] as String? ?? '').trim();
    if (id.isEmpty) return null;

    final series = m['series'] as Map<String, dynamic>?;
    final title = (m['title'] as String? ?? '').trim();

    return Sermon(
      id: id,
      title: title,
      speaker: m['speaker'] as String? ?? '',
      audioUrl: audioUrl,
      artworkUrl: m['image_url'] as String?,
      duration: m['duration'] != null
          ? Duration(seconds: (m['duration'] as num).toInt())
          : null,
      publishedAt: DateTime.tryParse(m['date_preached'] as String? ?? ''),
      series: series?['name'] as String?,
      description: (m['description'] as String?)?.trim(),
      artworkColor: (int.tryParse(id) ?? id.hashCode).abs() % 10,
      // messages.json has no category field yet either — same series/title
      // fallback the API repository uses.
      category: series?['name'] as String? ?? sermonCategory(title),
      videoId: _youTubeId(m['video_url'] as String?),
      source: 'r2',
      transcriptUrl: _absoluteTranscriptUrl(m['transcript_url'] as String?),
    );
  }

  /// `transcript_url` in messages.json is a bucket-relative path (e.g.
  /// `transcripts/100239.txt`), not a full URL — resolve it against the same
  /// bucket `kR2MessagesUrl` came from.
  static String? _absoluteTranscriptUrl(String? relativePath) {
    if (relativePath == null || relativePath.isEmpty) return null;
    return '$kR2BucketBaseUrl/$relativePath';
  }

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
}
