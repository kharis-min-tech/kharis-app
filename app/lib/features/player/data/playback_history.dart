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

/// How far the member has got through one message, for list rows.
sealed class ListeningProgress {
  const ListeningProgress();
}

/// Never played, or not past [PlaybackHistory.resumeFloor].
class NotStarted extends ListeningProgress {
  const NotStarted();
}

/// Started and not finished. [remaining] and [fraction] are null when the
/// message's length is unknown.
class InProgress extends ListeningProgress {
  const InProgress({required this.position, this.remaining, this.fraction});

  final Duration position;
  final Duration? remaining;
  final double? fraction;
}

/// Played to the end (and not restarted since).
class Finished extends ListeningProgress {
  const Finished();
}

/// Resume points, "Recently played" and the sermon snapshots that let recents
/// resolve before the archive has hydrated. Shared by the audio engine and
/// the video engine so both write ONE history for a message.
///
/// Positions are stored under every key a message can be looked up by: the
/// raw [Sermon.id] of the variant that played and its [NoteTimelineKey]
/// canonical (`yt_<videoId>` when it has a video). Audio and video variants
/// of one message therefore share a single resume point, whichever engine
/// played last. Positions are on the AUDIO timeline (the video engine maps
/// its clock through [Sermon.videoStart] before saving).
///
/// "Recently played" holds one entry per message, deduplicated by that same
/// canonical key, and keeps the raw id of the variant that played last so the
/// entry resolves through its snapshot.
///
/// The live stream ([liveSermonId]) is never recorded: it is not a message
/// that can be resumed or replayed, and its fixed id would hand one stream's
/// position to the next.
class PlaybackHistory {
  PlaybackHistory(this._cache);

  final CacheService _cache;

  /// Preference key of the snapshot list (read by `sermonByIdProvider`).
  static const String snapshotsKey = 'recent_sermon_snapshots';

  /// Id of the live-stream pseudo-sermon Home's Live now block plays.
  static const String liveSermonId = 'live';

  /// Snapshots kept, newest first.
  static const int maxSnapshots = 30;

  /// Positions at or under this are "not really started" and never resumed.
  static const Duration resumeFloor = Duration(seconds: 10);

  /// A saved position this close to the end counts as finished.
  static const Duration endGuard = Duration(seconds: 15);

  static bool _isLive(Sermon sermon) => sermon.id == liveSermonId;

  static List<String> _keys(Sermon sermon) {
    final canonical = NoteTimelineKey.of(sermon).canonical;
    return canonical == sermon.id ? [sermon.id] : [canonical, sermon.id];
  }

  // ── Positions ──────────────────────────────────────────────────────────────

  /// Preference key of the canonical keys of messages played to the end.
  static const String finishedKey = 'finished_sermons';

  /// Bumped on every write, so list rows can redraw their progress.
  final ValueNotifier<int> changes = ValueNotifier(0);

  /// Persists [position] for [sermon] when it is past [resumeFloor]. A
  /// finished message being played again is no longer "finished".
  void savePosition(Sermon sermon, Duration position) {
    if (position <= resumeFloor) return;
    _setFinished(sermon, finished: false, notify: false);
    _write(sermon, position.inMilliseconds);
  }

  /// The message played to the end: forget the resume point so the next
  /// play starts from the top, and remember it was finished.
  void markFinished(Sermon sermon) {
    if (_isLive(sermon)) return;
    _setFinished(sermon, finished: true, notify: false);
    _write(sermon, 0);
  }

  void _write(Sermon sermon, int ms) {
    if (_isLive(sermon)) return;
    for (final key in _keys(sermon)) {
      _cache.cachePlaybackPosition(key, ms);
    }
    changes.value++;
  }

  Set<String> _finished() => {
    ...?(_cache.getPreference<Object?>(finishedKey, null) as List?)
        ?.whereType<String>(),
  };

  /// Callers that go on to [_write] pass `notify: false`, so listeners hear
  /// one change per save with both writes already done.
  void _setFinished(
    Sermon sermon, {
    required bool finished,
    bool notify = true,
  }) {
    final all = _finished();
    final key = NoteTimelineKey.of(sermon).canonical;
    final changed = finished ? all.add(key) : all.remove(key);
    if (!changed) return;
    _cache.cachePreference(finishedKey, all.toList());
    if (notify) changes.value++;
  }

  /// Where the member is with [sermon], for the "28 min left" and
  /// "Finished" labels on list rows.
  ListeningProgress progressOf(Sermon sermon) {
    if (_isLive(sermon)) return const NotStarted();
    if (_finished().contains(NoteTimelineKey.of(sermon).canonical)) {
      return const Finished();
    }
    final saved = savedPosition(sermon);
    if (saved <= resumeFloor) return const NotStarted();
    final total = sermon.duration;
    if (total == null || total <= Duration.zero) {
      return InProgress(position: saved);
    }
    if (saved >= total - endGuard) return const Finished();
    return InProgress(
      position: saved,
      remaining: total - saved,
      fraction: saved.inMilliseconds / total.inMilliseconds,
    );
  }

  /// The last saved position, or zero. The canonical key wins; the raw id is
  /// the fallback for positions saved before keys were shared.
  Duration savedPosition(Sermon sermon) {
    if (_isLive(sermon)) return Duration.zero;
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
  ///
  /// Any other variant of the same message (the numeric API id vs the `yt_`
  /// CMS doc vs the bare feed id) is dropped first, so one message is one
  /// row whichever engine or variant played it.
  void recordPlay(Sermon sermon) {
    if (_isLive(sermon)) return;
    final key = NoteTimelineKey.of(sermon);
    final snapshots = _rawSnapshots()
      ..removeWhere((json) {
        final id = json['id'] as String;
        if (id == sermon.id ||
            NoteTimelineKey.of(Sermon.fromJson(json)).canonical !=
                key.canonical) {
          return false;
        }
        _cache.removeRecentlyPlayed(id);
        return true;
      });
    // Alias ids that may sit in the list without a snapshot.
    for (final alias in {key.canonical, ?key.videoId}) {
      if (alias != sermon.id) _cache.removeRecentlyPlayed(alias);
    }
    _cache.addRecentlyPlayed(sermon.id);
    _upsertSnapshot(snapshots, sermon);
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

  /// Moves [sermon]'s snapshot to the front of [snapshots] and persists them.
  void _upsertSnapshot(List<Map<String, dynamic>> snapshots, Sermon sermon) {
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
