import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kharis_app/features/player/data/playback_history.dart';
import 'package:kharis_app/shared/models/sermon.dart';
import 'package:kharis_app/shared/providers/audio_provider.dart';
import 'package:kharis_app/shared/providers/cache_provider.dart';
import 'package:kharis_app/shared/providers/listening_history_provider.dart';

import 'support/fake_cache_service.dart';

void main() {
  late FakeCacheService cache;
  late ProviderContainer container;
  late PlaybackHistory history;

  Sermon sermon(int n, {Duration? duration, String? videoId}) => Sermon(
    id: 's$n',
    title: 'Message $n',
    speaker: 'Pastor A',
    audioUrl: videoId == null ? 'https://cdn.example/s$n.mp3' : '',
    videoId: videoId,
    duration: duration,
  );

  /// Plays [message] and leaves it at [minutes].
  void playTo(Sermon message, int minutes) {
    history.recordPlay(message);
    history.savePosition(message, Duration(minutes: minutes));
  }

  List<String> ids() => [
    for (final play in container.read(listeningHistoryProvider)) play.sermon.id,
  ];

  setUp(() {
    cache = FakeCacheService();
    container = ProviderContainer(
      overrides: [cacheServiceProvider.overrideWithValue(cache)],
    );
    addTearDown(container.dispose);
    history = container.read(playbackHistoryProvider);
  });

  test('empty before anything has been played', () {
    expect(container.read(listeningHistoryProvider), isEmpty);
    expect(container.read(continueListeningListProvider), isEmpty);
  });

  test('each started message carries its position and length', () {
    playTo(sermon(1, duration: const Duration(minutes: 40)), 10);

    final play = container.read(listeningHistoryProvider).single;
    expect(play.sermon.title, 'Message 1');
    expect(play.position, const Duration(minutes: 10));
    expect(play.duration, const Duration(minutes: 40));
    expect(play.progress, 0.25);
  });

  test('most recently played first', () {
    playTo(sermon(1), 5);
    playTo(sermon(2), 7);
    playTo(sermon(3), 9);

    expect(ids(), ['s3', 's2', 's1']);
  });

  test('playing an older message again moves it to the front', () {
    playTo(sermon(1), 5);
    playTo(sermon(2), 7);
    playTo(sermon(1), 12);

    expect(ids(), ['s1', 's2']);
    expect(
      container.read(listeningHistoryProvider).first.position,
      const Duration(minutes: 12),
    );
  });

  test('a finished message drops out', () {
    final message = sermon(1, duration: const Duration(minutes: 40));
    playTo(message, 10);
    playTo(sermon(2), 3);

    history.markFinished(message);

    expect(ids(), ['s2']);
  });

  test('a message left in its closing seconds counts as finished', () {
    final message = sermon(1, duration: const Duration(minutes: 40));
    history.recordPlay(message);
    history.savePosition(message, const Duration(minutes: 39, seconds: 55));

    expect(ids(), isEmpty);
  });

  test('a message opened and left in the first seconds is not listed', () {
    final message = sermon(1);
    history.recordPlay(message);
    history.savePosition(message, const Duration(seconds: 4));

    expect(ids(), isEmpty);
  });

  test('audio and video messages are listed together', () {
    playTo(sermon(1), 5);
    playTo(sermon(2, videoId: 'abc'), 8);

    expect(ids(), ['s2', 's1']);
  });

  test('the first entry is the Continue listening card\'s message', () {
    playTo(sermon(1), 5);
    playTo(sermon(2), 7);

    expect(
      container.read(listeningHistoryProvider).first.sermon.id,
      history.lastUnfinished()!.sermon.id,
    );
  });

  test('Continue listening is the first three', () {
    for (var n = 1; n <= 5; n++) {
      playTo(sermon(n), n + 1);
    }

    expect(
      [
        for (final play in container.read(continueListeningListProvider))
          play.sermon.id,
      ],
      ['s5', 's4', 's3'],
    );
    expect(ids(), hasLength(5));
  });

  test('the list follows the position as it is saved', () {
    final message = sermon(1);
    final sub = container.listen(listeningHistoryProvider, (_, _) {});
    addTearDown(sub.close);
    playTo(message, 5);
    expect(sub.read().single.position, const Duration(minutes: 5));

    history.savePosition(message, const Duration(minutes: 6));

    expect(sub.read().single.position, const Duration(minutes: 6));
  });
}
