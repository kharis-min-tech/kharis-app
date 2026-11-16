import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kharis_app/shared/providers/audio_provider.dart';
import 'package:kharis_app/ui/components/components.dart';

/// The player's error state: why the loaded message would not play, and a way
/// to try again without restarting the app.
///
/// Renders nothing while playback is healthy, so it can sit permanently in a
/// player layout.
class PlaybackErrorBanner extends ConsumerWidget {
  const PlaybackErrorBanner({super.key, this.sermonId});

  /// Only show a failure belonging to this sermon. Null shows whichever
  /// failure the player currently holds.
  final String? sermonId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final failure = ref.watch(playbackFailureProvider).valueOrNull;
    if (failure == null) return const SizedBox.shrink();
    if (sermonId != null && failure.sermonId != sermonId) {
      return const SizedBox.shrink();
    }

    final service = ref.read(audioPlayerServiceProvider);
    final canRetry = service.currentSermon?.hasAudio ?? false;

    return Padding(
      padding: const EdgeInsets.only(bottom: KSpace.x3),
      child: KErrorBanner(
        message: failure.message,
        actions: [
          if (canRetry)
            KBannerAction(label: 'Retry', onPressed: () => service.retry()),
        ],
      ),
    );
  }
}
