import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:just_audio_platform_interface/just_audio_platform_interface.dart';

/// A just_audio platform with no native engine, so the REAL
/// `AudioPlayerService` (and just_audio's own `AudioPlayer`) can run in a
/// test. Behaves like the native players where it matters:
///
/// - `play()` completes only when playback pauses, stops or completes — the
///   exact behaviour that made `await _player.play()` block its callers;
/// - `seek(index:)`, concatenating inserts and removals move `currentIndex`
///   the way ExoPlayer / AVQueuePlayer do.
///
/// Positions do not advance on their own; tests [FakeAudioPlatformPlayer.seek]
/// or call [FakeAudioPlatformPlayer.complete].
class FakeJustAudioPlatform extends JustAudioPlatform {
  FakeAudioPlatformPlayer? player;

  /// When set, the next load stays in [ProcessingStateMessage.loading] until
  /// this completes: a slow network. Consumed by that one load.
  Future<void>? holdNextLoad;

  /// Installs the fake platform and silences the audio_session channel.
  static FakeJustAudioPlatform install() {
    final platform = FakeJustAudioPlatform();
    JustAudioPlatform.instance = platform;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.ryanheise.audio_session'),
          (_) async => null,
        );
    return platform;
  }

  @override
  Future<AudioPlayerPlatform> init(InitRequest request) async {
    final created = FakeAudioPlatformPlayer(request.id, this);
    player = created;
    return created;
  }

  @override
  Future<DisposePlayerResponse> disposePlayer(
    DisposePlayerRequest request,
  ) async {
    await player?.dispose(DisposeRequest());
    return DisposePlayerResponse();
  }

  @override
  Future<DisposeAllPlayersResponse> disposeAllPlayers(
    DisposeAllPlayersRequest request,
  ) async {
    return DisposeAllPlayersResponse();
  }
}

class FakeAudioPlatformPlayer extends AudioPlayerPlatform {
  FakeAudioPlatformPlayer(super.id, [this._platform]);

  final FakeJustAudioPlatform? _platform;

  /// Bumped per load, so a held load that a newer one replaced resolves
  /// without touching the newer load's state (as the native players do).
  int _loadSerial = 0;

  /// Length every loaded item reports.
  static const Duration itemDuration = Duration(minutes: 30);

  final _events = StreamController<PlaybackEventMessage>.broadcast();

  ProcessingStateMessage _state = ProcessingStateMessage.idle;
  Duration _position = Duration.zero;
  int? _index;
  int _length = 0;
  bool _playing = false;
  Completer<void>? _playCompleter;

  /// Every load request, in order.
  final List<LoadRequest> loads = [];

  /// Every seek request, in order.
  final List<SeekRequest> seeks = [];

  bool get playing => _playing;
  int? get index => _index;
  int get length => _length;
  Duration get position => _position;
  LoopModeMessage loopMode = LoopModeMessage.off;
  double speed = 1.0;

  void _broadcast() {
    _events.add(
      PlaybackEventMessage(
        processingState: _state,
        updatePosition: _position,
        updateTime: DateTime.now(),
        bufferedPosition: _position,
        icyMetadata: null,
        duration: _state == ProcessingStateMessage.idle ? null : itemDuration,
        currentIndex: _index,
        androidAudioSessionId: null,
      ),
    );
  }

  /// Plays the current item to its end (no auto-advance).
  void complete() {
    _position = itemDuration;
    _state = ProcessingStateMessage.completed;
    _broadcast();
    _playCompleter?.complete();
    _playCompleter = null;
  }

  @override
  Stream<PlaybackEventMessage> get playbackEventMessageStream => _events.stream;

  @override
  Future<LoadResponse> load(LoadRequest request) async {
    final serial = ++_loadSerial;
    loads.add(request);
    final source = request.audioSourceMessage;
    _length = source is ConcatenatingAudioSourceMessage
        ? source.children.length
        : 1;
    _state = ProcessingStateMessage.loading;
    _broadcast();
    final hold = _platform?.holdNextLoad;
    _platform?.holdNextLoad = null;
    if (hold != null) await hold;
    await Future<void>.delayed(Duration.zero);
    if (serial != _loadSerial) return LoadResponse(duration: itemDuration);
    _index = request.initialIndex ?? 0;
    _position = request.initialPosition ?? Duration.zero;
    _state = ProcessingStateMessage.ready;
    _broadcast();
    return LoadResponse(duration: itemDuration);
  }

