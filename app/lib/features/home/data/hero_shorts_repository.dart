import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kharis_app/core/utils/html_entities.dart';
import 'package:kharis_app/features/home/data/featured_video_repository.dart';
import 'package:kharis_app/features/messages/data/feed_fetch.dart';
import 'package:kharis_app/features/messages/data/kharis_content.dart';

/// One of the channel's YouTube Shorts, with what ranking needs.
@immutable
class HeroShort {
  const HeroShort({
    required this.videoId,
    required this.title,
    required this.seconds,
    required this.views,
    required this.publishedAt,
    required this.thumbnailUrl,
    required this.bySeniorPastor,
  });

  final String videoId;

  /// The title without its hashtags ("Have you tried fasting?").
  final String title;
  final int seconds;
  final int views;
  final DateTime? publishedAt;
  final String thumbnailUrl;

  /// Names the Senior Pastor (David Antwi) in its title, description or tags.
  final bool bySeniorPastor;

  FeaturedVideo toFeaturedVideo() => FeaturedVideo(
    workspace: 'youtube',
    url: 'https://www.youtube.com/shorts/$videoId',
    videoId: videoId,
    title: title,
    thumbnailUrl: thumbnailUrl,
    updatedAt: publishedAt,
    vertical: true,
  );

  Map<String, Object?> toJson() => {
    'videoId': videoId,
    'title': title,
    'seconds': seconds,
    'views': views,
    'publishedAt': publishedAt?.toIso8601String(),
    'thumbnailUrl': thumbnailUrl,
    'bySeniorPastor': bySeniorPastor,
  };

  static HeroShort fromJson(Map<String, dynamic> j) => HeroShort(
    videoId: j['videoId'] as String,
    title: j['title'] as String,
    seconds: j['seconds'] as int,
    views: j['views'] as int,
    publishedAt: DateTime.tryParse(j['publishedAt'] as String? ?? ''),
    thumbnailUrl: j['thumbnailUrl'] as String,
    bySeniorPastor: j['bySeniorPastor'] as bool,
  );
}

/// Shortest Short the hero plays: a sentence of preaching, not a 12-second
/// reaction clip.
const Duration kHeroShortMin = Duration(seconds: 30);

/// Oldest Short the hero plays.
const Duration kHeroShortMaxAge = Duration(days: 180);

/// How many Shorts the hero rotates.
const int kHeroShortCount = 3;

/// The hero's Shorts: the Senior Pastor's best sayings and the longer
/// preview clips, best first.
///
/// Drops anything shorter than [kHeroShortMin] or older than
/// [kHeroShortMaxAge], then scores by views (log scale, so one viral clip
/// does not drown the rest), favouring longer clips (up to 90 s), the
/// Senior Pastor, and the last two months.
List<HeroShort> pickHeroShorts(
  List<HeroShort> all, {
  required DateTime now,
  int limit = kHeroShortCount,
}) {
  double score(HeroShort s) {
    final length = 0.6 + 0.4 * math.min(s.seconds, 90) / 90;
    final pastor = s.bySeniorPastor ? 1.4 : 1.0;
    final age = now.difference(s.publishedAt ?? now);
    final fresh = age <= const Duration(days: 60) ? 1.0 : 0.8;
    return math.log(s.views + 10) * length * pastor * fresh;
  }

  final eligible = [
    for (final s in all)
      if (s.seconds >= kHeroShortMin.inSeconds &&
          now.difference(s.publishedAt ?? now) <= kHeroShortMaxAge)
        s,
  ]..sort((a, b) => score(b).compareTo(score(a)));
  return eligible.take(limit).toList();
}

