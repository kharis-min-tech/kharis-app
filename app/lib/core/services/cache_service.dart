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

/// Encodes [snapshot] for disk. Top-level so it can run under [compute].
String encodeSermonArchive(SermonArchiveSnapshot snapshot) => jsonEncode({
  'v': 2,
  'fetchedAt': snapshot.fetchedAt.toIso8601String(),
  'sermons': [for (final s in snapshot.sermons) s.toJson()],
});

/// Decodes a stored archive; null for an unknown schema or corrupt data.
/// Top-level so it can run under [compute]: the archive is ~1.4 MB of JSON,
/// which would stall first paint if decoded on the UI isolate.
SermonArchiveSnapshot? decodeSermonArchive(String raw) {
  try {
    final data = jsonDecode(raw);
    if (data is! Map || data['v'] != 2) return null;
    final fetchedAt = DateTime.tryParse(data['fetchedAt'] as String? ?? '');
    if (fetchedAt == null) return null;
    return SermonArchiveSnapshot(
      fetchedAt: fetchedAt,
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

  /// Versioned archive key. The unversioned `sermons_list` blob it replaces
  /// stored series names as categories and had no fetch time.
  static const _archiveKey = 'sermon_archive_v2';
  static const _legacyArchiveKey = 'sermons_list';

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  static Future<CacheService> init() async {
    await Hive.initFlutter();
    final sermonsBox = await Hive.openBox<dynamic>('sermons');
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
