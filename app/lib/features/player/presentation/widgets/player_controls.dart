import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/shared/providers/audio_provider.dart';

/// A snapshot of whichever engine currently owns playback, so [PlayerControls]
/// can drive audio (just_audio) and video (YouTube) with one control row.
///
/// Null on [PlayerControls.transport] means the audio service, read reactively
/// from the Riverpod providers as before. A video host supplies a binding
/// rebuilt from its own streams instead.
@immutable
class TransportBinding {
  const TransportBinding({
    required this.isPlaying,
    required this.isBuffering,
    required this.position,
    required this.duration,
    required this.onPlay,
    required this.onPause,
    required this.onSeek,
    required this.onSetSpeed,
  });

  final bool isPlaying;
  final bool isBuffering;
  final Duration position;
  final Duration duration;
  final VoidCallback onPlay;
  final VoidCallback onPause;
  final ValueChanged<Duration> onSeek;
  final ValueChanged<double> onSetSpeed;
}

/// Transport controls.
///
/// Row layout: speed pill | skip-back 15 | play/pause | skip-forward 30 |
/// repeat. The play/pause button is a 70-px gold circle with a dark icon and a
/// soft gold glow; a spinner replaces the icon while buffering. Tapping the
/// speed pill cycles 1× → 1.25× → 1.5× → 2× → 0.75× and applies the rate to the
/// active engine. Repeat is a local visual toggle only.
class PlayerControls extends ConsumerStatefulWidget {
  const PlayerControls({super.key, this.transport});

  /// The engine these controls operate. Null drives the audio service.
  final TransportBinding? transport;

  @override
  ConsumerState<PlayerControls> createState() => _PlayerControlsState();
}

class _PlayerControlsState extends ConsumerState<PlayerControls> {
  static const List<double> _speeds = [1, 1.25, 1.5, 2, 0.75];

  int _speedIndex = 0;
  bool _repeatOn = false;

  double get _speed => _speeds[_speedIndex];

  void _cycleSpeed() {
    setState(() => _speedIndex = (_speedIndex + 1) % _speeds.length);
    final transport = widget.transport;
    if (transport != null) {
      transport.onSetSpeed(_speed);
    } else {
      ref.read(audioPlayerServiceProvider).setSpeed(_speed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final transport = widget.transport;

    final bool isPlaying;
    final bool isBuffering;
    final Duration position;
    final Duration duration;
    final VoidCallback onPlay;
    final VoidCallback onPause;
    final ValueChanged<Duration> onSeek;

    if (transport != null) {
      isPlaying = transport.isPlaying;
      isBuffering = transport.isBuffering;
      position = transport.position;
      duration = transport.duration;
      onPlay = transport.onPlay;
      onPause = transport.onPause;
      onSeek = transport.onSeek;
    } else {
      final playerState = ref.watch(playerStateProvider).valueOrNull;
      isPlaying = playerState?.playing ?? false;
      final processingState = playerState?.processingState;
      isBuffering = processingState == ProcessingState.loading ||
          processingState == ProcessingState.buffering;
      position = ref.watch(positionProvider).valueOrNull ?? Duration.zero;
      duration = ref.watch(durationProvider).valueOrNull ?? Duration.zero;
      final service = ref.read(audioPlayerServiceProvider);
      onPlay = service.resume;
      onPause = service.pause;
      onSeek = service.seek;
    }

    void seekRelative(int seconds) {
      final newPos = position + Duration(seconds: seconds);
      final clamped = Duration(
        milliseconds: newPos.inMilliseconds.clamp(0, duration.inMilliseconds),
      );
      onSeek(clamped);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Speed pill.
          _SpeedPill(speed: _speed, onTap: _cycleSpeed),

          // Skip back 15 seconds.
          _SkipButton(
            seconds: 15,
            isForward: false,
            onPressed: () => seekRelative(-15),
          ),

          // Play / Pause.
          _PlayPauseButton(
            isPlaying: isPlaying,
            isBuffering: isBuffering,
            onTap: () => isPlaying ? onPause() : onPlay(),
          ),

          // Skip forward 30 seconds.
          _SkipButton(
            seconds: 30,
            isForward: true,
            onPressed: () => seekRelative(30),
          ),

          // Repeat toggle (visual only).
          _RepeatButton(
            active: _repeatOn,
            onTap: () => setState(() => _repeatOn = !_repeatOn),
          ),
        ],
      ),
    );
  }
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
    return GestureDetector(
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
                  valueColor:
                      AlwaysStoppedAnimation<Color>(context.kc.onAccent),
                ),
              )
            : Icon(
                isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: context.kc.onAccent,
                size: 34,
              ),
      ),
    );
  }
}

// ── Skip +/- seconds button ─────────────────────────────────────────────────

class _SkipButton extends StatelessWidget {
  const _SkipButton({
    required this.seconds,
    required this.isForward,
    required this.onPressed,
  });

  final int seconds;
  final bool isForward;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    // Tonal circle so the seek controls read as buttons instead of floating
    // glyphs, with a ripple and a bigger tap target (tester feedback).
    return Material(
      color: context.kc.chipBg,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: SizedBox(
          width: 54,
          height: 54,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(
                isForward ? Icons.forward_rounded : Icons.replay_rounded,
                color: context.kc.onBg,
                size: 28,
              ),
              Positioned(
                bottom: 12,
                child: Text(
                  '$seconds',
                  style: AppTypography.ui(
                    size: 8,
                    weight: FontWeight.w800,
                    color: context.kc.onBg,
                  ).copyWith(height: 1),
                ),
              ),
            ],
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
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 40,
        height: 40,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(
              Icons.repeat_rounded,
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
    );
  }
}
