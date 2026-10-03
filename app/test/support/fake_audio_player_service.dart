import 'dart:async';

import 'package:just_audio/just_audio.dart';

import 'package:kharis_app/features/player/data/audio_player_service.dart';
import 'package:kharis_app/shared/models/sermon.dart';

/// One [FakeAudioPlayerService.play] request, as the caller made it.
class PlayCall {
  const PlayCall(this.sermon, {this.startAt, this.queue});

  final Sermon sermon;
  final Duration? startAt;
  final List<Sermon>? queue;
}

/// [AudioPlayerService] with no just_audio engine behind it.
///
/// Shared by every widget test that needs the player: it records what the UI
/// drives it to do and keeps a real [PlaybackQueue], so Previous / Next obey
/// the production rules. Extend it to override a single behaviour.
class FakeAudioPlayerService implements AudioPlayerService {
  final List<PlayCall> calls = [];
  final List<Duration> seekCalls = [];
  final List<double> speedCalls = [];
  int stopCalls = 0;
  int pauseCalls = 0;
  int resumeCalls = 0;
  int nextCalls = 0;
  int previousCalls = 0;
  bool resumed = false;

  /// What [play] reports; set false to simulate a failed load.
  bool playResult = true;

  /// Live position reported to callers ([position]).
  Duration positionValue = Duration.zero;

  Sermon? current;
  PlaybackQueue? _queue;
  double _speed = 1.0;
  bool _repeatOne = false;

  final StreamController<Duration> positions =
      StreamController<Duration>.broadcast();
  final StreamController<PlayerState> playerStates =
      StreamController<PlayerState>.broadcast();
  final StreamController<Duration?> durations =
      StreamController<Duration?>.broadcast();
  final StreamController<PlaybackQueue?> _queueController =
      StreamController<PlaybackQueue?>.broadcast();

  /// The sermons [play] was asked for, in order.
  List<Sermon> get playCalls => [for (final call in calls) call.sermon];

  @override
  Sermon? get currentSermon => current;

  @override
  Duration get position => positionValue;

  @override
  PlaybackQueue? get queue => _queue;

  @override
  Stream<PlaybackQueue?> get queueStream => _queueController.stream;

  @override
  PlaybackFailure? get failure => null;

  @override
  Stream<PlaybackFailure?> get failureStream => const Stream.empty();

  @override
  Stream<PlayerState> get playerStateStream => playerStates.stream;

  @override
  Stream<Duration> get positionStream => positions.stream;

  @override
  Stream<Duration?> get durationStream => durations.stream;

  @override
  double get speed => _speed;

  @override
  Stream<double> get speedStream => const Stream.empty();

  @override
  bool get repeatOne => _repeatOne;

  @override
  Stream<bool> get repeatOneStream => const Stream.empty();

  void _setQueue(PlaybackQueue? queue) {
    _queue = queue;
    _queueController.add(queue);
  }

  @override
  Future<bool> play(
    Sermon sermon, {
    Duration? startAt,
    List<Sermon>? queue,
  }) async {
    calls.add(PlayCall(sermon, startAt: startAt, queue: queue));
    if (!playResult) return false;
    current = sermon;
    _setQueue(PlaybackQueue.from(sermon, queue));
    if (startAt != null) positionValue = startAt;
    return true;
  }

  @override
  Future<bool> retry() async => false;

  @override
  Future<void> loadPaused(Sermon sermon) async {}

  @override
  Future<void> skipToNext() async {
    nextCalls++;
    final queue = _queue;
    if (queue == null || !queue.hasNext) return;
    _setQueue(queue.moveTo(queue.index + 1));
    current = _queue!.current;
    positionValue = Duration.zero;
  }

  @override
  Future<void> skipToPrevious() async {
    previousCalls++;
    final queue = _queue;
    if (queue == null) return;
    switch (queue.previousAction(positionValue)) {
      case PreviousAction.restart:
        positionValue = Duration.zero;
        seekCalls.add(Duration.zero);
      case PreviousAction.previousItem:
        _setQueue(queue.moveTo(queue.index - 1));
        current = _queue!.current;
        positionValue = Duration.zero;
      case PreviousAction.none:
        return;
    }
  }

  @override
  Future<void> pause() async {
    pauseCalls++;
  }

  @override
  Future<void> resume() async {
    resumeCalls++;
    resumed = true;
  }

  @override
  Future<void> stop() async {
    stopCalls++;
    current = null;
    _setQueue(null);
  }

  @override
  Future<void> seek(Duration position) async {
    seekCalls.add(position);
    positionValue = position;
  }

  @override
  Future<void> setSpeed(double speed) async {
    speedCalls.add(speed);
    _speed = speed;
  }

  @override
  Future<void> setRepeatOne(bool enabled) async {
    _repeatOne = enabled;
  }

  @override
  Future<void> dispose() async {}
}
