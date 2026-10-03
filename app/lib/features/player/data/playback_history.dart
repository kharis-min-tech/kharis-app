import 'package:flutter/foundation.dart';

import 'package:kharis_app/core/services/cache_service.dart';
import 'package:kharis_app/features/notes/data/note_timeline_key.dart';
import 'package:kharis_app/shared/models/sermon.dart';

/// A message the member started and has not finished.
@immutable
class UnfinishedPlay {
  const UnfinishedPlay({
    required this.sermon,
    required this.position,
    this.duration,
  });

  final Sermon sermon;
  final Duration position;

  /// Null when neither the catalogue nor a player ever reported a length.
  final Duration? duration;

  /// Fraction listened, or null when the length is unknown.
  double? get progress {
    final total = duration?.inMilliseconds ?? 0;
    if (total <= 0) return null;
    return (position.inMilliseconds / total).clamp(0.0, 1.0);
  }
}

/// Resume points, "Recently played" and the sermon snapshots that let recents
/// resolve before the archive has hydrated. Shared by the audio engine and
/// the video engine so both write ONE history for a message.
///
/// Positions are stored under every key a message can be looked up by: the
/// raw [Sermon.id] of the variant that played and its [NoteTimelineKey]
/// canonical (`yt_<videoId>` when it has a video). Audio and video variants
/// of one message therefore share a single resume point, whichever engine
/// played last.
class PlaybackHistory {
  PlaybackHistory(this._cache);

  final CacheService _cache;

  /// Preference key of the snapshot list (read by `sermonByIdProvider`).
  static const String snapshotsKey = 'recent_sermon_snapshots';

  /// Snapshots kept, newest first.
  static const int maxSnapshots = 30;

  /// Positions at or under this are "not really started" and never resumed.
  static const Duration resumeFloor = Duration(seconds: 10);

  /// A saved position this close to the end counts as finished.
  static const Duration endGuard = Duration(seconds: 15);

  static List<String> _keys(Sermon sermon) {
    final canonical = NoteTimelineKey.of(sermon).canonical;
    return canonical == sermon.id ? [sermon.id] : [canonical, sermon.id];
  }

  // ── Positions ──────────────────────────────────────────────────────────────

  /// Persists [position] for [sermon] when it is past [resumeFloor].
  void savePosition(Sermon sermon, Duration position) {
    if (position <= resumeFloor) return;
    _write(sermon, position.inMilliseconds);
  }

  /// Forgets the resume point, e.g. after the message played to the end.
  void clearPosition(Sermon sermon) => _write(sermon, 0);

  void _write(Sermon sermon, int ms) {
    for (final key in _keys(sermon)) {
      _cache.cachePlaybackPosition(key, ms);
    }
  }

  /// The last saved position, or zero. The canonical key wins; the raw id is
  /// the fallback for positions saved before keys were shared.
  Duration savedPosition(Sermon sermon) {
    for (final key in _keys(sermon)) {
      final ms = _cache.getPlaybackPosition(key);
      if (ms > 0) return Duration(milliseconds: ms);
    }
    return Duration.zero;
  }

  /// Where playback of [sermon] should pick up, or null to start from the
  /// top. [duration] guards against resuming in the closing seconds; when it
  /// is unknown any position past [resumeFloor] is resumed.
  Duration? resumePoint(Sermon sermon, [Duration? duration]) {
    final saved = savedPosition(sermon);
    if (saved <= resumeFloor) return null;
    final total = duration ?? sermon.duration;
    if (total != null && total > Duration.zero && saved >= total - endGuard) {
      return null;
    }
    return saved;
  }

  // ── Recently played ────────────────────────────────────────────────────────

  /// Records a real play: "Recently played" order plus a snapshot of the
  /// sermon, so the entry resolves even before the catalogue has loaded.
  void recordPlay(Sermon sermon) {
    _cache.addRecentlyPlayed(sermon.id);
    _upsertSnapshot(sermon, moveToFront: true);
  }

  /// Fills in a length the catalogue did not know, once a player reports it.
  void rememberDuration(Sermon sermon, Duration duration) {
    if (duration <= Duration.zero || sermon.duration != null) return;
    final snapshots = _rawSnapshots();
    final index = snapshots.indexWhere((s) => s['id'] == sermon.id);
    if (index < 0 || snapshots[index]['durationSeconds'] != null) return;
    snapshots[index] = {
      ...snapshots[index],
      'durationSeconds': duration.inSeconds,
    };
    _cache.cachePreference(snapshotsKey, snapshots);
  }

  void _upsertSnapshot(Sermon sermon, {required bool moveToFront}) {
    final snapshots = _rawSnapshots();
    final existing = snapshots.indexWhere((s) => s['id'] == sermon.id);
    final json = sermon.toJson();
    if (existing >= 0) {
      // Keep a length learned from a player when the catalogue has none.
      final known = snapshots[existing]['durationSeconds'];
      if (json['durationSeconds'] == null && known != null) {
        json['durationSeconds'] = known;
      }
      snapshots.removeAt(existing);
    }
    snapshots.insert(0, json);
    if (snapshots.length > maxSnapshots) {
      snapshots.removeRange(maxSnapshots, snapshots.length);
    }
    _cache.cachePreference(snapshotsKey, snapshots);
  }

  List<Map<String, dynamic>> _rawSnapshots() {
    final raw = _cache.getPreference<Object?>(snapshotsKey, null);
    if (raw is! List) return <Map<String, dynamic>>[];
    return [
      for (final entry in raw)
        if (entry is Map && entry['id'] is String)
          Map<String, dynamic>.from(entry),
    ];
  }

  /// Snapshots of recently played sermons, newest first.
  List<Sermon> snapshots() => [
    for (final json in _rawSnapshots()) Sermon.fromJson(json),
  ];

  /// The most recently played message that was started but not finished.
  UnfinishedPlay? lastUnfinished() {
    final byId = {for (final s in snapshots()) s.id: s};
    for (final id in _cache.getRecentlyPlayed()) {
      final sermon = byId[id];
      if (sermon == null) continue;
      final resume = resumePoint(sermon);
      if (resume == null) continue;
      return UnfinishedPlay(
        sermon: sermon,
        position: resume,
        duration: sermon.duration,
      );
    }
    return null;
  }
}
