import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kharis_app/core/utils/share_sermon.dart';
import 'package:kharis_app/features/notes/presentation/widgets/sermon_notes_sheet.dart';
import 'package:kharis_app/features/player/presentation/widgets/transcript_sheet.dart';
import 'package:kharis_app/features/playlists/presentation/widgets/add_to_playlist_sheet.dart';
import 'package:kharis_app/shared/models/sermon.dart';
import 'package:kharis_app/shared/providers/audio_provider.dart';
import 'package:kharis_app/ui/components/components.dart';

/// Row of secondary player actions shown below the transport controls:
/// Notes · Playlist · Transcript · Share, each a chip with its icon and
/// label. The row scrolls sideways when the chips do not fit.
///
/// Notes opens [SermonNotesSheet] for the message on screen — its notepad,
/// free typing with an Insert action that stamps the live playback position
/// as a tappable `[m:ss]`. Playlist opens
/// [AddToPlaylistSheet], filing the message into the member's persisted
/// playlists. Transcript opens [TranscriptSheet] and only shows up when the
/// message actually has one (a handful genuinely have none). Share opens the
/// OS share sheet with the right link for the medium on screen (see
/// [sermonShareLink]).
class PlayerActions extends ConsumerWidget {
  const PlayerActions({
    super.key,
    this.sermon,
    this.timeline,
    this.asVideo = false,
    this.positionOf,
  });

  /// The message on screen. Falls back to whatever the audio service is
  /// playing.
  final Sermon? sermon;

  /// The engine that owns playback on the hosting screen, handed through to
  /// [SermonNotesSheet] and [TranscriptSheet] so note capture, transcript
  /// follow-along and seeks drive the ACTIVE engine. Null means the audio
  /// service (the sheets' default).
  final NoteTimelineBinding? timeline;

  /// Whether the message is being watched, so Share hands out the video link.
  final bool asVideo;

  /// The active engine's position, read when Share is tapped so a video link
  /// starts where the member is.
  final Duration Function()? positionOf;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final target = sermon ?? ref.watch(currentSermonProvider);
    if (target == null) return const SizedBox.shrink();

    return KChipRow(
      children: [
        KChip(
          key: const Key('player-action-notes'),
          label: 'Notes',
          leading: KIcons.note,
          onTap: () =>
              SermonNotesSheet.show(context, target, timeline: timeline),
        ),
        KChip(
          key: const Key('player-action-playlist'),
          label: 'Playlist',
          leading: KIcons.plus,
          onTap: () => showAddToPlaylistSheet(
            context,
            sermonId: target.id,
            sermonTitle: target.title,
          ),
        ),
        if (target.hasTranscript)
          KChip(
            key: const Key('player-action-transcript'),
            label: 'Transcript',
            leading: KIcons.scroll,
            onTap: () =>
                TranscriptSheet.show(context, target, timeline: timeline),
          ),
        KChip(
          key: const Key('player-action-share'),
          label: 'Share',
          leading: KIcons.share,
          onTap: () => unawaited(
            shareSermon(target, asVideo: asVideo, position: positionOf?.call()),
          ),
        ),
      ],
    );
  }
}
