import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart' show ProcessingState;

import 'audio_provider.dart';

/// Who is playing with sound right now: one source at a time across the
/// app (a message's audio, a message's video, a full-screen clip, the Home
/// video unmuted). A source [claim]s it as it starts making sound; every
/// other source watches [soundFocusProvider] and pauses (or mutes) the
/// moment the owner is someone else. A silent preview never claims it.
class SoundFocus extends StateNotifier<Object?> {
  SoundFocus() : super(null);

  /// [owner] is now the one source with sound; whoever held it yields.
  void claim(Object owner) {
    if (mounted && state != owner) state = owner;
  }

  /// [owner] stopped making sound; nobody holds the sound until the next
  /// claim. A stale release from a source that already yielded is ignored.
  void release(Object owner) {
    // A release deferred past teardown finds nothing left to update.
    if (mounted && state == owner) state = null;
  }
}

final soundFocusProvider = StateNotifierProvider<SoundFocus, Object?>(
  (ref) => SoundFocus(),
);

/// The message audio engine's identity in [soundFocusProvider].
const Object kAudioSoundOwner = #audio;

/// Binds the message audio engine to [soundFocusProvider]: playing audio
/// claims the sound; anyone else claiming it pauses the audio. Kept alive
/// by the app root.
final audioSoundFocusProvider = Provider<void>((ref) {
  ref.listen(playerStateProvider, (_, next) {
    final state = next.valueOrNull;
    if (state == null) return;
    final focus = ref.read(soundFocusProvider.notifier);
    if (state.playing && state.processingState != ProcessingState.completed) {
      focus.claim(kAudioSoundOwner);
    } else {
      focus.release(kAudioSoundOwner);
    }
  });
  ref.listen(soundFocusProvider, (_, owner) {
    if (owner == null || owner == kAudioSoundOwner) return;
    final audio = ref.read(audioPlayerServiceProvider);
    if (audio.currentSermon != null) unawaited(audio.pause());
  });
});
