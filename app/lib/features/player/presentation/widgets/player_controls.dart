import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kharis_app/shared/providers/audio_provider.dart';

class PlayerControls extends ConsumerWidget {
  const PlayerControls({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(playerStateProvider).valueOrNull;
    final isPlaying = playerState?.playing ?? false;
    final position = ref.watch(positionProvider).valueOrNull ?? Duration.zero;
    final duration = ref.watch(durationProvider).valueOrNull ?? Duration.zero;
    final service = ref.read(audioPlayerServiceProvider);

    void seekRelative(int seconds) {
      final newPos = position + Duration(seconds: seconds);
      final clamped = Duration(
        milliseconds: newPos.inMilliseconds.clamp(0, duration.inMilliseconds),
      );
      service.seek(clamped);
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Skip previous — seeks to start of current track
        IconButton(
          onPressed: () => service.seek(Duration.zero),
          icon: const Icon(Icons.skip_previous_rounded),
          color: Colors.white,
          iconSize: 24,
          padding: EdgeInsets.zero,
        ),
        // Replay 15s
        _Replay15Button(onPressed: () => seekRelative(-15)),
        // Play / Pause
        GestureDetector(
          onTap: () => isPlaying ? service.pause() : service.resume(),
          child: Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
            child: Icon(
              isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: Colors.black,
              size: 28,
            ),
          ),
        ),
        // Forward 15s
        _Forward15Button(onPressed: () => seekRelative(15)),
        // Skip next — no playlist yet; disabled
        IconButton(
          onPressed: null,
          icon: const Icon(Icons.skip_next_rounded),
          color: Colors.white.withValues(alpha: 0.4),
          iconSize: 24,
          padding: EdgeInsets.zero,
        ),
      ],
    );
  }
}

// ── Replay 15 ──────────────────────────────────────────────────────────────────

class _Replay15Button extends StatelessWidget {
  const _Replay15Button({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: SizedBox(
        width: 40,
        height: 40,
        child: Stack(
          alignment: Alignment.center,
          children: [
            const Icon(Icons.replay_rounded, color: Colors.white, size: 28),
            Positioned(
              bottom: 6,
              child: Text(
                '15',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  height: 1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Forward 15 ─────────────────────────────────────────────────────────────────

class _Forward15Button extends StatelessWidget {
  const _Forward15Button({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: SizedBox(
        width: 40,
        height: 40,
        child: Stack(
          alignment: Alignment.center,
          children: [
            const Icon(Icons.forward_rounded, color: Colors.white, size: 28),
            Positioned(
              bottom: 6,
              child: Text(
                '15',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  height: 1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