  @override
  Future<PlayResponse> play(PlayRequest request) async {
    if (_playing) return PlayResponse();
    _playing = true;
    _broadcast();
    final completer = _playCompleter = Completer<void>();
    await completer.future;
    return PlayResponse();
  }

  @override
  Future<PauseResponse> pause(PauseRequest request) async {
    _playing = false;
    _broadcast();
    _playCompleter?.complete();
    _playCompleter = null;
    return PauseResponse();
  }

  @override
  Future<SeekResponse> seek(SeekRequest request) async {
    seeks.add(request);
    _position = request.position ?? Duration.zero;
    if (request.index != null) _index = request.index;
    if (_state == ProcessingStateMessage.completed) {
      _state = ProcessingStateMessage.ready;
    }
    _broadcast();
    return SeekResponse();
  }

  @override
  Future<ConcatenatingInsertAllResponse> concatenatingInsertAll(
    ConcatenatingInsertAllRequest request,
  ) async {
    final count = request.children.length;
    final current = _index;
    if (current != null && request.index <= current) _index = current + count;
    _length += count;
    _broadcast();
    return ConcatenatingInsertAllResponse();
  }

  @override
  Future<ConcatenatingRemoveRangeResponse> concatenatingRemoveRange(
    ConcatenatingRemoveRangeRequest request,
  ) async {
    final count = request.endIndex - request.startIndex;
    final current = _index;
    if (current != null && request.endIndex <= current) {
      _index = current - count;
    }
    _length -= count;
    _broadcast();
    return ConcatenatingRemoveRangeResponse();
  }

  @override
  Future<ConcatenatingMoveResponse> concatenatingMove(
    ConcatenatingMoveRequest request,
  ) async => ConcatenatingMoveResponse();

  @override
  Future<DisposeResponse> dispose(DisposeRequest request) async {
    _playing = false;
    _state = ProcessingStateMessage.idle;
    _playCompleter?.complete();
    _playCompleter = null;
    _broadcast();
    return DisposeResponse();
  }

  @override
  Future<SetVolumeResponse> setVolume(SetVolumeRequest request) async =>
      SetVolumeResponse();

  @override
  Future<SetSpeedResponse> setSpeed(SetSpeedRequest request) async {
    speed = request.speed;
    return SetSpeedResponse();
  }

  @override
  Future<SetPitchResponse> setPitch(SetPitchRequest request) async =>
      SetPitchResponse();

  @override
  Future<SetSkipSilenceResponse> setSkipSilence(
    SetSkipSilenceRequest request,
  ) async => SetSkipSilenceResponse();

  @override
  Future<SetLoopModeResponse> setLoopMode(SetLoopModeRequest request) async {
    loopMode = request.loopMode;
    return SetLoopModeResponse();
  }

  @override
  Future<SetShuffleModeResponse> setShuffleMode(
    SetShuffleModeRequest request,
  ) async => SetShuffleModeResponse();

  @override
  Future<SetShuffleOrderResponse> setShuffleOrder(
    SetShuffleOrderRequest request,
  ) async => SetShuffleOrderResponse();

  @override
  Future<SetAutomaticallyWaitsToMinimizeStallingResponse>
  setAutomaticallyWaitsToMinimizeStalling(
    SetAutomaticallyWaitsToMinimizeStallingRequest request,
  ) async => SetAutomaticallyWaitsToMinimizeStallingResponse();

  @override
  Future<SetCanUseNetworkResourcesForLiveStreamingWhilePausedResponse>
  setCanUseNetworkResourcesForLiveStreamingWhilePaused(
    SetCanUseNetworkResourcesForLiveStreamingWhilePausedRequest request,
  ) async => SetCanUseNetworkResourcesForLiveStreamingWhilePausedResponse();

  @override
  Future<SetPreferredPeakBitRateResponse> setPreferredPeakBitRate(
    SetPreferredPeakBitRateRequest request,
  ) async => SetPreferredPeakBitRateResponse();

  @override
  Future<SetAllowsExternalPlaybackResponse> setAllowsExternalPlayback(
    SetAllowsExternalPlaybackRequest request,
  ) async => SetAllowsExternalPlaybackResponse();

  @override
  Future<SetAndroidAudioAttributesResponse> setAndroidAudioAttributes(
    SetAndroidAudioAttributesRequest request,
  ) async => SetAndroidAudioAttributesResponse();
}
