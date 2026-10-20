import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kharis_app/features/home/presentation/screens/clip_player_screen.dart';
import 'package:kharis_app/features/home/presentation/screens/home_screen.dart';
import 'package:kharis_app/features/player/presentation/screens/media_player_screen.dart';
import 'package:kharis_app/shared/providers/audio_provider.dart';
import 'package:kharis_app/shared/providers/sound_focus_provider.dart';

import '../support/actions.dart';
import '../support/harness.dart';

/// (m) One sound at a time on a real device: a message playing pauses when
/// the Home clip opens full screen, and again when the Home video is
/// unmuted; a message starting mutes the Home video.
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

  // The Home clip full screen takes the sound: the message pauses.
  await t.tap(find.byKey(const Key('home-hero-pager')), warnIfMissed: false);
  await pumpUntilFound(t, find.byType(ClipPlayerScreen));
  j.check(
    await pumpUntil(
      t,
      () => !audioPlaying(),
      timeout: const Duration(seconds: 10),
    ),
    'opening the clip pauses the message',
  );
  await pumpFor(t, const Duration(seconds: 5));
  await j.shot('clip-playing-message-paused');
  await t.tap(find.byKey(const Key('clip-player-close')));
  await pumpFor(t, const Duration(seconds: 2));

  // Unmuting the Home video takes the sound: the message pauses again.
  await audio.resume();
  j.check(
    await pumpUntil(t, audioPlaying, timeout: const Duration(seconds: 20)),
    'the message resumes',
  );
  // The hero may have moved on to an event flyer (it advances while a clip
  // is not playing): swipe back to a video slide, which has the mute chip.
  final mute = find.byKey(const Key('home-hero-mute'));
  for (var i = 0; i < 6 && mute.evaluate().isEmpty; i++) {
    await t.drag(
      find.byKey(const Key('home-hero-pager')),
      const Offset(400, 0),
      warnIfMissed: false,
    );
    await pumpFor(t, const Duration(seconds: 3));
  }
  if (await pumpUntil(
    t,
    () => mute.evaluate().isNotEmpty,
    timeout: const Duration(seconds: 20),
  )) {
    await t.tap(mute);
    await t.pump();
    j.check(
      await pumpUntil(
        t,
        () => !audioPlaying(),
        timeout: const Duration(seconds: 10),
      ),
      'unmuting the Home video pauses the message',
    );
    j.check(
      find.byIcon(Icons.volume_up_rounded).evaluate().isNotEmpty,
      'the Home video is unmuted',
    );
    await j.shot('home-video-unmuted');

    // The message starting again re-mutes the Home video.
    await audio.resume();
    j.check(
      await pumpUntil(
        t,
        () => find.byIcon(Icons.volume_off_rounded).evaluate().isNotEmpty,
        timeout: const Duration(seconds: 20),
      ),
      'the message starting mutes the Home video',
    );
    await j.shot('message-playing-video-muted');
  } else {
    j.check(false, 'the Home video shows its mute button (a clip is live)');
  }
  await audio.stop();
}
