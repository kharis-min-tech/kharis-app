import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/shared/providers/audio_provider.dart';

/// The player's error state: why the loaded message would not play, and a way
/// to try again without restarting the app.
///
/// Renders nothing while playback is healthy, so it can sit permanently in a
/// player layout. Like the toasts, it keeps a fixed deep-red plate in both
/// brightnesses rather than flipping with the theme.
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

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: AppColors.errorContainer,
        borderRadius: BorderRadius.circular(AppRadius.tile),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 20,
            color: AppColors.error,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              failure.message,
              style: AppTypography.ui(
                size: 12.5,
                height: 1.35,
                color: AppColors.onSurface,
              ),
            ),
          ),
          if (canRetry)
            TextButton(
              onPressed: () => service.retry(),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.secondary,
                minimumSize: const Size(64, 40),
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              child: Text(
                'Retry',
                style: AppTypography.ui(
                  size: 13,
                  weight: FontWeight.w700,
                  color: AppColors.secondary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
