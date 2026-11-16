import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kharis_app/features/home/data/streak_repository.dart';
import 'package:kharis_app/features/player/data/playback_history.dart';
import 'package:kharis_app/shared/models/sermon.dart';
import 'package:kharis_app/shared/providers/audio_provider.dart';
import 'package:kharis_app/shared/providers/cache_provider.dart';
import 'package:kharis_app/shared/providers/clock_provider.dart';
import 'package:kharis_app/shared/providers/streaks_provider.dart';

import 'support/fake_cache_service.dart';

void main() {
  late FakeCacheService cache;
  // Wednesday 11 November 2026, mid-morning.
  late DateTime now;

  StreakRepository repository() => StreakRepository(cache, clock: () => now);

  /// Moves the clock to [day] of November 2026 and marks that day as read.
  void readOn(StreakRepository repo, int day) {
    now = DateTime(2026, 11, day, 10);
    repo.markReadToday();
  }

  /// Listens for [seconds] on the clock's day, in 5-second saves.
  void listen(StreakRepository repo, int seconds, {int from = 100}) {
    for (var s = 0; s < seconds; s += 5) {
      repo.recordListening(
        Duration(seconds: from + s),
        Duration(seconds: from + s + 5),
      );
    }
  }

  setUp(() {
    cache = FakeCacheService();
    now = DateTime(2026, 11, 11, 10);
  });

  group('reading', () {
    test('nothing read: not read today, no streak, no dots', () {
      final s = repository().snapshot();

      expect(s.readToday, isFalse);
      expect(s.readingStreak, 0);
      expect(s.weekRead, List.filled(7, false));
      expect(s.todayIndex, 2, reason: 'Wednesday is the third dot');
    });

    test('marking today counts today, once', () {
      final repo = repository();
      repo.markReadToday();
      repo.markReadToday();

      expect(repo.readToday, isTrue);
      expect(repo.snapshot().readingStreak, 1);
    });

    test('the streak is the run of days ending today', () {
      final repo = repository();
      for (final day in [5, 7, 8, 9, 10, 11]) {
        readOn(repo, day);
      }

      expect(repo.snapshot().readingStreak, 5, reason: 'the 6th was missed');
    });

    test('today not read yet: the streak still stands, up to yesterday', () {
      final repo = repository();
      for (final day in [8, 9, 10]) {
        readOn(repo, day);
      }
      now = DateTime(2026, 11, 11, 7);

      final s = repo.snapshot();
      expect(s.readToday, isFalse);
      expect(s.readingStreak, 3);
    });

    test('a missed day ends the streak', () {
      final repo = repository();
      for (final day in [7, 8, 9]) {
        readOn(repo, day);
      }
      now = DateTime(2026, 11, 11, 7);

      expect(repo.snapshot().readingStreak, 0, reason: 'the 10th was missed');
    });

    test('week dots run Monday to Sunday of the current week', () {
      final repo = repository();
      // Sunday the 8th is last week; Monday the 9th starts this one.
      for (final day in [8, 9, 11]) {
        readOn(repo, day);
      }

      final s = repo.snapshot();
      expect(s.weekRead, [true, false, true, false, false, false, false]);
      expect(s.todayIndex, 2);
    });

    test('on a Sunday the week is the six days before it and today', () {
      final repo = repository();
      for (final day in [9, 14, 15]) {
        readOn(repo, day);
      }

      final s = repo.snapshot();
      expect(s.todayIndex, 6);
      expect(s.weekRead, [true, false, false, false, false, true, true]);
    });

    test('marks survive a restart', () {
      final first = repository();
      readOn(first, 10);
      readOn(first, 11);

      final s = repository().snapshot();
      expect(s.readToday, isTrue);
      expect(s.readingStreak, 2);
    });

    test('a streak runs across a month end', () {
      final repo = repository();
      now = DateTime(2026, 10, 30, 9);
      repo.markReadToday();
      now = DateTime(2026, 10, 31, 9);
      repo.markReadToday();
      now = DateTime(2026, 11, 1, 9);
      repo.markReadToday();

      expect(repo.snapshot().readingStreak, 3);
    });
  });

  group('clock changes', () {
    test('the day the clocks go back (25 hours long) is one day', () {
      final repo = repository();
      // UK clocks go back on Sunday 25 October 2026.
      now = DateTime(2026, 10, 24, 23, 30);
      repo.markReadToday();
      now = DateTime(2026, 10, 25, 0, 30);
      repo.markReadToday();
      now = DateTime(2026, 10, 25, 23, 30);
      repo.markReadToday();
      now = DateTime(2026, 10, 26, 0, 15);
      repo.markReadToday();

      expect(repo.snapshot().readingStreak, 3);
    });

    test('the day the clocks go forward (23 hours long) is one day', () {
      final repo = repository();
      // UK clocks go forward on Sunday 29 March 2026.
      for (final day in [28, 29, 30]) {
        now = DateTime(2026, 3, day, 23, 45);
        repo.markReadToday();
      }

      expect(repo.snapshot().readingStreak, 3);
    });

    test('a mark made with the clock set ahead waits for its day', () {
      final repo = repository();
      readOn(repo, 10);
      // The clock jumps a week ahead, a reading is marked, and it is put
      // right again.
      readOn(repo, 18);
      now = DateTime(2026, 11, 11, 10);

      final s = repo.snapshot();
      expect(s.readToday, isFalse);
      expect(s.readingStreak, 1, reason: 'the 10th; the 18th has not come');
      expect(s.weekRead, [false, true, false, false, false, false, false]);
    });
  });

  group('messages', () {
    test('under a minute of listening does not count the day', () {
      final repo = repository();
      listen(repo, 55);

      final s = repo.snapshot();
      expect(s.listenedToday, isFalse);
      expect(s.messagesStreak, 0);
    });

    test('a minute of listening counts the day', () {
      final repo = repository();
      listen(repo, 60);

      final s = repo.snapshot();
      expect(s.listenedToday, isTrue);
      expect(s.messagesStreak, 1);
    });

    test('a seek forward is not listening', () {
      final repo = repository();
      repo.recordListening(
        const Duration(minutes: 2),
        const Duration(minutes: 40),
      );

      expect(repo.snapshot().listenedToday, isFalse);
    });

    test('the 30-second skip button is not listening', () {
      final repo = repository();
      for (var at = 100; at < 400; at += 30) {
        repo.recordListening(Duration(seconds: at), Duration(seconds: at + 30));
      }

      expect(repo.snapshot().listenedToday, isFalse);
    });

    test('a seek back is not listening', () {
      final repo = repository();
      repo.recordListening(
        const Duration(minutes: 40),
        const Duration(minutes: 2),
      );

      expect(repo.snapshot().listenedToday, isFalse);
    });

    test('the streak is the run of days that reached a minute', () {
      final repo = repository();
      for (final day in [8, 9, 10, 11]) {
        now = DateTime(2026, 11, day, 20);
        listen(repo, day == 9 ? 30 : 90);
      }

      expect(
        repo.snapshot().messagesStreak,
        2,
        reason: 'the 9th fell short, so only the 10th and 11th',
      );
    });

    test('not listened yet today: the streak stands, up to yesterday', () {
      final repo = repository();
      for (final day in [9, 10]) {
        now = DateTime(2026, 11, day, 20);
        listen(repo, 120);
      }
      now = DateTime(2026, 11, 11, 7);

      final s = repo.snapshot();
      expect(s.listenedToday, isFalse);
      expect(s.messagesStreak, 2);
    });

    test('listening is kept across a restart', () {
      listen(repository(), 40);
      final repo = repository();
      listen(repo, 20, from: 140);

      expect(repo.snapshot().listenedToday, isTrue);
    });

    test('changes fires when a day reaches the minute, not on every save', () {
      final repo = repository();
      var fired = 0;
      repo.changes.addListener(() => fired++);
      listen(repo, 180);

      expect(fired, 1);
    });
  });

  group('playback positions feed the messages streak', () {
    const sermon = Sermon(
      id: 's1',
      title: 'Message',
      speaker: 'Pastor A',
      audioUrl: 'https://cdn.example/s1.mp3',
    );

    test('every saved position reports the stretch since the last one', () {
      final steps = <(Duration, Duration)>[];
      final history = PlaybackHistory(
        cache,
        onListened: (previous, position) => steps.add((previous, position)),
      );

      history.savePosition(sermon, const Duration(seconds: 15));
      history.savePosition(sermon, const Duration(seconds: 20));

      expect(steps, [
        (Duration.zero, const Duration(seconds: 15)),
        (const Duration(seconds: 15), const Duration(seconds: 20)),
      ]);
    });

    test('a position at or under the resume floor is not reported', () {
      var calls = 0;
      final history = PlaybackHistory(cache, onListened: (_, _) => calls++);

      history.savePosition(sermon, const Duration(seconds: 5));

      expect(calls, 0);
      expect(history.savedPosition(sermon), Duration.zero);
    });

    test('saving still works with no listener', () {
      final history = PlaybackHistory(cache);

      history.savePosition(sermon, const Duration(seconds: 42));

      expect(history.savedPosition(sermon), const Duration(seconds: 42));
    });

    test('the live stream is not counted', () {
      var calls = 0;
      final history = PlaybackHistory(cache, onListened: (_, _) => calls++);

      history.savePosition(
        const Sermon(
          id: PlaybackHistory.liveSermonId,
          title: 'Live',
          speaker: '',
          audioUrl: 'https://cdn.example/live',
        ),
        const Duration(minutes: 3),
      );

      expect(calls, 0);
    });
  });

  group('providers', () {
    ProviderContainer container() {
      final c = ProviderContainer(
        overrides: [
          cacheServiceProvider.overrideWithValue(cache),
          clockProvider.overrideWithValue(() => now),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('marking today updates readToday and the streak', () {
      final c = container();
      expect(c.read(readTodayProvider), isFalse);

      c.read(streakRepositoryProvider).markReadToday();

      expect(c.read(readTodayProvider), isTrue);
      expect(c.read(streaksProvider).readingStreak, 1);
      expect(c.read(streaksProvider).weekRead[2], isTrue);
    });

    test('a minute of saved positions starts the messages streak', () {
      final c = container();
      final history = c.read(playbackHistoryProvider);
      const sermon = Sermon(
        id: 's1',
        title: 'Message',
        speaker: 'Pastor A',
        audioUrl: 'https://cdn.example/s1.mp3',
      );
      expect(c.read(streaksProvider).messagesStreak, 0);

      // The players save every 5 seconds; the first save past the resume
      // floor arrives at 15 seconds.
      for (var s = 15; s <= 80; s += 5) {
        history.savePosition(sermon, Duration(seconds: s));
      }

      expect(c.read(streaksProvider).listenedToday, isTrue);
      expect(c.read(streaksProvider).messagesStreak, 1);
    });

    test('opening a message at its resume point is not listening', () {
      final c = container();
      final history = c.read(playbackHistoryProvider);
      const sermon = Sermon(
        id: 's1',
        title: 'Message',
        speaker: 'Pastor A',
        audioUrl: 'https://cdn.example/s1.mp3',
      );

      history.savePosition(sermon, const Duration(minutes: 30));

      expect(c.read(streaksProvider).listenedToday, isFalse);
    });
  });
}
