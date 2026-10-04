import 'dart:convert';

import 'package:kharis_app/core/utils/html_entities.dart';
import 'package:kharis_app/shared/models/sermon.dart';
import 'feed_fetch.dart';
import 'kharis_content.dart';

/// Fetches the channel's latest YouTube uploads, freshest first.
///
/// Primary source is the YouTube Data API v3. Unlike the Atom feed, the API
/// sends permissive CORS headers, so the list is genuinely live on web and
/// mobile alike. It also exposes durations, letting us drop Shorts reliably
/// (a featured message must always be a full sermon, never a 30s clip).
///
/// Falls back to the public Atom feed, then to the embedded [kharisVideos]
/// dataset, when the API is unreachable or no key is configured.
class VideoRepository {
  VideoRepository();

  /// Injected at build time via --dart-define-from-file=env.json. Never baked.
  static const _apiKey = String.fromEnvironment('YOUTUBE_API_KEY');

  /// Uploads playlist = channel id with the leading "UC" swapped for "UU".
  static const _uploadsPlaylist = 'UU4l8WmdF9ivMDQHHVOdYKqQ';

  static const _atomFeedUrl =
      'https://www.youtube.com/feeds/videos.xml?channel_id=$kharisChannelId';

  /// Shortest run-time (seconds) we treat as a real sermon. Anything below is
  /// a Short or music clip and is excluded.
  static const _minSermonSeconds = 120;

  /// Returns the newest YouTube uploads (Shorts excluded), freshest first.
  Future<List<Sermon>> getVideos() async {
    if (_apiKey.isNotEmpty) {
      try {
        final videos = await _fetchFromDataApi();
        if (videos.isNotEmpty) return videos;
      } catch (_) {
        // Fall through to the Atom feed.
      }
    }
    try {
      final xml = await fetchFeed(_atomFeedUrl);
      final parsed = _parseAtom(xml);
      if (parsed.isNotEmpty) return parsed;
    } catch (_) {
      // Fall through to the static dataset.
    }
    return _fallback();
  }

  // ── YouTube Data API v3 ───────────────────────────────────────────────────

  Future<List<Sermon>> _fetchFromDataApi() async {
    final listUrl =
        Uri.parse('https://www.googleapis.com/youtube/v3/playlistItems')
            .replace(
              queryParameters: {
                'part': 'snippet,contentDetails',
                'maxResults': '20',
                'playlistId': _uploadsPlaylist,
                'key': _apiKey,
              },
            )
            .toString();

    final body = await fetchFeed(listUrl);
    final json = jsonDecode(body) as Map<String, dynamic>;
    final items = (json['items'] as List?) ?? const [];

    // Collect candidate video ids (in feed order) and their snippets.
    final ordered = <String>[];
    final snippets = <String, Map<String, dynamic>>{};
    for (final item in items) {
      final map = item as Map<String, dynamic>;
      final snippet = map['snippet'] as Map<String, dynamic>?;
      final videoId =
          (map['contentDetails'] as Map<String, dynamic>?)?['videoId']
              as String?;
      if (snippet == null || videoId == null || videoId.isEmpty) continue;
      final title = snippet['title'] as String? ?? '';
      if (title == 'Private video' || title == 'Deleted video') continue;
      ordered.add(videoId);
      snippets[videoId] = snippet;
    }
    if (ordered.isEmpty) return const [];

    // Resolve durations so Shorts/clips can be filtered out reliably.
    final durations = await _fetchDurations(ordered);

    final out = <Sermon>[];
    var i = 0;
    for (final videoId in ordered) {
      final secs = durations[videoId];
      if (secs != null && secs < _minSermonSeconds) continue;
      final snippet = snippets[videoId]!;
      final rawTitle = decodeHtmlEntities(snippet['title'] as String? ?? '');
      if (_isShort(rawTitle)) continue;
      final (title, speaker) = splitVideoTitle(rawTitle);
      out.add(
        Sermon(
          id: videoId,
          title: title,
          speaker: speaker,
          audioUrl: '',
          videoId: videoId,
          artworkUrl: _thumbnail(snippet, videoId),
          duration: secs != null ? Duration(seconds: secs) : null,
          publishedAt: DateTime.tryParse(
            snippet['publishedAt'] as String? ?? '',
          ),
          source: 'youtube',
          artworkColor: i % 10,
        ),
      );
      i++;
    }
    return out;
  }

  Future<Map<String, int>> _fetchDurations(List<String> ids) async {
    try {
      final url = Uri.parse('https://www.googleapis.com/youtube/v3/videos')
          .replace(
            queryParameters: {
              'part': 'contentDetails',
              'id': ids.join(','),
              'key': _apiKey,
            },
          )
          .toString();
      final body = await fetchFeed(url);
      final json = jsonDecode(body) as Map<String, dynamic>;
      final items = (json['items'] as List?) ?? const [];
      final out = <String, int>{};
      for (final item in items) {
        final map = item as Map<String, dynamic>;
        final id = map['id'] as String?;
        final iso =
            (map['contentDetails'] as Map<String, dynamic>?)?['duration']
                as String?;
        if (id != null && iso != null) out[id] = _isoToSeconds(iso);
      }
      return out;
    } catch (_) {
      // Without durations we keep everything and rely on the title heuristic.
      return const {};
    }
  }

