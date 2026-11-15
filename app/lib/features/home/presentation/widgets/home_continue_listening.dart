import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:kharis_app/features/player/presentation/playback_launcher.dart';
import 'package:kharis_app/shared/providers/listening_history_provider.dart';
import 'package:kharis_app/ui/components/components.dart';

/// "34:10", "1:02:05".
String _clock(Duration d) {
  final minutes = d.inMinutes % 60;
  final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
  if (d.inHours == 0) return '$minutes:$seconds';
  return '${d.inHours}:${minutes.toString().padLeft(2, '0')}:$seconds';
}

/// "Continue listening": up to three messages the member has started, the
/// newest first, each resuming where it stopped; History lists them all.
/// Renders nothing when none is unfinished.
class HomeContinueListening extends ConsumerWidget {
  const HomeContinueListening({super.key, this.padding = EdgeInsets.zero});

  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plays = ref.watch(continueListeningListProvider);
    if (plays.isEmpty) return const SizedBox.shrink();

    return Padding(
      key: const Key('home-continue-listening'),
      padding: padding,
      child: KContinueListening(
        onHistory: () => context.push('/history'),
        items: [
          for (final play in plays)
            () {
              final sermon = play.sermon;
              final speaker = sermon.speaker.trim();
              final duration = play.duration;
              final where = duration == null || duration <= Duration.zero
                  ? _clock(play.position)
                  : '${_clock(play.position)} of ${_clock(duration)}';
              final artwork = sermon.artworkUrl?.trim();
              void resume() =>
                  unawaited(startPlayback(context, ref, sermon));
              return KContinueItem(
                title: sermon.title,
                meta: speaker.isEmpty ? where : '$speaker \u00b7 $where',
                progress: play.progress ?? 0,
                artwork: artwork == null || artwork.isEmpty
                    ? null
                    : CachedNetworkImageProvider(artwork),
                onTap: resume,
                onPlay: resume,
              );
            }(),
        ],
      ),
    );
  }
}
