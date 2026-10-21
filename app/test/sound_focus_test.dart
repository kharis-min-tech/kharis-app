import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart' show PlayerState, ProcessingState;

import 'package:kharis_app/shared/providers/audio_provider.dart';
import 'package:kharis_app/shared/providers/sound_focus_provider.dart';

import 'support/fake_audio_player_service.dart';
import 'support/fake_sermon_repository.dart';

/// One sound at a time: a message playing holds the app's sound, and any
/// other source that starts with sound pauses it.
void main() {
  test('a message playing takes the sound; another source taking it pauses '
      'the message; a finished message gives it back', () async {
    final audio = FakeAudioPlayerService()..current = testSermon('m1');
    final c = ProviderContainer(
      overrides: [audioPlayerServiceProvider.overrideWithValue(audio)],
    );
    addTearDown(c.dispose);
    c.listen(audioSoundFocusProvider, (_, _) {});
    c.listen(playerStateProvider, (_, _) {});

    audio.playerStates.add(PlayerState(true, ProcessingState.ready));
    await Future<void>.delayed(Duration.zero);
    expect(c.read(soundFocusProvider), kAudioSoundOwner);

    final clip = Object();
    c.read(soundFocusProvider.notifier).claim(clip);
    await Future<void>.delayed(Duration.zero);
    expect(audio.pauseCalls, 1);
    expect(c.read(soundFocusProvider), clip);

    // A stale release from a source that already yielded changes nothing.
    c.read(soundFocusProvider.notifier).release(kAudioSoundOwner);
    expect(c.read(soundFocusProvider), clip);
  });
}
