import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'package:kharis_app/core/constants/http_constants.dart';

/// A curated playlist or a sermon series from the Kharis public API.
enum CollectionKind { playlist, series }

@immutable
class SermonCollection {
  const SermonCollection({
    required this.id,
    required this.name,
    required this.kind,
    this.description,
    this.imageUrl,
  });

  final int id;
  final String name;
  final CollectionKind kind;
  final String? description;
  final String? imageUrl;
}

/// Fetches playlists + series from the Kharis public API.
///
/// A browser [kBrowserUserAgent] is required (the host is behind Cloudflare bot
/// protection — 403 otherwise). NOTE: the API's `?series=` / `?playlist=`
/// filters are ignored server-side and the detail endpoints don't embed
/// sermons, so a collection's sermons are matched client-side by series name
/// against the loaded library (see docs/INTEGRATION_ISSUES.md). Returns an empty
/// list on failure so the Playlists screen falls back to its built-in set.
class SermonCollectionsRepository {
  SermonCollectionsRepository({Dio? dio})
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

  Future<List<SermonCollection>> playlists() =>
      _fetch('playlists/', CollectionKind.playlist);

  Future<List<SermonCollection>> series() =>
      _fetch('series/', CollectionKind.series);

  Future<List<SermonCollection>> _fetch(String path, CollectionKind kind) async {
    try {
      final out = <SermonCollection>[];
      String? url = '$path?page_size=100';
      var guard = 0;
      while (url != null && guard < 6) {
        final res = await _dio.get<Map<String, dynamic>>(url);
        final results = (res.data?['results'] as List?) ?? const [];
        for (final r in results.whereType<Map<String, dynamic>>()) {
          final id = (r['id'] as num?)?.toInt();
          final name = (r['name'] as String?)?.trim();
          if (id == null || name == null || name.isEmpty) continue;
          out.add(SermonCollection(
            id: id,
            name: name,
            kind: kind,
            description: (r['description'] as String?)?.trim(),
            imageUrl: r['image_url'] as String?,
          ));
        }
        final next = res.data?['next'] as String?;
        url = (next == null || next.isEmpty)
            ? null
            : (next.startsWith('http')
                ? next
                : 'https://${next.replaceFirst(RegExp(r'^/+'), '')}');
        guard++;
      }
      return out;
    } catch (_) {
      return const [];
    }
  }
}
