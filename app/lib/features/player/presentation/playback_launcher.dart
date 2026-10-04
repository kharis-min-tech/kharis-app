import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kharis_app/core/services/notification_service.dart';
import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/features/player/data/audio_player_service.dart';
import 'package:kharis_app/features/player/presentation/screens/media_player_screen.dart';
import 'package:kharis_app/shared/models/sermon.dart';
import 'package:kharis_app/shared/providers/audio_provider.dart';
import 'package:kharis_app/shared/providers/sermon_provider.dart';

export 'package:kharis_app/features/player/presentation/media_mode.dart';

/// Opens the unified player for [sermon] and starts the right engine.
///
/// Every list that plays a message goes through here, so every tap lands on
/// the same [MediaPlayerScreen]:
/// - audio (with or without a video option): the audio load kicks off first,
///   then the screen opens in audio mode and attaches to that load;
/// - video (requested via [mode], or the only medium): the screen opens
///   straight in video mode and the sermon never reaches
///   [AudioPlayerService.play];
/// - no media at all: no screen; the failure snackbar explains.
///
/// [queue] is the list the member launched from (a playlist, search results,
/// a Messages section); Previous / Next walk it. Null falls back to the
/// library order, newest first. Re-tapping the message already playing just
/// opens the player and resumes, without reloading.
///
/// The returned future completes when the audio load settles (immediately for
/// video), never waiting for playback itself to end.
Future<void> startPlayback(
  BuildContext context,
  WidgetRef ref,
  Sermon sermon, {
  List<Sermon>? queue,
  MediaMode? mode,
}) {
  // Reentry latch: a double-tap fires a second call before the incoming route
  // covers the row. Without this, each tap stacks another MediaPlayerScreen —
  // and in video mode each stacked screen autoplays its own YouTube engine.
  // Popping the player clears the latch via [Route.isActive].
  final active = _playerRoute;
  if (active != null && active.isActive) return Future.value();

  // Root navigator: the player overlays the tab shell, like the /player route.
  final navigator = Navigator.of(context, rootNavigator: true);
  final items = resolvePlaybackQueue(ref, queue);

  if (resolveInitialMode(sermon, mode) == MediaMode.video) {
    _pushPlayer(navigator, sermon, MediaMode.video, items);
    return Future.value();
  }

  final started = _start(
    ref.read(audioPlayerServiceProvider),
    sermon,
    queue: items,
  );
  if (sermon.hasAudio) {
    _pushPlayer(navigator, sermon, MediaMode.audio, items);
  }
  return started;
}

/// The queue for a launch: the caller's list, else the library order
/// (`sermonsProvider`, newest first). Empty while the library is loading;
/// the message then plays on its own.
List<Sermon> resolvePlaybackQueue(WidgetRef ref, List<Sermon>? queue) =>
    queue ?? ref.read(sermonsProvider).valueOrNull ?? const <Sermon>[];

/// The player route currently on the navigator, if any. See [startPlayback].
Route<void>? _playerRoute;

void _pushPlayer(
  NavigatorState navigator,
  Sermon sermon,
  MediaMode mode,
  List<Sermon> queue,
) {
  final route = MaterialPageRoute<void>(
    builder: (_) => MediaPlayerScreen(sermon: sermon, mode: mode, queue: queue),
  );
  _playerRoute = route;
  unawaited(navigator.push(route));
}

/// Starts audio playback of [sermon] without touching navigation, and tells
/// the member when it fails. Used by [startPlayback] and by the player screen
/// when the member toggles from video back to audio or skips in video mode.
///
/// [startAt] wins over the saved resume point (engine handoffs, note
/// anchors); [queue] is what Previous / Next walk.
Future<void> startAudioPlayback(
  WidgetRef ref,
  Sermon sermon, {
  Duration? startAt,
  List<Sermon>? queue,
}) => _start(
  ref.read(audioPlayerServiceProvider),
  sermon,
  startAt: startAt,
  queue: queue,
);

/// Holds the service rather than the [WidgetRef] so a retry still works after
/// the list that started playback has been scrolled away or unmounted. The
/// service is root-scoped, so it outlives every screen.
///
/// Uses [kharisMessengerKey] for the same reason: no [BuildContext] is
/// captured.
Future<void> _start(
  AudioPlayerService service,
  Sermon sermon, {
  Duration? startAt,
  List<Sermon>? queue,
}) async {
  if (await service.play(sermon, startAt: startAt, queue: queue)) return;

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
                onPressed: () => _start(service, sermon, queue: queue),
              )
            : null,
      ),
    );
}
