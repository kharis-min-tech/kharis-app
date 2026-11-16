import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';

import 'package:kharis_app/shared/providers/audio_provider.dart';
import 'package:kharis_app/ui/components/components.dart';

/// The mini player shown above the floating nav while a message is loaded:
/// artwork, title, speaker, progress, play or pause, and close.
///
/// Tapping the card pushes `/player`; play or pause and close act in place.
/// Close (or a swipe down) stops playback. Draws nothing when
/// [currentSermonProvider] is null.
class MiniPlayer extends ConsumerStatefulWidget {
  const MiniPlayer({super.key});

  @override
  ConsumerState<MiniPlayer> createState() => _MiniPlayerState();
}

class _MiniPlayerState extends ConsumerState<MiniPlayer> {
  /// Sermon whose card the member just closed. `stop()` clears
  /// [currentSermonProvider] through the engine's stream, a frame or more
  /// later on a real device, and a dismissed [Dismissible] that is still in
  /// the tree for that frame asserts ("A dismissed Dismissible widget is still
  /// part of the tree", seen on iPhone during the KA-001 walkthrough). Hiding
  /// synchronously here closes that gap; the flag resets once the sermon is
  /// gone so the same message can come back later.
  String? _dismissedSermonId;

  @override
  Widget build(BuildContext context) {
    final sermon = ref.watch(currentSermonProvider);
    if (sermon == null) {
      _dismissedSermonId = null;
      return const SizedBox.shrink();
    }
    if (sermon.id == _dismissedSermonId) return const SizedBox.shrink();

    final playerState = ref.watch(playerStateProvider).valueOrNull;
    final processing = playerState?.processingState;
    // A finished message offers Play (which restarts it), not Pause; so does
    // an idle engine (a fatal Android error idles ExoPlayer while the flag
    // stays set), whose Play reloads it. Same rule as PlayerControls.
    final isPlaying =
        (playerState?.playing ?? false) &&
        processing != ProcessingState.completed &&
        processing != ProcessingState.idle;
    final isBuffering =
        processing == ProcessingState.loading ||
        processing == ProcessingState.buffering;
    final position = ref.watch(positionProvider).valueOrNull ?? Duration.zero;
    final rawDuration =
        ref.watch(durationProvider).valueOrNull ?? Duration.zero;
    final service = ref.read(audioPlayerServiceProvider);

    // A failed load keeps the sermon loaded here, so the card doubles as the
    // error state: it says what happened and retries in place.
    final failure = ref.watch(playbackFailureProvider).valueOrNull;
    final failed = failure != null && failure.sermonId == sermon.id;

    final progress = rawDuration.inMilliseconds > 0
        ? (position.inMilliseconds / rawDuration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    void close() {
      setState(() => _dismissedSermonId = sermon.id);
      unawaited(service.stop());
    }

    final String? subtitle;
    if (failed) {
      subtitle = sermon.hasAudio
          ? 'Couldn\u2019t play \u00b7 tap to retry'
          : 'Video only \u00b7 no audio recording';
    } else {
      subtitle = sermon.speaker.isEmpty ? null : sermon.speaker;
    }

    final artworkUrl = sermon.artworkUrl;
    // Decoded at the thumbnail's size, never the full-resolution artwork.
    final artworkWidth = (KSize.thumb * MediaQuery.devicePixelRatioOf(context))
        .round();

    return Dismissible(
      key: ValueKey('mini-player-${sermon.id}'),
      direction: DismissDirection.down,
      // A short fling should be enough; this is a small card, not a list row.
      dismissThresholds: const {DismissDirection.down: 0.35},
      onDismissed: (_) => close(),
      child: KMiniPlayer(
        title: sermon.title,
        subtitle: subtitle,
        artwork: artworkUrl == null || artworkUrl.isEmpty
            ? null
            : ResizeImage(
                CachedNetworkImageProvider(artworkUrl),
                width: artworkWidth,
              ),
        progress: progress,
        playing: isPlaying && !failed,
        playLabel: failed
            ? 'Retry'
            : isBuffering
            ? 'Loading'
            : 'Play',
        pauseLabel: isBuffering ? 'Loading' : 'Pause',
        onPlayPause: failed
            ? (sermon.hasAudio ? service.retry : null)
            : (isPlaying ? service.pause : service.resume),
        onClose: close,
        onTap: () => context.push('/player'),
      ),
    );
  }
}