/// Reads the channel's newest Shorts from the YouTube Data API (two calls:
/// the Shorts playlist, then lengths and views) and keeps them for
/// [cacheFor], so a launch normally spends no quota.
class HeroShortsRepository {
  HeroShortsRepository({
    required this.prefs,
    this.apiKey = const String.fromEnvironment('YOUTUBE_API_KEY'),
    this.fetch = fetchFeed,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  /// Read lazily: tests without an API key never touch storage.
  final SharedPreferences Function() prefs;
  final String apiKey;
  final Future<String> Function(String url) fetch;
  final DateTime Function() _clock;

  static const cacheFor = Duration(hours: 6);
  static const _cacheKey = 'hero_shorts_v2';

  /// The channel's Shorts playlist: its id with "UC" swapped for "UUSH".
  static final _shortsPlaylist = 'UUSH${kharisChannelId.substring(2)}';

  /// The ranked Shorts; empty without a key, or when YouTube and the cache
  /// both have nothing.
  Future<List<HeroShort>> getShorts() async {
    if (apiKey.isEmpty) return const [];
    final now = _clock();
    final cached = _readCache();
    if (cached != null && now.difference(cached.at) < cacheFor) {
      return pickHeroShorts(cached.items, now: now);
    }
    try {
      final fresh = await _fetchAll();
      _writeCache(now, fresh);
      return pickHeroShorts(fresh, now: now);
    } catch (_) {
      // Offline or over quota: yesterday's picks beat an empty hero.
      return pickHeroShorts(cached?.items ?? const [], now: now);
    }
  }

  Future<List<HeroShort>> _fetchAll() async {
    final list =
        jsonDecode(
              await fetch(
                Uri.https('www.googleapis.com', '/youtube/v3/playlistItems', {
                  'part': 'snippet,contentDetails',
                  'maxResults': '50',
                  'playlistId': _shortsPlaylist,
                  'key': apiKey,
                }).toString(),
              ),
            )
            as Map<String, dynamic>;
    final snippets = <String, Map<String, dynamic>>{};
    for (final item in (list['items'] as List?) ?? const []) {
      final map = item as Map<String, dynamic>;
      final id =
          (map['contentDetails'] as Map<String, dynamic>?)?['videoId']
              as String?;
      final snippet = map['snippet'] as Map<String, dynamic>?;
      if (id == null || snippet == null) continue;
      snippets[id] = snippet;
    }
    if (snippets.isEmpty) return const [];

    final details =
        jsonDecode(
              await fetch(
                Uri.https('www.googleapis.com', '/youtube/v3/videos', {
                  'part': 'contentDetails,statistics,snippet',
                  'id': snippets.keys.join(','),
                  'key': apiKey,
                }).toString(),
              ),
            )
            as Map<String, dynamic>;
    final out = <HeroShort>[];
    for (final item in (details['items'] as List?) ?? const []) {
      final map = item as Map<String, dynamic>;
      final id = map['id'] as String?;
      final snippet =
          (map['snippet'] as Map<String, dynamic>?) ?? snippets[id] ?? const {};
      if (id == null) continue;
      final rawTitle = decodeHtmlEntities(snippet['title'] as String? ?? '');
      final words = [
        rawTitle,
        snippet['description'] as String? ?? '',
        ...((snippet['tags'] as List?) ?? const []).map((t) => '$t'),
      ].join(' ').toLowerCase();
      out.add(
        HeroShort(
          videoId: id,
          title: cleanShortTitle(rawTitle),
          seconds: _isoToSeconds(
            (map['contentDetails'] as Map<String, dynamic>?)?['duration']
                    as String? ??
                '',
          ),
          views:
              int.tryParse(
                '${(map['statistics'] as Map<String, dynamic>?)?['viewCount'] ?? 0}',
              ) ??
              0,
          publishedAt: DateTime.tryParse(
            snippet['publishedAt'] as String? ?? '',
          ),
          thumbnailUrl: _thumbnail(id),
          bySeniorPastor:
              words.contains('david antwi') ||
              words.contains('davidantwi') ||
              words.contains('pastor david'),
        ),
      );
    }
    return out;
  }

  ({DateTime at, List<HeroShort> items})? _readCache() {
    try {
      final raw = prefs().getString(_cacheKey);
      if (raw == null) return null;
      final j = jsonDecode(raw) as Map<String, dynamic>;
      return (
        at: DateTime.parse(j['at'] as String),
        items: [
          for (final s in j['items'] as List)
            HeroShort.fromJson(s as Map<String, dynamic>),
        ],
      );
    } catch (_) {
      return null;
    }
  }

  void _writeCache(DateTime at, List<HeroShort> items) {
    if (items.isEmpty) return;
    prefs().setString(
      _cacheKey,
      jsonEncode({
        'at': at.toIso8601String(),
        'items': [for (final s in items) s.toJson()],
      }),
    );
  }

  static int _isoToSeconds(String iso) {
    final m = RegExp(r'PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?').firstMatch(iso);
    if (m == null) return 0;
    int part(int i) => int.tryParse(m.group(i) ?? '') ?? 0;
    return part(1) * 3600 + part(2) * 60 + part(3);
  }

  /// YouTube's full-size vertical frame for a Short (1080x1920), so the
  /// still before playback fills the hero like the clip does; the API's
  /// thumbnails are landscape with blurred side bands.
  static String _thumbnail(String id) =>
      'https://i.ytimg.com/vi/$id/oardefault.jpg';
}

/// A Short's title for the hero card: hashtags and "#shorts" noise removed,
/// spacing tidied ("Have you tried fasting? #shorts #davidantwi" → "Have you
/// tried fasting?").
String cleanShortTitle(String raw) => raw
    .replaceAll(RegExp(r'#\S+'), '')
    .replaceAll(RegExp(r'\s+'), ' ')
    .replaceAllMapped(RegExp(r'\s+([?!.,])'), (m) => m[1]!)
    .trim();
