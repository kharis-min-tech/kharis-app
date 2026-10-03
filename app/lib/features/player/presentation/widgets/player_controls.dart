import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/features/player/data/playback_queue.dart';
import 'package:kharis_app/shared/providers/audio_provider.dart';

/// A snapshot of whichever engine currently owns playback, so [PlayerControls]
/// can drive audio (just_audio) and video (YouTube) with one control row.
///
/// Null on [PlayerControls.transport] means the audio service, read reactively
/// from the Riverpod providers. A video host supplies a binding rebuilt from
/// its own streams instead.
@immutable
class TransportBinding {
  const TransportBinding({
    required this.isPlaying,
    required this.isBuffering,
    required this.speed,
    required this.repeatOn,
    required this.onPlay,
    required this.onPause,
    required this.onSetSpeed,
    required this.onToggleRepeat,
    this.onPrevious,
    this.onNext,
  });

  final bool isPlaying;
  final bool isBuffering;
  final double speed;
  final bool repeatOn;
  final VoidCallback onPlay;
  final VoidCallback onPause;
  final ValueChanged<double> onSetSpeed;
  final VoidCallback onToggleRepeat;

  /// Null disables the control (first message, already at its start).
  final VoidCallback? onPrevious;

  /// Null disables the control (last message in the queue).
  final VoidCallback? onNext;
}

/// Transport controls.
///
/// Row layout: speed pill | previous | play/pause | next | repeat.
/// Previous and Next walk the queue the member launched from, Spotify-style:
/// Previous restarts the message once it is past three seconds, otherwise
/// steps back; both disable at the ends of the queue. The play/pause button
/// is a 70-px gold circle with a spinner while buffering. The speed pill
/// cycles 1× → 1.25× → 1.5× → 2× → 0.75× and persists; Repeat loops the
/// current message.
class PlayerControls extends ConsumerWidget {
  const PlayerControls({super.key, this.transport});

  /// The engine these controls operate. Null drives the audio service.
  final TransportBinding? transport;

  static const List<double> speeds = [1, 1.25, 1.5, 2, 0.75];

  /// The speed after [current] in [speeds]; unknown rates restart the cycle.
  static double nextSpeed(double current) {
    final index = speeds.indexWhere((s) => (s - current).abs() < 0.01);
    return speeds[(index + 1) % speeds.length];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final binding = transport ?? _audioBinding(ref);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _SpeedPill(
            speed: binding.speed,
            onTap: () => binding.onSetSpeed(nextSpeed(binding.speed)),
          ),
          _SkipButton(
            icon: Icons.skip_previous_rounded,
            label: 'Previous message',
            onPressed: binding.onPrevious,
          ),
          _PlayPauseButton(
            isPlaying: binding.isPlaying,
            isBuffering: binding.isBuffering,
            onTap: binding.isPlaying ? binding.onPause : binding.onPlay,
          ),
          _SkipButton(
            icon: Icons.skip_next_rounded,
            label: 'Next message',
            onPressed: binding.onNext,
          ),
          _RepeatButton(
            active: binding.repeatOn,
            onTap: binding.onToggleRepeat,
          ),
        ],
      ),
    );
  }

  TransportBinding _audioBinding(WidgetRef ref) {
    final service = ref.read(audioPlayerServiceProvider);
    final playerState = ref.watch(playerStateProvider).valueOrNull;
    final processingState = playerState?.processingState;
    // A finished message is not "playing", whatever the engine's flag says:
    // the button must offer Play, and Play restarts it.
    final isPlaying =
        (playerState?.playing ?? false) &&
        processingState != ProcessingState.completed;
    final queue = ref.watch(playbackQueueProvider).valueOrNull;
    final position = ref.watch(positionProvider).valueOrNull ?? Duration.zero;
    final repeatOn = ref.watch(repeatOneProvider).valueOrNull ?? false;
    final skips = queueSkips(
      queue: queue,
      position: position,
      onRestart: () => unawaited(service.skipToPrevious()),
      onPrevious: () => unawaited(service.skipToPrevious()),
      onNext: () => unawaited(service.skipToNext()),
    );

    return TransportBinding(
      isPlaying: isPlaying,
      isBuffering:
          processingState == ProcessingState.loading ||
          processingState == ProcessingState.buffering,
      speed: ref.watch(playbackSpeedProvider).valueOrNull ?? 1.0,
      repeatOn: repeatOn,
      onPlay: () => unawaited(service.resume()),
      onPause: () => unawaited(service.pause()),
      onSetSpeed: (speed) => unawaited(service.setSpeed(speed)),
      onToggleRepeat: () => unawaited(service.setRepeatOne(!repeatOn)),
      onPrevious: skips.previous,
      onNext: skips.next,
    );
  }
}

