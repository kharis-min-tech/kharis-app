import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/core/utils/media_url.dart';
import 'package:kharis_app/features/home/presentation/widgets/continue_listening_card.dart';
import 'package:kharis_app/features/notes/data/note_timeline_key.dart';
import 'package:kharis_app/features/player/data/playback_history.dart';
import 'package:kharis_app/features/player/presentation/playback_launcher.dart';
import 'package:kharis_app/shared/models/sermon.dart';
import 'package:kharis_app/shared/providers/audio_provider.dart';
import 'package:kharis_app/shared/providers/sermon_provider.dart';
import 'package:kharis_app/shared/widgets/press_effect.dart';

const double _kArtSize = 156;

/// Extra height the continue card's progress bar adds under its artwork
/// (bar plus the gap below it, less the plain tiles' gap).
const double _kProgressBlock = 8;

/// Home's row of the newest messages ([homeLatestSermonsProvider]): large
/// square artwork, the title, the speaker and the date beneath, each
/// starting playback on tap. When a message is part-way through
/// ([continueListeningProvider]) it leads the row with how far the member
/// got and is not repeated; the [kHomeLatestMessagesCount] newest of the
/// rest follow. Renders nothing until there is something to show.
class LatestMessagesRow extends ConsumerWidget {
  const LatestMessagesRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unfinished = ref.watch(continueListeningProvider);
    final resumeKey = unfinished == null
        ? null
        : NoteTimelineKey.of(unfinished.sermon).canonical;
    final sermons = ref
        .watch(homeLatestSermonsProvider)
        .where(
          (s) =>
              unfinished == null ||
              (s.id != unfinished.sermon.id &&
                  NoteTimelineKey.of(s).canonical != resumeKey),
        )
        .take(kHomeLatestMessagesCount)
        .toList();
    if (unfinished == null && sermons.isEmpty) return const SizedBox.shrink();
    final leading = unfinished == null ? 0 : 1;
    return SizedBox(
      key: const Key('home-latest-messages'),
      // Artwork plus two title lines, the speaker and the date, at the
      // member's text size, plus the continue card's progress bar when it
      // leads.
      height:
          _kArtSize +
          MediaQuery.textScalerOf(context).scale(84) +
          (unfinished == null ? 0 : _kProgressBlock),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: leading + sermons.length,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
        itemBuilder: (context, i) => unfinished != null && i == 0
            ? _ContinueTile(unfinished: unfinished)
            : _MessageTile(sermon: sermons[i - leading]),
      ),
    );
  }
}

/// Artwork with a rounded clip, or the headphones mark when the message has
/// none (or it fails to load).
class _Artwork extends StatelessWidget {
  const _Artwork({required this.sermon});

  final Sermon sermon;

  @override
  Widget build(BuildContext context) {
    final kc = context.kc;
    final url = usableMediaUrl(sermon.artworkUrl);
    final fallback = ColoredBox(
      color: kc.chipBg,
      child: Center(
        child: Icon(Icons.headphones_rounded, size: 36, color: kc.onChip),
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox.square(
        dimension: _kArtSize,
        child: url == null
            ? fallback
            : CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                placeholder: (_, _) => ColoredBox(color: kc.chipBg),
                errorWidget: (_, _, _) => fallback,
              ),
      ),
    );
  }
}

/// The message the member left part-way: its artwork, a thin progress bar,
/// the title and the time left. One tap picks it up where they left off.
class _ContinueTile extends ConsumerWidget {
  const _ContinueTile({required this.unfinished});

  final UnfinishedPlay unfinished;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kc = context.kc;
    final sermon = unfinished.sermon;

    // While this message is the one loaded, follow the live engine.
    final isCurrent = ref.watch(currentSermonProvider)?.id == sermon.id;
    final livePosition = isCurrent
        ? ref.watch(positionProvider).valueOrNull
        : null;
    final liveDuration = isCurrent
        ? ref.watch(durationProvider).valueOrNull
        : null;
    final position = livePosition != null && livePosition > Duration.zero
        ? livePosition
        : unfinished.position;
    final duration = liveDuration ?? unfinished.duration;
    final total = duration?.inMilliseconds ?? 0;
    final progress = total > 0
        ? (position.inMilliseconds / total).clamp(0.0, 1.0)
        : null;
    final caption = total > 0
        ? remainingLabel(duration! - position)
        : 'Paused at ${_clock(position)}';

    return Semantics(
      button: true,
      label: 'Continue listening: ${sermon.title}, $caption',
      excludeSemantics: true,
      child: PressEffect(
        key: const Key('home-continue-card'),
        onTap: () => unawaited(startPlayback(context, ref, sermon)),
        child: SizedBox(
          width: _kArtSize,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Artwork(sermon: sermon),
              if (progress != null) ...[
                const SizedBox(height: 8),
                SizedBox(
                  key: const Key('home-continue-progress'),
                  height: 3,
                  child: ColoredBox(
                    color: kc.surfaceMuted,
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: FractionallySizedBox(
                        widthFactor: progress,
                        heightFactor: 1,
                        child: ColoredBox(color: kc.accent),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 7),
              ] else
                const SizedBox(height: 10),
              Text(
                sermon.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.ui(
                  size: 14,
                  weight: FontWeight.w700,
                ).copyWith(color: kc.onBg, height: 1.25),
              ),
              const SizedBox(height: 3),
              Text(
                caption,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.ui(
                  size: 12,
                  weight: FontWeight.w600,
                ).copyWith(color: kc.accentInk, height: 1.2),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _clock(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(h > 0 ? 2 : 1, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }
}

class _MessageTile extends ConsumerWidget {
  const _MessageTile({required this.sermon});

  final Sermon sermon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kc = context.kc;
    final published = sermon.publishedAt;
    final date = published == null
        ? null
        : DateFormat('d MMM').format(published);
    return Semantics(
      button: true,
      label:
          '${sermon.title}, ${sermon.speaker}'
          '${date == null ? '' : ', $date'}. Play',
      excludeSemantics: true,
      child: GestureDetector(
        key: Key('home-message-${sermon.id}'),
        behavior: HitTestBehavior.opaque,
        onTap: () => startPlayback(context, ref, sermon),
        child: SizedBox(
          width: _kArtSize,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Artwork(sermon: sermon),
              const SizedBox(height: 10),
              Text(
                sermon.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.ui(
                  size: 14,
                  weight: FontWeight.w700,
                ).copyWith(color: kc.onBg, height: 1.25),
              ),
              const SizedBox(height: 3),
              Text(
                sermon.speaker,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.ui(
                  size: 12,
                ).copyWith(color: kc.muted, height: 1.2),
              ),
              if (date != null) ...[
                const SizedBox(height: 2),
                Text(
                  date,
                  key: Key('home-message-date-${sermon.id}'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.ui(
                    size: 12,
                  ).copyWith(color: kc.muted, height: 1.2),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
