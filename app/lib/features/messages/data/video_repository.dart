import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:kharis_app/core/utils/html_entities.dart';
import 'package:kharis_app/shared/models/sermon.dart';
import 'kharis_content.dart';

/// Fetches YouTube video uploads from the channel's Atom feed.
///
/// On web, routes through the Cloud Function proxy to avoid CORS.
/// On mobile, hits YouTube directly. Falls back to the embedded
/// [kharisVideos] dataset on any failure.
class VideoRepository {
  VideoRepository({Dio? dio}) : _dio = dio ?? Dio();

  static const _directFeed =
      'https://www.youtube.com/feeds/videos.xml?channel_id=$kharisChannelId';
  static const _proxyFeed =
      'https://feedproxy-qf5ohtc4tq-ew.a.run.app?source=youtube';
  static String get _feedUrl => kIsWeb ? _proxyFeed : _directFeed;

  final Dio _dio;

  /// Returns the newest YouTube uploads (shorts excluded).
  Future<List<Sermon>> getVideos() async {
    try {
      final response = await _dio.get<String>(
        _feedUrl,
        options: Options(
          headers: {'Accept': 'application/atom+xml, application/xml, text/xml'},
          responseType: ResponseType.plain,
        ),
      );
      final xml = response.data ?? '';
      final parsed = _parseAtom(xml);
      if (parsed.isNotEmpty) return parsed;
      return _fallback();
    } catch (_) {
      return _fallback();
    }
  }

  List<Sermon> _parseAtom(String xml) {
    final entries = <Sermon>[];
    // Minimal XML extraction for the Atom feed (no heavy parser dep).
    final entryBlocks = RegExp(r'<entry>(.*?)</entry>', dotAll: true)
        .allMatches(xml);
    var i = 0;
    for (final m in entryBlocks) {
      final block = m.group(1) ?? '';
      final videoId = _extract(block, r'<yt:videoId>([^<]+)</yt:videoId>');
      final title = decodeHtmlEntities(
          _extract(block, r'<title>([^<]+)</title>'));
      final published = _extract(block, r'<published>([^<]+)</published>');
      if (videoId.isEmpty) continue;
      if (title.toLowerCase().contains('#short')) continue;
      entries.add(Sermon(
        id: videoId,
        title: title,
        speaker: 'David Antwi',
        audioUrl: '',
        videoId: videoId,
        artworkUrl: 'https://img.youtube.com/vi/$videoId/hqdefault.jpg',
        publishedAt: DateTime.tryParse(published),
        source: 'youtube',
        artworkColor: i % 10,
      ));
      i++;
    }
    return entries;
  }

  String _extract(String xml, String pattern) {
    final m = RegExp(pattern).firstMatch(xml);
    return m?.group(1)?.trim() ?? '';
  }

  List<Sermon> _fallback() {
    return kharisVideos.asMap().entries.map((entry) {
      final i = entry.key;
      final v = entry.value;
      return Sermon(
        id: v['videoId'] as String,
        title: decodeHtmlEntities(v['title'] as String),
        speaker: 'David Antwi',
        audioUrl: '',
        videoId: v['videoId'] as String,
        artworkUrl: v['thumbnailUrl'] as String?,
        publishedAt: DateTime.tryParse(v['publishedAt'] as String? ?? ''),
        source: 'youtube',
        artworkColor: i % 10,
      );
    }).toList();
  }
}
