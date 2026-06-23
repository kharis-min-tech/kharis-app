import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import 'package:kharis_app/core/theme/app_colors.dart';
import 'package:kharis_app/core/theme/app_typography.dart';
import 'package:kharis_app/shared/providers/audio_provider.dart';

/// Spotify-style playback controls.
///
/// Row layout: shuffle | -15s | play/pause | +15s | repeat
/// The play/pause button is a 64-px filled circle (AppColors.heading) with a
/// dark icon. A small spinner replaces the icon during loading/buffering.
/// Shuffle and repeat are local visual toggles only (no backend wiring).
class PlayerControls extends ConsumerStatefulWidget {
  const PlayerControls({super.key});

  @override
  ConsumerState<PlayerControls> createState() => _PlayerControlsState();
}

class _PlayerControlsState extends ConsumerState<PlayerControls> {
  bool _shuffleOn = false;
  bool _repeatOn = false;

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(playerStateProvider).valueOrNull;
    final isPlaying = playerState?.playing ?? false;
    final processingState = playerState?.processingState;
    final isBuffering = processingState == ProcessingState.loading ||
        processingState == ProcessingState.buffering;

    final position = ref.watch(positionProvider).valueOrNull ?? Duration.zero;
    final duration =
        ref.watch(durationProvider).valueOrNull ?? Duration.zero;
    final service = ref.read(audioPlayerServiceProvider);

    void seekRelative(int seconds) {
      final newPos = position + Duration(seconds: seconds);
      final clamped = Duration(
        milliseconds: newPos.inMilliseconds.clamp(0, duration.inMilliseconds),
      );
      service.seek(clamped);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Shuffle toggle (visual only)
          _SecondaryButton(
            icon: Icons.shuffle_rounded,
            active: _shuffleOn,
            onTap: () => setState(() => _shuffleOn = !_shuffleOn),
          ),

          // Skip back 15 seconds
          _SkipButton(
            onPressed: () => seekRelative(-15),
            isForward: false,
          ),

          // Play / Pause
          _PlayPauseButton(
            isPlaying: isPlaying,
            isBuffering: isBuffering,
            onTap: () => isPlaying ? service.pause() : service.resume(),
          ),

          // Skip forward 15 seconds
          _SkipButton(
            onPressed: () => seekRelative(15),
            isForward: true,
          ),

          // Repeat toggle (visual only)
          _SecondaryButton(
            icon: Icons.repeat_rounded,
            active: _repeatOn,
            onTap: () => setState(() => _repeatOn = !_repeatOn),
          ),
        ],
      ),
    );
  }
}

// ── Play / Pause circle button ────────────────────────────────────────────────

class _PlayPauseButton extends StatelessWidget {
  const _PlayPauseButton({
    required this.isPlaying,
    required this.isBuffering,
    required this.onTap,
  });

  final bool isPlaying;
  final bool isBuffering;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 64,
        height: 64,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.heading,
        ),
        alignment: Alignment.center,
        child: isBuffering
            ? SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppColors.canvas,
                  ),
                ),
              )
            : Icon(
                isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: AppColors.canvas,
                size: 34,
              ),
      ),
    );
  }
}

// ── Skip +/- 15 seconds button ────────────────────────────────────────────────

class _SkipButton extends StatelessWidget {
  const _SkipButton({
    required this.onPressed,
    required this.isForward,
  });

  final VoidCallback onPressed;
  final bool isForward;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: SizedBox(
        width: 44,
        height: 44,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(
              isForward ? Icons.forward_rounded : Icons.replay_rounded,
              color: Colors.white,
              size: 32,
            ),
            Positioned(
              bottom: 6,
              child: Text(
                '15',
                style: AppTypography.labelMd.copyWith(
                  fontSize: 8,
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  height: 1,
                  letterSpacing: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Secondary icon button (shuffle / repeat) ──────────────────────────────────

class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({
    required this.icon,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 36,
        height: 36,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(
              icon,
              color: active ? AppColors.secondary : AppColors.textFaint,
              size: 22,
            ),
            // Active indicator dot below the icon
            if (active)
              Positioned(
                bottom: 4,
                child: Container(
                  width: 4,
                  height: 4,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.secondary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
