import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kharis_app/features/home/presentation/screens/home_screen.dart';
import 'package:kharis_app/features/player/presentation/screens/media_player_screen.dart';
import 'package:kharis_app/shared/providers/audio_provider.dart';
import 'package:kharis_app/shared/providers/sound_focus_provider.dart';

import '../support/actions.dart';
import '../support/harness.dart';

/// (m) One sound at a time on a real device, from Home: the latest
/// message's Listen plays its audio and holds the sound; a Moment (a short
/// from Home) takes the sound, so the audio pauses; the latest message's
/// Watch does the same.
Future<void> mediaFocusJourney(Journey j) async {
  final t = j.tester;
  await j.launch();
  await pumpUntilFound(t, find.byType(HomeScreen));

  bool audioPlaying() =>
      j.c.read(playerStateProvider).valueOrNull?.playing ?? false;
  final audio = j.c.read(audioPlayerServiceProvider);
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

  /// The latest message's Listen on Home: the message plays as audio and
  /// holds the sound once the player is closed again.
  Future<void> listen(String why) async {
    t.state<ScrollableState>(home).position.jumpTo(0);
    await pumpFor(t, const Duration(milliseconds: 600));
    final listen = find.byKey(const Key('home-hero-listen'));
    await pumpUntilFound(t, listen, reason: 'Home\u2019s Listen');
    await t.tap(listen, warnIfMissed: false);
    await pumpUntilFound(t, find.byType(MediaPlayerScreen));
    j.check(
      await pumpUntil(t, audioPlaying, timeout: const Duration(seconds: 40)),
      'the message plays ($why)',
    );
    j.check(
      j.c.read(soundFocusProvider) == kAudioSoundOwner,
      'the message holds the sound ($why)',
    );
    await closePlayer(t);
    await pumpFor(t, const Duration(seconds: 1));
    j.check(
      audioPlaying() && j.c.read(soundFocusProvider) == kAudioSoundOwner,
      'closing the player leaves the message playing with the sound ($why)',
    );
  }

  await listen('Listen');
  await j.shot('home-message-playing');

  // ── A Moment takes the sound ─────────────────────────────────────────────
  final moment = find.byWidgetPredicate(
    (w) =>
        w.key is ValueKey &&
        '${(w.key! as ValueKey).value}'.startsWith('home-moment-'),
  );
  var momentShown = true;
  try {
    await scrollUntilFound(
      t,
      moment,
      scrollable: home,
      timeout: const Duration(seconds: 30),
    );
  } on TestFailure {
    momentShown = false;
  }
  if (!momentShown) {
    j.note('DATA: Home shows no Moments this run; the short is not checked');
  } else {
    await tapVisible(t, moment);
    await pumpUntilFound(t, find.byType(MediaPlayerScreen));
    j.check(
      await pumpUntil(
        t,
        () => !audioPlaying(),
        timeout: const Duration(seconds: 30),
      ),
      'a Moment takes the sound: the message pauses',
    );
    await pumpFor(t, const Duration(seconds: 3));
    await j.shot('moment-playing');
    await closePlayer(t);
    await listen('Listen again');
  }

  // ── The latest message's video takes the sound ───────────────────────────
  t.state<ScrollableState>(home).position.jumpTo(0);
  await pumpFor(t, const Duration(milliseconds: 600));
  final watch = find.byKey(const Key('home-hero-watch'));
  if (watch.evaluate().isEmpty) {
    j.note('DATA: the latest message has no video; Watch is not checked');
  } else {
    await t.tap(watch, warnIfMissed: false);
    await pumpUntilFound(t, find.byType(MediaPlayerScreen));
    j.check(
      await pumpUntil(
        t,
        () => !audioPlaying(),
        timeout: const Duration(seconds: 30),
      ),
      'Watch takes the sound: the message audio pauses',
    );
    await pumpFor(t, const Duration(seconds: 4));
    await j.shot('hero-video-playing');
    await closePlayer(t);
  }
  await audio.stop();
}
