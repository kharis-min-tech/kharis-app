import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kharis_app/features/home/presentation/screens/home_screen.dart';
import 'package:kharis_app/features/player/presentation/screens/media_player_screen.dart';
import 'package:kharis_app/shared/providers/audio_provider.dart';
import 'package:kharis_app/shared/providers/sound_focus_provider.dart';

import '../support/actions.dart';
import '../support/harness.dart';

/// (m) One sound at a time on a real device, from the Home hero wall: a
/// message playing as audio; a tap on the wall opens the latest message's
/// video, which takes the sound, so the audio pauses. The wall itself never
/// takes the sound (its videos are silent).
Future<void> mediaFocusJourney(Journey j) async {
  final t = j.tester;
  await j.launch();
  await pumpUntilFound(t, find.byType(HomeScreen));
  await pumpFor(t, const Duration(seconds: 4));

  bool audioPlaying() =>
      j.c.read(playerStateProvider).valueOrNull?.playing ?? false;
  final audio = j.c.read(audioPlayerServiceProvider);

  // A message from Home's latest messages.
  final tile = find.byWidgetPredicate(
    (w) =>
        w.key is ValueKey &&
        '${(w.key! as ValueKey).value}'.startsWith('home-message-'),
  );
  final home = find
      .descendant(
        of: find.byType(HomeScreen),
        matching: find.byWidgetPredicate(
          (w) =>
              w is Scrollable &&
              axisDirectionToAxis(w.axisDirection) == Axis.vertical,
        ),
      )
      .first;
  await scrollUntilFound(t, tile, scrollable: home);
  await t.tap(tile.first, warnIfMissed: false);
  await pumpUntilFound(t, find.byType(MediaPlayerScreen));
  j.check(
    await pumpUntil(t, audioPlaying, timeout: const Duration(seconds: 40)),
    'the message plays',
  );
  j.check(
    j.c.read(soundFocusProvider) == kAudioSoundOwner,
    'the message holds the sound',
  );
  await closePlayer(t);
  await pumpFor(t, const Duration(seconds: 1));
  t.state<ScrollableState>(home).position.jumpTo(0);
  await pumpFor(t, const Duration(seconds: 2));

  j.check(
    j.c.read(soundFocusProvider) == kAudioSoundOwner,
    'the silent hero wall leaves the message the sound',
  );
  await j.shot('home-wall-message-playing');

  // A tap on the wall plays the latest message's video: the audio pauses.
  await t.tap(find.byKey(const Key('home-hero-wall')), warnIfMissed: false);
  await pumpUntilFound(t, find.byType(MediaPlayerScreen));
  j.check(
    await pumpUntil(
      t,
      () => !audioPlaying(),
      timeout: const Duration(seconds: 30),
    ),
    'the hero\'s video takes the sound: the message pauses',
  );
  await pumpFor(t, const Duration(seconds: 4));
  await j.shot('hero-video-playing');
  await closePlayer(t);
  await audio.stop();
}
