import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../shared/models/sermon.dart';

/// The hydrated sermon archive as persisted on disk, with the time of the
/// last complete walk of the API (used to schedule revalidation).
@immutable
class SermonArchiveSnapshot {
  const SermonArchiveSnapshot({required this.sermons, required this.fetchedAt});

  final List<Sermon> sermons;
  final DateTime fetchedAt;
}

/// Disk store for the sermon archive. [CacheService] is the app's store;
/// tests use an in-memory one.
abstract interface class SermonArchiveStore {
  /// The last persisted archive, decoded off the UI isolate. Null when none
  /// has been stored (or it is unreadable).
  Future<SermonArchiveSnapshot?> readSermonArchive();

  /// Persists a fully hydrated archive.
  Future<void> writeSermonArchive(SermonArchiveSnapshot snapshot);
}

/// Archive schema written today. Version 2 archives were saved before
/// sermons carried their Bible passages: [decodeSermonArchive] still loads
/// them, so the library paints at once, but as never fetched, so the library
/// re-walks the archive on that launch and saves it as version 3.
const _archiveVersion = 3;
const _archiveVersionBeforePassages = 2;

/// The fetch time given to an archive that must be fetched again: older
/// than any maximum age.
final DateTime _dueForRefetch = DateTime.fromMillisecondsSinceEpoch(
  0,
  isUtc: true,
);

/// Encodes [snapshot] for disk. Top-level so it can run under [compute].
String encodeSermonArchive(SermonArchiveSnapshot snapshot) => jsonEncode({
  'v': _archiveVersion,
  'fetchedAt': snapshot.fetchedAt.toIso8601String(),
  'sermons': [for (final s in snapshot.sermons) s.toJson()],
});

/// Decodes a stored archive; null for an unknown schema or corrupt data.
/// Top-level so it can run under [compute]: the archive is ~1.4 MB of JSON,
/// which would stall first paint if decoded on the UI isolate.
SermonArchiveSnapshot? decodeSermonArchive(String raw) {
  try {
    final data = jsonDecode(raw);
    if (data is! Map) return null;
    final version = data['v'];
    if (version != _archiveVersion &&
        version != _archiveVersionBeforePassages) {
      return null;
    }
    final fetchedAt = DateTime.tryParse(data['fetchedAt'] as String? ?? '');
    if (fetchedAt == null) return null;
    return SermonArchiveSnapshot(
      fetchedAt: version == _archiveVersion ? fetchedAt : _dueForRefetch,
      sermons: [
        for (final m in data['sermons'] as List)
          Sermon.fromJson(Map<String, dynamic>.from(m as Map)),
      ],
    );
  } catch (_) {
    return null;
  }
}

class CacheService implements SermonArchiveStore {
  CacheService._({
    required this._sermonsBox,
    required this._eventsBox,
    required this._preferencesBox,
    required this._playbackPositionsBox,
    required this._notesBox,
  });

  final Box<dynamic> _sermonsBox;
  // ignore: unused_field
  final Box<dynamic> _eventsBox;
  final Box<dynamic> _preferencesBox;
  final Box<dynamic> _playbackPositionsBox;
  final Box<dynamic> _notesBox;

  /// Direct access to the raw Hive box for notes storage.
  Box<dynamic> get notesBox => _notesBox;

  /// Archive key. The name predates the schema version inside the blob
  /// (see [encodeSermonArchive]); it stays so an upgrade reads, then
  /// overwrites, the archive already on the phone. The unversioned
  /// `sermons_list` blob it replaced stored series names as categories and
  /// had no fetch time.
  static const _archiveKey = 'sermon_archive_v2';
  static const _legacyArchiveKey = 'sermons_list';

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  /// Hive appends every `put` and only reclaims overwritten frames once 60
  /// have piled up. The sermon box holds one ~1.5 MB archive rewritten on
  /// every archive walk, so the default let `sermons.hive` grow past 90 MB of
  /// dead copies in the app's storage. Compact as soon as anything is stale.
  static bool sermonsCompaction(int entries, int deletedEntries) =>
      deletedEntries > 0;

  static Future<CacheService> init() async {
    await Hive.initFlutter();
    final sermonsBox = await Hive.openBox<dynamic>(
      'sermons',
      compactionStrategy: sermonsCompaction,
    );
    // Reclaims space already lost on installs that ran the default strategy.
    await sermonsBox.compact();
    final eventsBox = await Hive.openBox<dynamic>('events');
    final preferencesBox = await Hive.openBox<dynamic>('preferences');
    final playbackPositionsBox = await Hive.openBox<dynamic>(
      'playback_positions',
    );
    final notesBox = await Hive.openBox<dynamic>('notes');
    return CacheService._(
      sermonsBox: sermonsBox,
      eventsBox: eventsBox,
      preferencesBox: preferencesBox,
      playbackPositionsBox: playbackPositionsBox,
      notesBox: notesBox,
    );
  }

  // ── Sermons ───────────────────────────────────────────────────────────────

  @override
  Future<SermonArchiveSnapshot?> readSermonArchive() async {
    final raw = _sermonsBox.get(_archiveKey);
    if (raw is! String) return null;
    return compute(decodeSermonArchive, raw);
  }

  @override
  Future<void> writeSermonArchive(SermonArchiveSnapshot snapshot) async {
    final raw = await compute(encodeSermonArchive, snapshot);
    await _sermonsBox.put(_archiveKey, raw);
    await _sermonsBox.delete(_legacyArchiveKey);
  }

  // ── Playback positions ────────────────────────────────────────────────────

  void cachePlaybackPosition(String sermonId, int positionMs) {
    _playbackPositionsBox.put(sermonId, positionMs);
  }

  int getPlaybackPosition(String sermonId) {
    final value = _playbackPositionsBox.get(sermonId);
    if (value == null) return 0;
    return value as int;
  }

  // ── Preferences ───────────────────────────────────────────────────────────

  void cachePreference(String key, dynamic value) {
    _preferencesBox.put(key, value);
  }

  T getPreference<T>(String key, T defaultValue) {
    final value = _preferencesBox.get(key);
    if (value == null) return defaultValue;
    return value as T;
  }

  // ── Recently played ────────────────────────────────────────────────────────

  /// Stores an ordered list of sermon IDs recently played (most recent first).
  static const _recentlyPlayedKey = 'recently_played';

  void addRecentlyPlayed(String sermonId) {
    final list = getRecentlyPlayed();
    list.remove(sermonId);
    list.insert(0, sermonId);
    // Keep at most 20 entries.
    if (list.length > 20) list.removeRange(20, list.length);
    _preferencesBox.put(_recentlyPlayedKey, jsonEncode(list));
  }

  /// Drops [sermonId] from the recently played list, if present.
  void removeRecentlyPlayed(String sermonId) {
    final list = getRecentlyPlayed();
    if (!list.remove(sermonId)) return;
    _preferencesBox.put(_recentlyPlayedKey, jsonEncode(list));
  }

  List<String> getRecentlyPlayed() {
    final raw = _preferencesBox.get(_recentlyPlayedKey);
    if (raw == null) return [];
    try {
      final decoded = jsonDecode(raw as String) as List<dynamic>;
      return decoded.cast<String>();
    } catch (_) {
      return [];
    }
  }

  // ── Clear ─────────────────────────────────────────────────────────────────

  Future<void> clearAll() async {
    await _sermonsBox.clear();
    await _eventsBox.clear();
    await _preferencesBox.clear();
    await _playbackPositionsBox.clear();
    await _notesBox.clear();
  }
}
