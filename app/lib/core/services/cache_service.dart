import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

class CacheService {
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

  static const _sermonsListKey = 'sermons_list';

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  static Future<CacheService> init() async {
    await Hive.initFlutter();
    final sermonsBox = await Hive.openBox<dynamic>('sermons');
    final eventsBox = await Hive.openBox<dynamic>('events');
    final preferencesBox = await Hive.openBox<dynamic>('preferences');
    final playbackPositionsBox =
        await Hive.openBox<dynamic>('playback_positions');
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

  void cacheSermons(List<Map<String, dynamic>> sermons) {
    _sermonsBox.put(_sermonsListKey, jsonEncode(sermons));
  }

  List<Map<String, dynamic>> getCachedSermons() {
    final raw = _sermonsBox.get(_sermonsListKey);
    if (raw == null) return [];
    final decoded = jsonDecode(raw as String) as List<dynamic>;
    return decoded
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
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

  // ── Clear ─────────────────────────────────────────────────────────────────

  Future<void> clearAll() async {
    await _sermonsBox.clear();
    await _eventsBox.clear();
    await _preferencesBox.clear();
    await _playbackPositionsBox.clear();
    await _notesBox.clear();
  }
}
