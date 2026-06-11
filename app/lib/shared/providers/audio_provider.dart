import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../models/sermon.dart';
import '../../features/player/data/audio_player_service.dart';
import 'cache_provider.dart';

/// Singleton [AudioPlayerService] scoped to the widget tree root.
/// Disposed automatically when the provider scope is destroyed.
final audioPlayerServiceProvider = Provider<AudioPlayerService>((ref) {
  final cache = ref.read(cacheServiceProvider);
  final service = AudioPlayerService(cache);
  ref.onDispose(() => service.dispose());
  return service;
});

/// Currently loaded [Sermon], or null when nothing is queued.
///
/// Note: this is a plain [Provider] — it reflects the snapshot at read time.
/// For reactive UI updates, combine with [playerStateProvider] which fires
/// on every state transition and forces dependent widgets to re-evaluate.
final currentSermonProvider = Provider<Sermon?>((ref) {
  // Re-read on every playerState change so widgets stay in sync.
  ref.watch(playerStateProvider);
  return ref.read(audioPlayerServiceProvider).currentSermon;
});

/// Emits [PlayerState] on every just_audio playback transition.
final playerStateProvider = StreamProvider<PlayerState>((ref) {
  return ref.watch(audioPlayerServiceProvider).playerStateStream;
});

/// Emits the current playback position, updated ~200 ms by just_audio.
final positionProvider = StreamProvider<Duration>((ref) {
  return ref.watch(audioPlayerServiceProvider).positionStream;
});

/// Emits the total duration of the loaded source; null until known.
final durationProvider = StreamProvider<Duration?>((ref) {
  return ref.watch(audioPlayerServiceProvider).durationStream;
});