/// Previous / Next callbacks for [queue] at [position], or null where the
/// control is disabled. Both engines use this so audio and video follow the
/// same rules ([PlaybackQueue.previousAction]).
({VoidCallback? previous, VoidCallback? next}) queueSkips({
  required PlaybackQueue? queue,
  required Duration position,
  required VoidCallback onRestart,
  required VoidCallback onPrevious,
  required VoidCallback onNext,
}) {
  if (queue == null) return (previous: null, next: null);
  final VoidCallback? previous = switch (queue.previousAction(position)) {
    PreviousAction.restart => onRestart,
    PreviousAction.previousItem => onPrevious,
    PreviousAction.none => null,
  };
  return (previous: previous, next: queue.hasNext ? onNext : null);
}

// ── Speed pill ────────────────────────────────────────────────────────────────

class _SpeedPill extends StatelessWidget {
  const _SpeedPill({required this.speed, required this.onTap});

  final double speed;
  final VoidCallback onTap;

  String get _label {
    final s = speed == speed.roundToDouble()
        ? speed.toStringAsFixed(0)
        : speed.toString();
    return '$s×';
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Playback speed $_label',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(
              color: context.kc.accentInk.withValues(alpha: 0.5),
              width: 1.5,
            ),
          ),
          child: Text(
            _label,
            style: AppTypography.ui(
              size: 12.5,
              weight: FontWeight.w700,
              color: context.kc.accentInk,
            ),
          ),
        ),
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
    return Semantics(
      button: true,
      label: isPlaying ? 'Pause' : 'Play',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: context.kc.accent,
            boxShadow: [
              BoxShadow(
                color: context.kc.accent.withValues(alpha: 0.5),
                blurRadius: 22,
                offset: const Offset(0, 12),
                spreadRadius: -6,
              ),
            ],
          ),
          alignment: Alignment.center,
          child: isBuffering
              ? SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      context.kc.onAccent,
                    ),
                  ),
                )
              : Icon(
                  isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: context.kc.onAccent,
                  size: 34,
                ),
        ),
      ),
    );
  }
}

// ── Previous / Next message button ────────────────────────────────────────────

class _SkipButton extends StatelessWidget {
  const _SkipButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    // Tonal circle so the controls read as buttons instead of floating
    // glyphs, with a ripple and a generous tap target.
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: context.kc.chipBg.withValues(alpha: enabled ? 1 : 0.5),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(
            width: 54,
            height: 54,
            child: Icon(
              icon,
              color: enabled
                  ? context.kc.onBg
                  : context.kc.onBg.withValues(alpha: 0.3),
              size: 30,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Repeat toggle ─────────────────────────────────────────────────────────────

class _RepeatButton extends StatelessWidget {
  const _RepeatButton({required this.active, required this.onTap});

  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      toggled: active,
      label: 'Repeat this message',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(
                Icons.repeat_one_rounded,
                color: active ? context.kc.accentInk : context.kc.muted,
                size: 22,
              ),
              if (active)
                Positioned(
                  bottom: 4,
                  child: Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: context.kc.accentInk,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
