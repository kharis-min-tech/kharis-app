import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show rootBundle;

import 'package:kharis_app/core/utils/html_entities.dart';
import 'package:kharis_app/core/utils/sermon_categorizer.dart';
import 'package:kharis_app/shared/models/sermon.dart';
import 'sermon_repository_base.dart';

/// Fetches sermons from the Kharis SoundCloud RSS feed.
///
/// On any network or CORS failure falls back to [loadCatalogue] - the full
/// 500-episode catalogue bundled at assets/data/kharis_sermons.json - so the
/// library is always complete, never empty, never fake.
class SermonRepository extends AbstractSermonRepository {
  SermonRepository({Dio? dio}) : _dio = dio ?? Dio();

  /// On web, CORS blocks the direct SoundCloud feed; route through the
  /// Firebase Cloud Function proxy instead. On mobile, hit SoundCloud direct
  /// (lower latency, no function cost). The proxy caches upstream for 5 min.
  static const _directFeed =
      'https://feeds.soundcloud.com/users/soundcloud:users:58625221/sounds.rss';
  static const _proxyFeed =
      'https://feedproxy-qf5ohtc4tq-ew.a.run.app?source=soundcloud';
  static String get _feedUrl =>
      kIsWeb ? _proxyFeed : _directFeed;

  final Dio _dio;

  /// Live fetch from SoundCloud RSS merged over the bundled catalogue.
  ///
  /// The RSS feed only exposes the newest 500 episodes, so it provides
  /// freshness while the bundled catalogue (1,470+ back to 2013) provides
  /// depth. Titles are deduped, RSS entries win. On any failure the full
  /// catalogue alone is returned.
  @override
  Future<List<Sermon>> getSermons() async {
    try {
      final response = await _dio.get<String>(
        _feedUrl,
        options: Options(
          headers: {'Accept': 'application/rss+xml, application/xml, text/xml'},
          responseType: ResponseType.plain,
        ),
      );
      final xml = response.data ?? '';
      final parsed = _parseRss(xml);
      final catalogue = await loadCatalogue();
      if (parsed.isEmpty) return catalogue;
      final seen = {for (final s in parsed) _titleKey(s.title)};
      return [
        ...parsed,
        ...catalogue.where((s) => seen.add(_titleKey(s.title))),
      ];
    } catch (_) {
      return loadCatalogue();
    }
  }

  static String _titleKey(String title) =>
      title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  /// Loads the bundled full catalogue (one-time, cached for the session).
  ///
  /// Regenerate the asset with `scripts/fetch_sermon_feed.py` before release
  /// to pick up new episodes for web builds (mobile gets them live via RSS).
  @override
  Future<List<Sermon>> loadCatalogue() async {
    if (_catalogueCache != null) return _catalogueCache!;
    final raw =
        await rootBundle.loadString('assets/data/kharis_sermons.json');
    final data = jsonDecode(raw) as Map<String, dynamic>;
    final episodes = (data['episodes'] as List).cast<Map<String, dynamic>>();
    _catalogueCache = [
      for (final (i, m) in episodes.indexed)
        Sermon(
          id: 'sc_${i}_${(m['audioUrl'] as String).hashCode.abs()}',
          title: m['title'] as String,
          speaker: m['speaker'] as String? ?? 'David Antwi',
          audioUrl: m['audioUrl'] as String,
          artworkUrl: m['artworkUrl'] as String?,
          duration: Duration(seconds: (m['durationSeconds'] as num).toInt()),
          publishedAt: DateTime.tryParse(m['publishedAt'] as String? ?? ''),
          description: m['description'] as String?,
          artworkColor: i % 10,
          category: sermonCategory(m['title'] as String),
          source: 'soundcloud',
        ),
    ];
    return _catalogueCache!;
  }

  static List<Sermon>? _catalogueCache;

  // ── RSS parser ─────────────────────────────────────────────────────────────

