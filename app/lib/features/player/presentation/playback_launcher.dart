import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kharis_app/core/services/notification_service.dart';
import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/features/player/data/audio_player_service.dart';
import 'package:kharis_app/shared/models/sermon.dart';
import 'package:kharis_app/shared/providers/audio_provider.dart';

/// Starts audio playback of [sermon], and tells the member when it fails.
///
/// Every list that plays a message goes through here, so a failed load is never
/// silent: the sermon stays loaded in the player with a retry affordance, and
/// this surfaces the reason over whichever screen the tap came from.
Future<void> startPlayback(WidgetRef ref, Sermon sermon) =>
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
