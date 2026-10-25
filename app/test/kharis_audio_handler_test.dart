import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:just_audio_platform_interface/just_audio_platform_interface.dart';

import 'package:kharis_app/features/player/data/audio_player_service.dart';
import 'package:kharis_app/features/player/data/kharis_audio_handler.dart';
import 'package:kharis_app/shared/models/sermon.dart';

import 'support/fake_cache_service.dart';
import 'support/fake_just_audio_platform.dart';

/// The OS media controls (notification, lock screen) over the REAL
/// [AudioPlayerService] and a fake just_audio platform: every control drives
/// the same service path as the in-app buttons, and the OS sees the message
/// and state the app is in.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Sermon sermon(int n, {Duration? duration}) => Sermon(
    id: 's$n',
    title: 'Message $n',
    speaker: 'Pastor $n',
    audioUrl: 'https://cdn.example/s$n.mp3',
    artworkUrl: 'https://cdn.example/s$n.jpg',
    series: 'Series $n',
    duration: duration,
  );
  final library = [for (var n = 1; n <= 4; n++) sermon(n)];
  const end = FakeAudioPlatformPlayer.itemDuration;

  late FakeJustAudioPlatform platform;
  late AudioPlayerService service;
  late KharisAudioHandler handler;

  FakeAudioPlatformPlayer native() => platform.player!;
  PlaybackState state() => handler.playbackState.value;
  List<MediaAction> controls() => [for (final c in state().controls) c.action];

  /// Lets just_audio and the handler relay platform events.
  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 5));

  /// just_audio extrapolates a playing position from the last event.
  void expectNear(Duration actual, Duration expected) =>
      expect(actual.inMilliseconds, closeTo(expected.inMilliseconds, 1000));

  setUp(() {
    platform = FakeJustAudioPlatform.install();
    service = AudioPlayerService(FakeCacheService());
    handler = KharisAudioHandler()..attach(service);
  });

  tearDown(() async {
    handler.detach(service);
    await service.dispose();
  });

  test(
    'shows the message: title, speaker, series, artwork and length',
    () async {
      await service.play(library[1], queue: library);
      await settle();

      final item = handler.mediaItem.value!;
      expect(item.id, 's2');
      expect(item.title, 'Message 2');
      expect(item.artist, 'Pastor 2');
      expect(item.album, 'Series 2');
      expect(item.artUri, Uri.parse('https://cdn.example/s2.jpg'));
      expect(item.duration, end, reason: 'learned from the engine');
      expect(handler.queue.value.map((i) => i.id), ['s1', 's2', 's3', 's4']);
      expect(state().queueIndex, 1);
    },
  );

  test('controls: back 15, play/pause, forward 30 (the compact three), '
      'Previous / Next only with neighbours, and scrubbing', () async {
    await service.play(library[1], queue: library);
    await settle();

    expect(controls(), [
      MediaAction.skipToPrevious,
      MediaAction.rewind,
      MediaAction.pause,
      MediaAction.fastForward,
      MediaAction.skipToNext,
    ]);
    expect(state().androidCompactActionIndices, [1, 2, 3]);
    expect(
      state().systemActions,
      containsAll([
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      ]),
    );
    expect(state().playing, isTrue);
    expect(state().processingState, AudioProcessingState.ready);

    await service.play(library[0]);
    await settle();
    expect(controls(), [
      MediaAction.rewind,
      MediaAction.pause,
      MediaAction.fastForward,
    ], reason: 'a message on its own has no Previous / Next');
    expect(state().androidCompactActionIndices, [0, 1, 2]);
  });

  group('every control drives the service', () {
    setUp(() async {
      await service.play(library[1], queue: library);
      await settle();
    });

    test('rewind goes back 15 s, never before the start', () async {
      await service.seek(const Duration(minutes: 5));
      await handler.rewind();
      expectNear(native().position, const Duration(minutes: 4, seconds: 45));

      await service.seek(const Duration(seconds: 10));
      await handler.rewind();
      expect(native().position, Duration.zero);
    });

    test('fast-forward goes on 30 s, never past the end', () async {
      await service.seek(const Duration(minutes: 5));
      await handler.fastForward();
      expectNear(native().position, const Duration(minutes: 5, seconds: 30));

      await service.seek(end - const Duration(seconds: 10));
      await handler.fastForward();
      expect(native().position, end);
    });

    test('pause and play', () async {
      await handler.pause();
      await settle();
      expect(native().playing, isFalse);
      expect(state().playing, isFalse);
      expect(controls(), contains(MediaAction.play));

      await handler.play();
      await settle();
      expect(native().playing, isTrue);
      expect(state().playing, isTrue);
      expect(controls(), contains(MediaAction.pause));
    });

    test('seek (scrubbing)', () async {
      await handler.seek(const Duration(minutes: 12));
      expect(native().position, const Duration(minutes: 12));
    });

    test('Next and Previous walk the queue and update the message', () async {
      await handler.skipToNext();
      await settle();
      expect(service.currentSermon?.id, 's3');
      expect(handler.mediaItem.value?.id, 's3');
      expect(state().queueIndex, 2);

      await handler.skipToPrevious();
      await settle();
      expect(service.currentSermon?.id, 's2');
      expect(handler.mediaItem.value?.id, 's2');
    });

    test('stop clears the notification', () async {
      await handler.stop();
      await settle();

      expect(service.currentSermon, isNull);
      expect(handler.mediaItem.value, isNull);
      expect(handler.queue.value, isEmpty);
      expect(state().processingState, AudioProcessingState.idle);
      expect(state().playing, isFalse);
    });
  });

  test('a failed retry shows the message paused, with Play', () async {
    await service.play(library[1], queue: library);
    await settle();
    await native().seek(SeekRequest(position: const Duration(minutes: 3)));
    await settle();

    final reported = service.failureStream
        .firstWhere((failure) => failure != null)
        .timeout(const Duration(seconds: 2));
    platform.failNextLoad = true;
    native().failStream(idle: true);
    await reported;
    await settle();

    expect(handler.mediaItem.value?.id, 's2');
    expect(state().playing, isFalse);
    expect(
      state().processingState,
      AudioProcessingState.ready,
      reason: 'idle would take the notification down',
    );
    expect(controls(), contains(MediaAction.play));
  });

  test(
    'follows a hand-off from video: the new message, at its point',
    () async {
      await service.play(library[0]);
      await settle();
      // Audio -> video released the engine; video -> audio starts the twin.
      await service.stop();
      await settle();
      expect(handler.mediaItem.value, isNull);

      await service.play(
        library[2],
        startAt: const Duration(minutes: 8),
        queue: library,
      );
      await settle();

      expect(handler.mediaItem.value?.id, 's3');
      expect(state().playing, isTrue);
      expectNear(state().updatePosition, const Duration(minutes: 8));
    },
  );

  test('detaching the service clears the OS controls', () async {
    await service.play(library[0]);
    await settle();

    handler.detach(service);

    expect(handler.mediaItem.value, isNull);
    expect(state().processingState, AudioProcessingState.idle);
    handler.attach(service);
  });
}
