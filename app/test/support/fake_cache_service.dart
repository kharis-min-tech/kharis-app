import 'package:hive_flutter/hive_flutter.dart';

import 'package:kharis_app/core/services/cache_service.dart';

/// In-memory [CacheService]: the same contract without Hive boxes on disk.
class FakeCacheService implements CacheService {
  final Map<String, int> positions = {};
  final Map<String, dynamic> preferences = {};
  final List<String> recentlyPlayed = [];

  @override
  Box<dynamic> get notesBox =>
      throw UnsupportedError('FakeCacheService has no notes box');

  @override
  void cachePlaybackPosition(String sermonId, int positionMs) =>
      positions[sermonId] = positionMs;

  @override
  int getPlaybackPosition(String sermonId) => positions[sermonId] ?? 0;

  @override
  void cachePreference(String key, dynamic value) => preferences[key] = value;

  @override
  T getPreference<T>(String key, T defaultValue) {
    final value = preferences[key];
    return value == null ? defaultValue : value as T;
  }

  @override
  void addRecentlyPlayed(String sermonId) {
    recentlyPlayed
      ..remove(sermonId)
      ..insert(0, sermonId);
    if (recentlyPlayed.length > 20) {
      recentlyPlayed.removeRange(20, recentlyPlayed.length);
    }
  }

  @override
  List<String> getRecentlyPlayed() => List.of(recentlyPlayed);

  @override
  Future<void> clearAll() async {
    positions.clear();
    preferences.clear();
    recentlyPlayed.clear();
  }

  /// Members added to [CacheService] later fail loudly only if a test uses
  /// them, instead of breaking every test that compiles this fake.
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
