import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kharis_app/core/services/notification_service.dart';
import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/features/player/data/audio_player_service.dart';
import 'package:kharis_app/features/player/presentation/screens/media_player_screen.dart';
import 'package:kharis_app/shared/models/sermon.dart';
import 'package:kharis_app/shared/providers/audio_provider.dart';

/// Opens the unified player for [sermon] and starts the right engine.
///
/// Every list that plays a message goes through here, so every tap lands on
/// the same [MediaPlayerScreen]:
/// - audio (with or without a video option): the audio load kicks off first,
///   then the screen opens in audio mode and attaches to that load;
/// - video-only: the screen opens straight in video mode — the sermon never
///   reaches [AudioPlayerService.play], so the old "video only" failure
///   cannot appear;
/// - no media at all: no screen; the failure snackbar explains.
///
/// The returned future completes when the audio load settles (immediately for
/// video-only), preserving the old contract for callers that await it.
Future<void> startPlayback(WidgetRef ref, Sermon sermon) {
  // Reentry latch: a double-tap fires a second call before the incoming route
  // covers the row. Without this, each tap stacks another MediaPlayerScreen —
  // and in video mode each stacked screen autoplays its own YouTube engine.
  // Popping the player clears the latch via [Route.isActive].
  final active = _playerRoute;
  if (active != null && active.isActive) return Future.value();

  // Root navigator: the player overlays the tab shell, like the /player route.
  final navigator = Navigator.of(ref.context, rootNavigator: true);

  if (!sermon.hasAudio && sermon.hasVideo) {
    _pushPlayer(navigator, sermon, MediaMode.video);
    return Future.value();
  }

  final started = startAudioPlayback(ref, sermon);
  if (sermon.hasAudio) {
    _pushPlayer(navigator, sermon, MediaMode.audio);
  }
  return started;
}

/// The player route currently on the navigator, if any. See [startPlayback].
Route<void>? _playerRoute;

void _pushPlayer(NavigatorState navigator, Sermon sermon, MediaMode mode) {
  final route = MaterialPageRoute<void>(
    builder: (_) => MediaPlayerScreen(sermon: sermon, mode: mode),
  );
  _playerRoute = route;
  unawaited(navigator.push(route));
}

/// Starts audio playback of [sermon] without touching navigation, and tells
/// the member when it fails. Used by [startPlayback] and by the player screen
/// when the member toggles from video back to audio.
Future<void> startAudioPlayback(WidgetRef ref, Sermon sermon) =>
    _start(ref.read(audioPlayerServiceProvider), sermon);

/// Holds the service rather than the [WidgetRef] so a retry still works after
/// the list that started playback has been scrolled away or unmounted. The
/// service is root-scoped, so it outlives every screen.
///
/// Uses [kharisMessengerKey] for the same reason: no [BuildContext] is
/// captured.
Future<void> _start(AudioPlayerService service, Sermon sermon) async {
  if (await service.play(sermon)) return;

  final failure = service.failure;
  // No failure recorded, or it belongs to a newer request: that request owns
  // the message the member is actually waiting on.
  if (failure == null || failure.sermonId != sermon.id) return;

  kharisMessengerKey.currentState
    ?..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(failure.message),
        backgroundColor: AppColors.errorContainer,
        duration: const Duration(seconds: 6),
        action: sermon.hasAudio
            ? SnackBarAction(
                label: 'Retry',
                onPressed: () => _start(service, sermon),
              )
            : null,
      ),
    );
}
