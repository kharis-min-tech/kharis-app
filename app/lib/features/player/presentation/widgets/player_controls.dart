import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import 'package:kharis_app/features/player/data/playback_queue.dart';
import 'package:kharis_app/features/player/data/time_skip.dart';
import 'package:kharis_app/shared/providers/audio_provider.dart';
import 'package:kharis_app/ui/components/components.dart';

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
    this.onSeekBy,
  });

  final bool isPlaying;
  final bool isBuffering;
  final double speed;
  final bool repeatOn;

  /// Null disables Play / Pause (the engine cannot act on it yet).
  final VoidCallback? onPlay;
  final VoidCallback? onPause;
  final ValueChanged<double> onSetSpeed;
  final VoidCallback onToggleRepeat;

  /// Null disables the control (first message, already at its start).
  final VoidCallback? onPrevious;

  /// Null disables the control (last message in the queue).
  final VoidCallback? onNext;

  /// Moves playback by a signed offset (back 15 s / forward 30 s), clamped
  /// to the message. Null disables both skip buttons.
  final ValueChanged<Duration>? onSeekBy;
}

/// Transport controls.
///
/// Main row: previous | back 15 s | play/pause | forward 30 s | next, the
/// podcast-app arrangement with the time skips next to Play. Below it: the
/// speed chip on the left and repeat on the right.
/// Previous and Next walk the queue the member launched from, Spotify-style:
/// Previous restarts the message once it is past three seconds, otherwise
/// steps back; both disable at the ends of the queue. Play/pause is the round
/// primary button, with a dimmed disabled state and a spinner while
/// buffering. The icon set has no skip glyphs: Previous and Next are the
/// double chevron (mirrored for Next) and the time skips show "−15" and
/// "+30" as text. The speed chip cycles 1× → 1.25× → 1.5× → 2× → 0.75× and
/// persists; Repeat loops the current message.
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

  static String _speedLabel(double speed) {
    final s = speed == speed.roundToDouble()
        ? speed.toStringAsFixed(0)
        : speed.toString();
    return '$s×';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final binding = transport ?? _audioBinding(ref);

    final seekBy = binding.onSeekBy;
    final speed = _speedLabel(binding.speed);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            KIconButton(
              key: const Key('player-previous'),
              icon: KIcons.rewind,
              label: 'Previous message',
              variant: KIconButtonVariant.filled,
              onPressed: binding.onPrevious,
            ),
            KTransportTextButton(
              key: const Key('skip-back'),
              text: '\u221215',
              label: 'Back ${TimeSkip.back.inSeconds} seconds',
              onPressed: seekBy == null ? null : () => seekBy(-TimeSkip.back),
            ),
            KPlayButton(
              key: const ValueKey('player-play-pause'),
              playing: binding.isPlaying,
              loading: binding.isBuffering,
              onPressed: binding.isPlaying ? binding.onPause : binding.onPlay,
            ),
            KTransportTextButton(
              key: const Key('skip-forward'),
              text: '+30',
              label: 'Forward ${TimeSkip.forward.inSeconds} seconds',
              onPressed: seekBy == null ? null : () => seekBy(TimeSkip.forward),
            ),
            // The double chevron, mirrored to point forward.
            Transform.flip(
              flipX: true,
              child: KIconButton(
                key: const Key('player-next'),
                icon: KIcons.rewind,
                label: 'Next message',
                variant: KIconButtonVariant.filled,
                onPressed: binding.onNext,
              ),
            ),
          ],
        ),
        const SizedBox(height: KSpace.md),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Semantics(
              button: true,
              label: 'Playback speed $speed',
              onTap: () => binding.onSetSpeed(nextSpeed(binding.speed)),
              excludeSemantics: true,
              child: KChip(
                key: const Key('player-speed'),
                label: speed,
                onTap: () => binding.onSetSpeed(nextSpeed(binding.speed)),
              ),
            ),
            Semantics(
              button: true,
              toggled: binding.repeatOn,
              label: 'Repeat this message',
              onTap: binding.onToggleRepeat,
              excludeSemantics: true,
              child: KIconButton(
                key: const Key('player-repeat'),
                icon: KIcons.repeat,
                label: 'Repeat this message',
                variant: binding.repeatOn
                    ? KIconButtonVariant.filled
                    : KIconButtonVariant.plain,
                color: binding.repeatOn ? context.k.primaryText : null,
                onPressed: binding.onToggleRepeat,
              ),
            ),
          ],
        ),
      ],
    );
  }

  TransportBinding _audioBinding(WidgetRef ref) {
    final service = ref.read(audioPlayerServiceProvider);
    final playerState = ref.watch(playerStateProvider).valueOrNull;
    final processingState = playerState?.processingState;
    // A finished message is not "playing", whatever the engine's flag says:
    // the button must offer Play, and Play restarts it. Neither is an idle
    // engine: a fatal Android error idles ExoPlayer while the flag stays
    // set, and Pause over a stopped player does nothing.
    final isPlaying =
        (playerState?.playing ?? false) &&
        processingState != ProcessingState.completed &&
        processingState != ProcessingState.idle;
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
      onSeekBy: (offset) => unawaited(service.seekBy(offset)),
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
