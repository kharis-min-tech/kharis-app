import 'package:dio/dio.dart';

import '../../../shared/models/sermon.dart';

/// Fetches sermons from the Kharis SoundCloud RSS feed.
///
/// Falls back to [getMockSermons] during offline development or when the
/// network is unavailable.
class SermonRepository {
  SermonRepository({Dio? dio}) : _dio = dio ?? Dio();

  static const _feedUrl =
      'https://feeds.soundcloud.com/users/soundcloud:users:58625221/sounds.rss';

  final Dio _dio;

  /// Live fetch from SoundCloud RSS.
  Future<List<Sermon>> getSermons() async {
    final response = await _dio.get<String>(
      _feedUrl,
      options: Options(
        headers: {'Accept': 'application/rss+xml, application/xml, text/xml'},
        responseType: ResponseType.plain,
      ),
    );

    final xml = response.data ?? '';
    return _parseRss(xml);
  }

  /// 10 hardcoded sermons for offline development.
  List<Sermon> getMockSermons() => _mockSermons;

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

      if (audioUrl.isEmpty) continue;

      sermons.add(Sermon(
        id: guid.isNotEmpty ? guid : 'sermon_$index',
        title: title.isNotEmpty ? _stripCdata(title) : 'Untitled',
        speaker: 'Kharis Ministries',
        description: _stripCdata(description),
        audioUrl: audioUrl,
        duration: _parseDuration(durationRaw),
        publishedAt: _parsePubDate(pubDateRaw),
        artworkColor: index % 10,
        category: _inferCategory(title),
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
    return value
        .replaceAll('<![CDATA[', '')
        .replaceAll(']]>', '')
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .trim();
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
    if (t.contains('prayer') || t.contains('pray')) return 'Prayer';
    if (t.contains('worship')) return 'Worship';
    if (t.contains('grace') || t.contains('mercy')) return 'Grace';
    if (t.contains('holy') || t.contains('spirit')) return 'Holy Spirit';
    return 'Messages';
  }

  // ── Mock data ──────────────────────────────────────────────────────────────

  static final _mockSermons = [
    Sermon(
      id: 'mock_1',
      title: 'Walking in Faith',
      speaker: 'Pastor Kharis',
      description:
          'A message about the foundation of faith and how it transforms our daily walk with God.',
      audioUrl: 'https://example.com/sermons/walking-in-faith.mp3',
      duration: const Duration(seconds: 3720),
      publishedAt: DateTime(2024, 12, 1),
      artworkColor: 0,
      category: 'Faith',
    ),
    Sermon(
      id: 'mock_2',
      title: 'The Power of Prayer',
      speaker: 'Pastor Kharis',
      description:
          'Discover how persistent prayer opens doors and changes circumstances.',
      audioUrl: 'https://example.com/sermons/power-of-prayer.mp3',
      duration: const Duration(seconds: 4140),
      publishedAt: DateTime(2024, 11, 24),
      artworkColor: 1,
      category: 'Prayer',
    ),
    Sermon(
      id: 'mock_3',
      title: 'Grace Unending',
      speaker: 'Pastor Kharis',
      description:
          "Understanding the depth and breadth of God's grace in our lives.",
      audioUrl: 'https://example.com/sermons/grace-unending.mp3',
      duration: const Duration(seconds: 2880),
      publishedAt: DateTime(2024, 11, 17),
      artworkColor: 2,
      category: 'Grace',
    ),
    Sermon(
      id: 'mock_4',
      title: 'Holy Spirit: Our Guide',
      speaker: 'Pastor Kharis',
      description:
          'How the Holy Spirit leads, comforts, and empowers believers.',
      audioUrl: 'https://example.com/sermons/holy-spirit-guide.mp3',
      duration: const Duration(seconds: 5100),
      publishedAt: DateTime(2024, 11, 10),
      artworkColor: 3,
      category: 'Holy Spirit',
    ),
    Sermon(
      id: 'mock_5',
      title: 'Worship as a Lifestyle',
      speaker: 'Pastor Kharis',
      description:
          'Moving worship beyond Sunday mornings into every area of life.',
      audioUrl: 'https://example.com/sermons/worship-lifestyle.mp3',
      duration: const Duration(seconds: 3300),
      publishedAt: DateTime(2024, 11, 3),
      artworkColor: 4,
      category: 'Worship',
    ),
    Sermon(
      id: 'mock_6',
      title: 'Renewed Mind',
      speaker: 'Pastor Kharis',
      description:
          'The transformation that comes when we align our thinking with Scripture.',
      audioUrl: 'https://example.com/sermons/renewed-mind.mp3',
      duration: const Duration(seconds: 3960),
      publishedAt: DateTime(2024, 10, 27),
      artworkColor: 5,
      category: 'Messages',
    ),
    Sermon(
      id: 'mock_7',
      title: 'Purpose and Calling',
      speaker: 'Pastor Kharis',
      description: 'Discovering and stepping into your God-given purpose.',
      audioUrl: 'https://example.com/sermons/purpose-calling.mp3',
      duration: const Duration(seconds: 4500),
      publishedAt: DateTime(2024, 10, 20),
      artworkColor: 6,
      category: 'Messages',
    ),
    Sermon(
      id: 'mock_8',
      title: 'Mercy Never Fails',
      speaker: 'Pastor Kharis',
      description:
          "God's mercy endures through every season — even the darkest ones.",
      audioUrl: 'https://example.com/sermons/mercy-never-fails.mp3',
      duration: const Duration(seconds: 3600),
      publishedAt: DateTime(2024, 10, 13),
      artworkColor: 7,
      category: 'Grace',
    ),
    Sermon(
      id: 'mock_9',
      title: 'Faith Over Fear',
      speaker: 'Pastor Kharis',
      description:
          "Practical steps to replace anxiety with trust in God's promises.",
      audioUrl: 'https://example.com/sermons/faith-over-fear.mp3',
      duration: const Duration(seconds: 2760),
      publishedAt: DateTime(2024, 10, 6),
      artworkColor: 8,
      category: 'Faith',
    ),
    Sermon(
      id: 'mock_10',
      title: 'Kingdom Perspective',
      speaker: 'Pastor Kharis',
      description:
          "Seeing every situation through the lens of God's eternal kingdom.",
      audioUrl: 'https://example.com/sermons/kingdom-perspective.mp3',
      duration: const Duration(seconds: 4200),
      publishedAt: DateTime(2024, 9, 29),
      artworkColor: 9,
      category: 'Messages',
    ),
  ];
}
