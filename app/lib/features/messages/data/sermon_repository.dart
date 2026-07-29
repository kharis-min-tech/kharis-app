import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import 'package:kharis_app/core/utils/sermon_categorizer.dart';
import 'package:kharis_app/shared/models/sermon.dart';
import 'sermon_repository_base.dart';

/// Offline fallback catalogue for the sermon library.
///
/// The live library is served by `KharisApiSermonRepository`
/// (yetanothersermon.host). This repository only provides the bundled archive
/// at `assets/data/kharis_sermons.json` so the Messages surface is never empty
/// when the network is unavailable.
///
/// (Formerly fetched the Kharis SoundCloud RSS feed — that live SoundCloud
/// source has been removed in favour of the public sermon API.)
class SermonRepository extends AbstractSermonRepository {
  SermonRepository();

  static List<Sermon>? _catalogueCache;

  /// No live source here — returns the bundled archive.
  @override
  Future<List<Sermon>> getSermons() => loadCatalogue();

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
          id: 'archive_${i}_${(m['audioUrl'] as String).hashCode.abs()}',
          title: m['title'] as String,
          speaker: m['speaker'] as String? ?? 'David Antwi',
          audioUrl: m['audioUrl'] as String,
          artworkUrl: m['artworkUrl'] as String?,
          duration: Duration(seconds: (m['durationSeconds'] as num).toInt()),
          publishedAt: DateTime.tryParse(m['publishedAt'] as String? ?? ''),
          description: m['description'] as String?,
          artworkColor: i % 10,
          category: sermonCategory(m['title'] as String),
          source: 'archive',
        ),
    ];
    return _catalogueCache!;
  }
}