  List<Sermon> _parseRss(String xml) {
    final items = _extractAll(xml, 'item');
    final sermons = <Sermon>[];
    var index = 0;

    for (final item in items) {
      final title = _extractText(item, 'title');
      final description = _extractText(item, 'description');
      final audioUrl = _extractAttribute(item, 'enclosure', 'url');
      final durationRaw = _extractText(item, 'itunes:duration');
      final pubDateRaw = _extractText(item, 'pubDate');
      final guid = _extractText(item, 'guid');
      final itunesImage = _extractAttribute(item, 'itunes:image', 'href');

      if (audioUrl.isEmpty) continue;

      sermons.add(Sermon(
        id: guid.isNotEmpty ? guid : 'sermon_$index',
        title: title.isNotEmpty ? _stripCdata(title) : 'Untitled',
        speaker: _inferSpeaker(title),
        description: _stripCdata(description),
        audioUrl: audioUrl,
        artworkUrl: itunesImage.isNotEmpty ? itunesImage : null,
        duration: _parseDuration(durationRaw),
        publishedAt: _parsePubDate(pubDateRaw),
        artworkColor: index % 10,
        category: sermonCategory(title),
        source: 'soundcloud',
      ));
      index++;
    }

    return sermons;
  }

  // ── XML helpers ────────────────────────────────────────────────────────────

  List<String> _extractAll(String xml, String tag) {
    final results = <String>[];
    final open = '<$tag>';
    final close = '</$tag>';
    var start = 0;
    while (true) {
      final s = xml.indexOf(open, start);
      if (s == -1) break;
      final e = xml.indexOf(close, s);
      if (e == -1) break;
      results.add(xml.substring(s + open.length, e));
      start = e + close.length;
    }
    return results;
  }

  String _extractText(String xml, String tag) {
    final cdataPattern = '<$tag><![CDATA[';
    final cs = xml.indexOf(cdataPattern);
    if (cs != -1) {
      final ce = xml.indexOf(']]></$tag>', cs);
      if (ce != -1) return xml.substring(cs + cdataPattern.length, ce);
    }
    final open = '<$tag>';
    final close = '</$tag>';
    final s = xml.indexOf(open);
    if (s == -1) return '';
    final e = xml.indexOf(close, s);
    if (e == -1) return '';
    return xml.substring(s + open.length, e).trim();
  }

  String _extractAttribute(String xml, String tag, String attr) {
    final tagPattern = RegExp('<$tag[^>]*>');
    final match = tagPattern.firstMatch(xml);
    if (match == null) return '';
    final tagStr = match.group(0) ?? '';
    final attrPattern = RegExp('$attr="([^"]*)"');
    final attrMatch = attrPattern.firstMatch(tagStr);
    return attrMatch?.group(1) ?? '';
  }

  String _stripCdata(String value) {
    return decodeHtmlEntities(
      value
          .replaceAll('<![CDATA[', '')
          .replaceAll(']]>', '')
          .replaceAll(RegExp(r'<[^>]+>'), '')
          .trim(),
    );
  }

  /// Parses HH:MM:SS or MM:SS or raw seconds into a [Duration].
  Duration? _parseDuration(String raw) {
    if (raw.isEmpty) return null;
    final parts = raw.split(':');
    int seconds;
    if (parts.length == 3) {
      seconds = (int.tryParse(parts[0]) ?? 0) * 3600 +
          (int.tryParse(parts[1]) ?? 0) * 60 +
          (int.tryParse(parts[2]) ?? 0);
    } else if (parts.length == 2) {
      seconds = (int.tryParse(parts[0]) ?? 0) * 60 +
          (int.tryParse(parts[1]) ?? 0);
    } else {
      seconds = int.tryParse(raw) ?? 0;
    }
    return Duration(seconds: seconds);
  }

  DateTime? _parsePubDate(String raw) {
    if (raw.isEmpty) return null;
    try {
      return DateTime.parse(raw);
    } catch (_) {
      return null;
    }
  }



  String _inferSpeaker(String title) {
    if (title.contains('Awo Antwi')) return 'Awo Antwi';
    return 'David Antwi';
  }



}
