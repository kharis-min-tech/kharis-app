import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

import 'package:kharis_app/features/player/data/audio_player_service.dart';
import 'package:kharis_app/features/player/data/time_skip.dart';
import 'package:kharis_app/shared/models/sermon.dart';

/// The OS media controls (Android's media notification, the iOS lock screen
/// and Control Center, CarPlay, headset buttons) bound to the app's
/// [AudioPlayerService].
///
/// Mirrors the service onto [playbackState], [mediaItem] and [queue], and
/// routes every control into the same service methods the in-app buttons
/// call. `AudioService.init` creates the one instance in `main`, before any
/// player exists; the service [attach]es itself once the app creates it.
/// Tests construct it directly, without the platform.
class KharisAudioHandler extends BaseAudioHandler
    with QueueHandler, SeekHandler {
  /// Skip back [TimeSkip.back]. The interval the OS shows comes from
  /// `AudioServiceConfig.rewindInterval`.
  static const MediaControl skipBack = MediaControl(
    androidIcon: 'drawable/audio_service_fast_rewind',
    label: 'Back 15 seconds',
    action: MediaAction.rewind,
  );

  /// Skip forward [TimeSkip.forward] (`fastForwardInterval`).
  static const MediaControl skipForward = MediaControl(
    androidIcon: 'drawable/audio_service_fast_forward',
    label: 'Forward 30 seconds',
    action: MediaAction.fastForward,
  );

  /// Registers the app's one handler with the OS. Call once, before any
  /// player is created. The intervals are what the iOS lock screen and
  /// Control Center label their skip buttons with.
  static Future<KharisAudioHandler> init() => AudioService.init(
    builder: KharisAudioHandler.new,
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.kharis.church.channel.audio',
      androidNotificationChannelName: 'Kharis audio playback',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
      rewindInterval: TimeSkip.back,
      fastForwardInterval: TimeSkip.forward,
    ),
  );

  AudioPlayerService? _service;
  final List<StreamSubscription<Object?>> _subscriptions = [];

  /// The queue last published to [queue], so it is rebuilt only when the
  /// member starts from another list.
  List<Sermon>? _publishedItems;

  /// Binds the OS controls to [service], replacing any earlier binding.
  void attach(AudioPlayerService service) {
    _unbind();
    _service = service;
    void refresh(Object? _) => _broadcast();
    _subscriptions.addAll([
      service.playbackEventStream.listen(refresh, onError: _ignore),
      service.playerStateStream.listen(refresh, onError: _ignore),
      service.queueStream.listen(refresh),
      service.failureStream.listen(refresh),
      service.durationStream.listen(refresh, onError: _ignore),
      service.speedStream.listen(refresh, onError: _ignore),
    ]);
    _broadcast();
  }

  /// Unbinds [service] (it is being disposed) and clears the OS controls.
  void detach(AudioPlayerService service) {
    if (!identical(_service, service)) return;
    _unbind();
    _broadcast();
  }

  void _unbind() {
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    _subscriptions.clear();
    _service = null;
  }

  static void _ignore(Object _) {}

  // ── Service -> OS ──────────────────────────────────────────────────────────

  void _broadcast() {
    final service = _service;
    final sermon = service?.currentSermon;
    if (service == null || sermon == null) {
      // Idle takes the notification down and releases Now Playing.
      _publishedItems = null;
      if (queue.value.isNotEmpty) queue.add(const []);
      if (mediaItem.value != null) mediaItem.add(null);
      playbackState.add(PlaybackState());
      return;
    }

    final items = service.queue?.items;
    if (!identical(items, _publishedItems)) {
      _publishedItems = items;
      queue.add([for (final s in items ?? const <Sermon>[]) itemFor(s)]);
    }
    final item = itemFor(sermon, duration: service.duration);
    final shown = mediaItem.value;
    // MediaItem equality is by id only; a length learned later must still
    // reach the seek bar.
    if (shown == null ||
        shown.id != item.id ||
        shown.duration != item.duration) {
      mediaItem.add(item);
    }
    playbackState.add(_stateOf(service));
  }

  /// [sermon] as the OS shows it: title, speaker as artist, series as album,
  /// artwork and length ([duration] when the catalogue has none).
  static MediaItem itemFor(Sermon sermon, {Duration? duration}) {
    final art = sermon.artworkUrl;
    return MediaItem(
      id: sermon.id,
      title: sermon.title,
      artist: sermon.speaker,
      album: sermon.series ?? 'Kharis Church',
      artUri: art != null ? Uri.tryParse(art) : null,
      duration: sermon.duration ?? duration,
    );
  }

  static PlaybackState _stateOf(AudioPlayerService service) {
    final playbackQueue = service.queue;
    final hasPrevious = playbackQueue?.hasPrevious ?? false;
    final hasNext = playbackQueue?.hasNext ?? false;
    final failed = service.failure != null;
    final engine = service.processingState;
    // As the in-app button: a failed, finished or released engine offers
    // Play, whatever just_audio's playing flag says.
    final playing =
        service.playing &&
        !failed &&
        engine != ProcessingState.completed &&
        engine != ProcessingState.idle;
    final first = hasPrevious ? 1 : 0;
    return PlaybackState(
      controls: [
        if (hasPrevious) MediaControl.skipToPrevious,
        skipBack,
        playing ? MediaControl.pause : MediaControl.play,
        skipForward,
        if (hasNext) MediaControl.skipToNext,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
        MediaAction.stop,
      },
      androidCompactActionIndices: [first, first + 1, first + 2],
      processingState: _processingOf(engine, failed: failed),
      playing: playing,
      updatePosition: service.position,
      bufferedPosition: service.bufferedPosition,
      speed: service.speed,
      queueIndex: playbackQueue?.index,
    );
  }

  /// A message is loaded whenever this is asked, so the engine idling (a
  /// failed load released it, or a failed stream stopped it) reads as ready
  /// and paused: the notification keeps the message with Play, which
  /// retries. Idle would take the notification down.
  static AudioProcessingState _processingOf(
    ProcessingState engine, {
    required bool failed,
  }) {
    if (failed) return AudioProcessingState.ready;
    return switch (engine) {
      ProcessingState.idle => AudioProcessingState.ready,
      ProcessingState.loading => AudioProcessingState.loading,
      ProcessingState.buffering => AudioProcessingState.buffering,
      ProcessingState.ready => AudioProcessingState.ready,
      ProcessingState.completed => AudioProcessingState.completed,
    };
  }

  // ── OS -> service ──────────────────────────────────────────────────────────

  @override
  Future<void> play() async => _service?.resume();

  @override
  Future<void> pause() async => _service?.pause();

  @override
  Future<void> seek(Duration position) async => _service?.seek(position);

  @override
  Future<void> rewind() async => _service?.seekBy(-TimeSkip.back);

  @override
  Future<void> fastForward() async => _service?.seekBy(TimeSkip.forward);

  @override
  Future<void> skipToNext() async => _service?.skipToNext();

  @override
  Future<void> skipToPrevious() async => _service?.skipToPrevious();

  /// A tap on a queue entry (Android Auto, CarPlay): plays it in the same
  /// queue, as a tap in Up next does.
  @override
  Future<void> skipToQueueItem(int index) async {
    final service = _service;
    final playbackQueue = service?.queue;
    if (service == null || playbackQueue == null) return;
    if (index < 0 || index >= playbackQueue.items.length) return;
    if (index == playbackQueue.index) return;
    await service.play(playbackQueue.items[index], queue: playbackQueue.items);
  }

  @override
  Future<void> stop() async {
    await _service?.stop();
    await super.stop();
  }
}
