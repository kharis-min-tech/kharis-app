import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import 'package:kharis_app/core/utils/sermon_categorizer.dart';
import 'package:kharis_app/shared/models/sermon.dart';
import 'sermon_repository_base.dart';

/// Offline fallback catalogue for the sermon library.
///
/// The live library is served by `KharisApiSermonRepository`
/// (yetanothersermon.host). This repository only provides the bundled archive
/// at `assets/data/kharis_sermons.json` (a SoundCloud snapshot), so the
/// Messages surface is never empty when the network is unavailable.
class SermonRepository extends AbstractSermonRepository {
  SermonRepository();

  static List<Sermon>? _catalogueCache;

  /// The bundled archive is one terminal page.
  @override
  Future<SermonPage> fetchPage({String? url, String? search}) async {
    final all = await loadCatalogue();
    return SermonPage(sermons: all, totalCount: all.length);
  }

  /// Loads the bundled archive (one-time, cached for the session).
  @override
  Future<List<Sermon>> loadCatalogue() async {
    if (_catalogueCache != null) return _catalogueCache!;
    final raw = await rootBundle.loadString('assets/data/kharis_sermons.json');
    final data = jsonDecode(raw) as Map<String, dynamic>;
    final episodes = (data['episodes'] as List).cast<Map<String, dynamic>>();
    _catalogueCache = [
      for (final (i, m) in episodes.indexed)
        Sermon(
          id: archiveSermonId(m['audioUrl'] as String),
          title: m['title'] as String,
          speaker: m['speaker'] as String? ?? 'David Antwi',
          audioUrl: m['audioUrl'] as String,
          artworkUrl: m['artworkUrl'] as String?,
          duration: Duration(seconds: (m['durationSeconds'] as num).toInt()),
          publishedAt: DateTime.tryParse(m['publishedAt'] as String? ?? ''),
          description: m['description'] as String?,
          artworkColor: i % 10,
          category: sermonCategory(
            m['title'] as String,
            description: m['description'] as String?,
          ),
          source: 'archive',
        ),
    ];
    return _catalogueCache!;
  }
}

/// Stable id for a bundled-archive episode, built from its audio URL so it
/// survives reordering of the asset (a playlist or recently-played entry keeps
/// resolving). SoundCloud stream paths start with the numeric track id
/// (`/stream/2339300339-kharismedia-...mp3`); anything else uses the whole
/// last path segment.
String archiveSermonId(String audioUrl) {
  final segments = Uri.tryParse(audioUrl)?.pathSegments ?? const <String>[];
  final last = segments.where((s) => s.isNotEmpty).lastOrNull ?? audioUrl;
  final track = RegExp(r'^\d+').firstMatch(last)?.group(0);
  return 'archive_${track ?? last.replaceAll(RegExp(r'\.mp3$'), '')}';
}