  /// Parses an ISO-8601 duration (e.g. PT1H2M3S) into seconds.
  static int _isoToSeconds(String iso) {
    final m = RegExp(r'PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?').firstMatch(iso);
    if (m == null) return 0;
    final h = int.tryParse(m.group(1) ?? '') ?? 0;
    final min = int.tryParse(m.group(2) ?? '') ?? 0;
    final s = int.tryParse(m.group(3) ?? '') ?? 0;
    return h * 3600 + min * 60 + s;
  }

  String _thumbnail(Map<String, dynamic> snippet, String videoId) {
    final thumbs = snippet['thumbnails'] as Map<String, dynamic>?;
    final best =
        thumbs?['maxres'] ??
        thumbs?['standard'] ??
        thumbs?['high'] ??
        thumbs?['medium'];
    final url = (best as Map<String, dynamic>?)?['url'] as String?;
    return url ?? 'https://img.youtube.com/vi/$videoId/hqdefault.jpg';
  }

  // ── Atom feed fallback ──────────────────────────────────────────────────────

  List<Sermon> _parseAtom(String xml) {
    final entries = <Sermon>[];
    final entryBlocks = RegExp(
      r'<entry>(.*?)</entry>',
      dotAll: true,
    ).allMatches(xml);
    var i = 0;
    for (final m in entryBlocks) {
      final block = m.group(1) ?? '';
      final videoId = _extract(block, r'<yt:videoId>([^<]+)</yt:videoId>');
      final rawTitle = decodeHtmlEntities(
        _extract(block, r'<title>([^<]+)</title>'),
      );
      final published = _extract(block, r'<published>([^<]+)</published>');
      if (videoId.isEmpty) continue;
      if (_isShort(rawTitle) || _hasClipMarker(block)) continue;
      final (title, speaker) = splitVideoTitle(rawTitle);
      entries.add(
        Sermon(
          id: videoId,
          title: title,
          speaker: speaker,
          audioUrl: '',
          videoId: videoId,
          artworkUrl: 'https://img.youtube.com/vi/$videoId/hqdefault.jpg',
          publishedAt: DateTime.tryParse(published),
          source: 'youtube',
          artworkColor: i % 10,
        ),
      );
      i++;
    }
    return entries;
  }

  /// Title-based Short/clip detection (used by both API and Atom paths).
  bool _isShort(String title) {
    final t = title.toLowerCase();
    if (t.contains('#short')) return true;
    const clipMarkers = ['🎶', '🎵', '#worship', '#gospelmusic', '#praise'];
    return clipMarkers.any(t.contains);
  }

  bool _hasClipMarker(String block) {
    final b = block.toLowerCase();
    return b.contains('#shorts');
  }

  String _extract(String xml, String pattern) {
    final m = RegExp(pattern).firstMatch(xml);
    return m?.group(1)?.trim() ?? '';
  }

  List<Sermon> _fallback() {
    return kharisVideos.asMap().entries.map((entry) {
      final i = entry.key;
      final v = entry.value;
      final (title, speaker) = splitVideoTitle(
        decodeHtmlEntities(v['title'] as String),
      );
      return Sermon(
        id: v['videoId'] as String,
        title: title,
        speaker: speaker,
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

/// Speaker shown for a channel upload whose title names no preacher.
const String kChannelSpeaker = 'Kharis Church';

/// Splits a channel upload title such as
/// `The LOGOS Became Flesh | John 1:14 | David Antwi | Kharis Phase Two`
/// into the message title (first segment) and the preacher (the last segment
/// that reads as a person's name). Falls back to [kChannelSpeaker] rather
/// than guessing a preacher.
(String, String) splitVideoTitle(String raw) {
  final parts = [
    for (final p in raw.split('|'))
      if (p.trim().isNotEmpty) p.trim(),
  ];
  if (parts.length < 2) return (raw.trim(), kChannelSpeaker);
  final speaker = parts
      .skip(1)
      .lastWhere(_looksLikePerson, orElse: () => kChannelSpeaker);
  return (parts.first, speaker);
}

/// A title segment that names a person: two to five words, no digits, and
/// not a channel, series or episode label.
bool _looksLikePerson(String segment) {
  if (RegExp(r'\d').hasMatch(segment)) return false;
  final lower = segment.toLowerCase();
  const notPeople = ['kharis', 'series', 'church', 'service', 'live', 'phase'];
  if (notPeople.any(lower.contains)) return false;
  final words = segment.split(RegExp(r'\s+'));
  return words.length >= 2 && words.length <= 5;
}
