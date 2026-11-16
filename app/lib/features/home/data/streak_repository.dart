import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:kharis_app/core/services/cache_service.dart';
import 'package:kharis_app/features/home/data/daily_content_repository.dart';

/// Where the member stands today: what Home's streak card and the More
/// profile card show.
@immutable
class Streaks {
  const Streaks({
    required this.readToday,
    required this.readingStreak,
    required this.listenedToday,
    required this.messagesStreak,
    required this.weekRead,
    required this.todayIndex,
  });

  /// Whether today's reading is marked as read.
  final bool readToday;

  /// Days in a row with a reading marked, ending today, or yesterday while
  /// today's is still unread.
  final int readingStreak;

  /// Whether today has reached [StreakRepository.listeningThreshold].
  final bool listenedToday;

  /// Days in a row that reached [StreakRepository.listeningThreshold] of
  /// listening, ending today, or yesterday while today has not got there.
  final int messagesStreak;

  /// Read or not for Monday to Sunday of the current week (seven entries).
  /// Days still to come are false.
  final List<bool> weekRead;

  /// Today's place in [weekRead]: 0 is Monday, 6 is Sunday.
  final int todayIndex;

  @override
  bool operator ==(Object other) =>
      other is Streaks &&
      other.readToday == readToday &&
      other.readingStreak == readingStreak &&
      other.listenedToday == listenedToday &&
      other.messagesStreak == messagesStreak &&
      other.todayIndex == todayIndex &&
      listEquals(other.weekRead, weekRead);

  @override
  int get hashCode => Object.hash(
    readToday,
    readingStreak,
    listenedToday,
    messagesStreak,
    todayIndex,
    Object.hashAll(weekRead),
  );
}

/// Daily reading marks and listening time, kept on this device.
///
/// A day is a local calendar day, named `YYYY-MM-DD` ([readingDateKey], the
/// key the daily reading itself is fetched by). Streaks are counted by
/// stepping back one calendar date at a time, never by subtracting 24 hours,
/// so a daylight-saving change cannot split or merge a day. A mark dated
/// after today (the clock was ahead when it was made) is ignored until that
/// day comes round; nothing is ever deleted because the clock moved.
///
/// Listening is measured from the positions the players already save, not
/// from a clock: each save adds how far the message moved on since the save
/// before it. A jump longer than [maxListeningStep] is a seek, not
/// listening, and adds nothing.
class StreakRepository {
  StreakRepository(this._cache, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final CacheService _cache;
  final DateTime Function() _clock;

  /// Preference key of the days a reading was marked, as a JSON list.
  static const String readDaysKey = 'streak_read_days';

  /// Preference key of milliseconds listened per day, as a JSON object.
  static const String listeningKey = 'streak_listening_ms';

  /// Listening that makes a day count towards the messages streak.
  static const Duration listeningThreshold = Duration(seconds: 60);

  /// The furthest a message can move on between two saves and still be
  /// listening. The players save every 5 seconds, so a step is 5 seconds of
  /// the message, or 15 at 3x speed; the first save of a message comes at
  /// up to 20. The 30-second skip button is over the limit.
  static const Duration maxListeningStep = Duration(seconds: 20);

  /// Bumped when a streak figure can have changed: a reading was marked, or
  /// a day reached [listeningThreshold].
  final ValueNotifier<int> changes = ValueNotifier(0);

  Set<String>? _readDays;
  Map<String, int>? _listening;

  // ── Reading ────────────────────────────────────────────────────────────────

  /// Whether today's reading is marked as read.
  bool get readToday => _days().contains(readingDateKey(_clock()));

  /// Marks today's reading as read. Marking twice is the same as once.
  void markReadToday() {
    final days = _days();
    if (!days.add(readingDateKey(_clock()))) return;
    _cache.cachePreference(readDaysKey, jsonEncode(days.toList()..sort()));
    changes.value++;
  }

  Set<String> _days() => _readDays ??= {
    ...?_decode<List<dynamic>>(readDaysKey)?.whereType<String>(),
  };

  // ── Listening ──────────────────────────────────────────────────────────────

  /// Counts the stretch from [previous], the position saved before, to
  /// [position], the one being saved now, as listening done today.
  void recordListening(Duration previous, Duration position) {
    final step = position - previous;
    if (step <= Duration.zero || step > maxListeningStep) return;
    final listening = _listened();
    final today = readingDateKey(_clock());
    final before = listening[today] ?? 0;
    final after = before + step.inMilliseconds;
    listening[today] = after;
    // A day before today that never got there cannot count any more.
    final threshold = listeningThreshold.inMilliseconds;
    listening.removeWhere(
      (day, ms) => ms < threshold && day.compareTo(today) < 0,
    );
    _cache.cachePreference(listeningKey, jsonEncode(listening));
    if (before < threshold && after >= threshold) changes.value++;
  }

  Map<String, int> _listened() => _listening ??= {
    for (final entry
        in (_decode<Map<String, dynamic>>(listeningKey) ?? const {}).entries)
      if (entry.value is num) entry.key: (entry.value as num).toInt(),
  };

  bool _listenedOn(String day) =>
      (_listened()[day] ?? 0) >= listeningThreshold.inMilliseconds;

  // ── Summary ────────────────────────────────────────────────────────────────

  /// Today's figures.
  Streaks snapshot() {
    final now = _clock();
    final today = DateTime(now.year, now.month, now.day);
    final days = _days();
    bool read(DateTime day) => days.contains(readingDateKey(day));
    bool listened(DateTime day) => _listenedOn(readingDateKey(day));
    final todayIndex = today.weekday - DateTime.monday;
    return Streaks(
      readToday: read(today),
      readingStreak: _streak(read, today),
      listenedToday: listened(today),
      messagesStreak: _streak(listened, today),
      weekRead: [
        for (var i = 0; i < DateTime.daysPerWeek; i++)
          i <= todayIndex && read(_shift(today, i - todayIndex)),
      ],
      todayIndex: todayIndex,
    );
  }

  /// Days in a row [has] holds for, ending on [today], or the day before
  /// when today does not hold yet.
  static int _streak(bool Function(DateTime day) has, DateTime today) {
    var day = has(today) ? today : _shift(today, -1);
    var count = 0;
    while (has(day)) {
      count++;
      day = _shift(day, -1);
    }
    return count;
  }

  /// The calendar date [days] away from [day].
  static DateTime _shift(DateTime day, int days) =>
      DateTime(day.year, day.month, day.day + days);

  T? _decode<T>(String key) {
    final raw = _cache.getPreference<Object?>(key, null);
    if (raw is! String) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is T ? decoded : null;
    } on FormatException {
      return null;
    }
  }
}
