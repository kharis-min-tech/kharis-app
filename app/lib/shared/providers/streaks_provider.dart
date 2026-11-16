import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/home/data/streak_repository.dart';
import 'cache_provider.dart';
import 'clock_provider.dart';

export '../../features/home/data/streak_repository.dart' show Streaks;

/// Reading marks and listening time on this device.
///
/// Mark today's reading with
/// `ref.read(streakRepositoryProvider).markReadToday()`. Listening is fed by
/// `playbackHistoryProvider`: every position the audio and video players
/// save.
final streakRepositoryProvider = Provider<StreakRepository>((ref) {
  return StreakRepository(
    ref.watch(cacheServiceProvider),
    clock: ref.watch(clockProvider),
  );
});

/// Today's local calendar date (midnight). Checked once a minute, so an app
/// left open past midnight, or a changed clock, moves every day-based figure
/// on within the minute.
final todayProvider = Provider<DateTime>((ref) {
  final clock = ref.watch(clockProvider);
  DateTime day() {
    final now = clock();
    return DateTime(now.year, now.month, now.day);
  }

  final today = day();
  final timer = Timer.periodic(const Duration(minutes: 1), (_) {
    if (day() != today) ref.invalidateSelf();
  });
  ref.onDispose(timer.cancel);
  return today;
});

/// The member's reading and messages streaks, whether today's reading is
/// read, and the week's dots. Rebuilt when a reading is marked, when a day
/// reaches the listening threshold and when the day changes.
final streaksProvider = Provider<Streaks>((ref) {
  ref.watch(todayProvider);
  final repository = ref.watch(streakRepositoryProvider);
  void changed() => ref.invalidateSelf();
  repository.changes.addListener(changed);
  ref.onDispose(() => repository.changes.removeListener(changed));
  return repository.snapshot();
});

/// Whether today's daily reading is marked as read.
final readTodayProvider = Provider<bool>(
  (ref) => ref.watch(streaksProvider.select((s) => s.readToday)),
);
