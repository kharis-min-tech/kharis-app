import 'package:dio/dio.dart';

import 'package:kharis_app/core/utils/html_entities.dart';

import 'package:kharis_app/shared/models/sermon.dart';
import 'kharis_content.dart';
import 'sermon_repository_base.dart';

/// Fetches sermons from the Kharis SoundCloud RSS feed.
///
/// On any network or CORS failure falls back to [getMockSermons], which
/// returns the real Kharis dataset from [kharisAudioSermons] so the list is
/// never empty and never contains fake titles.
class SermonRepository extends AbstractSermonRepository {
  SermonRepository({Dio? dio}) : _dio = dio ?? Dio();

  static const _feedUrl =
      'https://feeds.soundcloud.com/users/soundcloud:users:58625221/sounds.rss';

  final Dio _dio;

  /// Live fetch from SoundCloud RSS; falls back to real dataset on any error.
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
      if (parsed.isNotEmpty) return parsed;
      return getMockSermons();
    } catch (_) {
      return getMockSermons();
    }
  }

  /// Real Kharis dataset — used as the guaranteed fallback.
  @override
  List<Sermon> getMockSermons() => _realSermons;

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
        category: _inferCategory(title),
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

  String? _inferCategory(String title) {
    final t = title.toLowerCase();
    if (t.contains('faith') || t.contains('believe')) return 'Faith';
    if (t.contains('prayer') || t.contains('pray') || t.contains('fast')) {
      return 'Prayer';
    }
    if (t.contains('worship')) return 'Worship';
    if (t.contains('grace') || t.contains('mercy')) return 'Grace';
    if (t.contains('holy') || t.contains('spirit')) return 'Holy Spirit';
    return 'Messages';
  }

  String _inferSpeaker(String title) {
    if (title.contains('Awo Antwi')) return 'Awo Antwi';
    return 'David Antwi';
  }

  // ── Real fallback dataset ──────────────────────────────────────────────────

  static final List<Sermon> _realSermons = kharisAudioSermons
      .asMap()
      .entries
      .map((entry) {
        final i = entry.key;
        final m = entry.value;
        return Sermon(
          id: 'sc_${i}_${(m['audioUrl'] as String).hashCode.abs()}',
          title: m['title'] as String,
          speaker: m['speaker'] as String,
          audioUrl: m['audioUrl'] as String,
          artworkUrl: m['artworkUrl'] as String?,
          duration: Duration(seconds: m['durationSeconds'] as int),
          publishedAt: DateTime.tryParse(m['publishedAt'] as String),
          artworkColor: i % 10,
          category: _staticInferCategory(m['title'] as String),
          source: 'soundcloud',
        );
      })
      .toList();

  static String? _staticInferCategory(String title) {
    final t = title.toLowerCase();
    if (t.contains('faith') || t.contains('believe')) return 'Faith';
    if (t.contains('prayer') || t.contains('pray') || t.contains('fast')) {
      return 'Prayer';
    }
    if (t.contains('worship')) return 'Worship';
    if (t.contains('grace') || t.contains('mercy')) return 'Grace';
    if (t.contains('holy') || t.contains('spirit')) return 'Holy Spirit';
    return 'Messages';
  }
}
