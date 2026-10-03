import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:just_audio_platform_interface/just_audio_platform_interface.dart';

import 'package:kharis_app/features/player/data/audio_player_service.dart';
import 'package:kharis_app/features/player/data/playback_history.dart';
import 'package:kharis_app/shared/models/sermon.dart';

import 'support/fake_cache_service.dart';
import 'support/fake_just_audio_platform.dart';

/// The REAL [AudioPlayerService] over a fake just_audio platform: proves the
/// engine contract (non-blocking play, queue window, Previous / Next, resume
/// points, persisted speed) rather than a stand-in's behaviour.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Sermon sermon(int n, {String? videoId}) => Sermon(
    id: 's$n',
    title: 'Message $n',
    speaker: 'Pastor A',
    audioUrl: 'https://cdn.example/s$n.mp3',
    videoId: videoId,
  );
  final library = [for (var n = 1; n <= 5; n++) sermon(n)];

  late FakeJustAudioPlatform platform;
  late FakeCacheService cache;
  late AudioPlayerService service;

  FakeAudioPlatformPlayer native() => platform.player!;

  /// Lets just_audio relay platform events to its streams.
  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 5));

  setUp(() {
    platform = FakeJustAudioPlatform.install();
    cache = FakeCacheService();
    service = AudioPlayerService(cache);
  });

  tearDown(() => service.dispose());

  test(
    'play() returns once the engine runs, without waiting for a pause',
    () async {
      // Before the fix this future only completed when playback paused, so
      // every caller sequencing work after it (handoff seek, note anchor,
      // history) hung until the member pressed pause.
      final started = await service
          .play(library[0])
          .timeout(const Duration(seconds: 2));

      expect(started, isTrue);
      await settle();
      expect(native().playing, isTrue, reason: 'still playing after return');
    },
  );

  test('stop() survives the background plugin failing to dispose (Android '
      'audio-to-video switch) and still clears playback state', () async {
    await service.play(library[0]);
    await settle();
    platform.failDispose = true;

    // Before the guard, just_audio's UnimplementedError escaped stop() and
    // left currentSermon set on an engine that had already stopped.
    await expectLater(service.stop(), completes);
    expect(service.currentSermon, isNull);
    platform.failDispose = false;
  });

  test('only the load that wins is recorded as recently played', () async {
    final first = service.play(library[0]);
    final second = service.play(library[1]);
    final results = await Future.wait([first, second]);

    expect(results, [isFalse, isTrue]);
    expect(cache.getRecentlyPlayed(), ['s2']);
    final snapshots = PlaybackHistory(cache).snapshots();
    expect(
      snapshots.map((s) => s.id),
      ['s2'],
      reason: 'snapshot lets the recent entry resolve before hydration',
    );
  });

  test('startAt wins over the saved resume point', () async {
    cache.cachePlaybackPosition(
      's1',
      const Duration(minutes: 9).inMilliseconds,
    );

    await service.play(library[0], startAt: const Duration(minutes: 4));

    expect(native().loads.single.initialPosition, const Duration(minutes: 4));
  });

  test(
    'without startAt the shared resume point (canonical key) is used',
    () async {
      final withVideo = sermon(7, videoId: 'vid7');
      // Saved by the VIDEO engine under the canonical key only.
      cache.cachePlaybackPosition(
        'yt_vid7',
        const Duration(minutes: 12).inMilliseconds,
      );

      await service.play(withVideo);

      expect(
        native().loads.single.initialPosition,
        const Duration(minutes: 12),
      );
    },
  );

  test('re-playing the message on air attaches instead of reloading', () async {
    await service.play(library[0]);
    await settle();
    await service.pause();
    await settle();

    final again = await service.play(library[0]);
    await settle();

    expect(again, isTrue);
    expect(native().loads, hasLength(1), reason: 'no second load');
    expect(native().playing, isTrue, reason: 'paused playback resumes');
  });

  group('a request aimed at a message still loading', () {
    // just_audio drops seeks while loading, so these used to land nowhere.

    /// Starts [target] with its load held open on an already-active native
    /// player (the first activation is serialised by just_audio itself).
    Future<(Future<bool>, Completer<void>)> loadHeld(Sermon target) async {
      await service.play(library[4]);
      await settle();
      final gate = Completer<void>();
      platform.holdNextLoad = gate.future;
      final pending = service.play(target, queue: library);
      await settle();
      expect(native().loads, hasLength(2), reason: 'second load still held');
      return (pending, gate);
    }

    test('startAt reloads at that point instead of being dropped', () async {
      final (first, gate) = await loadHeld(library[1]);

      final started = await service.play(
        library[1],
        startAt: const Duration(minutes: 5),
        queue: library,
      );
      gate.complete();
      await first;
      await settle();

      expect(started, isTrue);
      expect(native().loads, hasLength(3), reason: 'a fresh load, not a seek');
      expect(native().loads.last.initialPosition, const Duration(minutes: 5));
      expect(native().position, const Duration(minutes: 5));
    });

    test('Next moves to the next message', () async {
      final (first, gate) = await loadHeld(library[1]);

      await service.skipToNext();
      gate.complete();
      await first;
      await settle();

      expect(service.currentSermon?.id, 's3');
      expect(service.queue!.index, 2);
      final window =
          native().loads.last.audioSourceMessage
              as ConcatenatingAudioSourceMessage;
      expect(
        (window.children[native().index!] as UriAudioSourceMessage).uri,
        library[2].audioUrl,
      );
    });
  });

  test(
    'queue loads a window around the message, Next moves and extends it',
    () async {
      await service.play(library[1], queue: library);
      await settle();

      final load = native().loads.single;
      final window = load.audioSourceMessage as ConcatenatingAudioSourceMessage;
      expect(window.children, hasLength(3), reason: 's1, s2, s3');
      expect(load.initialIndex, 1);
      expect(service.queue!.index, 1);

      await service.skipToNext();
      await settle();

      expect(native().seeks.last.index, 2);
      expect(service.currentSermon?.id, 's3');
      expect(service.queue!.index, 2);
      expect(native().length, 4, reason: 's4 appended so Next stays live');
      expect(cache.getRecentlyPlayed().first, 's3');
    },
  );

  test('Previous restarts past 3 s, steps back within 3 s', () async {
    await service.play(library[2], queue: library);
    await settle();

    await service.seek(const Duration(seconds: 40));
    await settle();
    await service.skipToPrevious();
    await settle();
    expect(service.currentSermon?.id, 's3', reason: 'restart, same message');
    expect(native().position, Duration.zero);

    await service.skipToPrevious();
    await settle();
    expect(service.currentSermon?.id, 's2', reason: 'within 3 s: step back');
  });

  test(
    'Next is a no-op on the last message; Previous at the first, at 0:00',
    () async {
      await service.play(library.last, queue: library);
      await settle();
      final seeksBefore = native().seeks.length;
      await service.skipToNext();
      await settle();
      expect(native().seeks.length, seeksBefore);
      expect(service.currentSermon?.id, 's5');

      await service.play(library.first, queue: library);
      await settle();
      final seeksAtStart = native().seeks.length;
      await service.skipToPrevious();
      await settle();
      expect(native().seeks.length, seeksAtStart);
      expect(service.currentSermon?.id, 's1');
    },
  );

  test(
    'a lock-screen skip (native index move) is followed by the service',
    () async {
      await service.play(library[1], queue: library);
      await settle();

      // The OS skip button seeks the native window directly.
      await native().seek(SeekRequest(position: Duration.zero, index: 0));
      await settle();

      expect(service.currentSermon?.id, 's1');
      expect(service.queue!.index, 0);
    },
  );

  test('resume after the message finished starts it over', () async {
    await service.play(library[0]);
    await settle();
    native().complete();
    await settle();

    await service.resume();
    await settle();

    expect(native().seeks.last.position, Duration.zero);
    expect(native().playing, isTrue);
    expect(PlaybackHistory(cache).savedPosition(library[0]), Duration.zero);
  });

  test('speed persists across service instances', () async {
    await service.setSpeed(1.5);
    expect(
      cache.getPreference<Object?>(AudioPlayerService.speedPreferenceKey, null),
      1.5,
    );

    final next = AudioPlayerService(cache);
    addTearDown(next.dispose);
    await settle();
    expect(next.speed, 1.5);
  });

  test('Repeat sets loop-one on the engine', () async {
    await service.play(library[0]);
    await service.setRepeatOne(true);
    await settle();
    expect(native().loopMode, LoopModeMessage.one);
    expect(service.repeatOne, isTrue);
  });
}
