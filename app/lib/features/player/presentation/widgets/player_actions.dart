import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/core/utils/share_sermon.dart';
import 'package:kharis_app/features/notes/presentation/widgets/sermon_notes_sheet.dart';
import 'package:kharis_app/features/player/presentation/widgets/transcript_sheet.dart';
import 'package:kharis_app/features/playlists/presentation/widgets/add_to_playlist_sheet.dart';
import 'package:kharis_app/shared/models/sermon.dart';
import 'package:kharis_app/shared/providers/audio_provider.dart';

/// Row of secondary player actions shown below the transport controls:
/// Notes · Playlist · Transcript · Share, each an icon over a small muted
/// label.
///
/// Notes opens [SermonNotesSheet] for the message on screen — everything
/// already written against it, in timeline order, plus a "add a note at
/// MM:SS" action stamped with the live playback position. Playlist opens
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
  /// [SermonNotesSheet] so note capture and anchor seeks drive the ACTIVE
  /// engine. Null means the audio service (the sheet's default).
  final NoteTimelineBinding? timeline;

  /// Whether the message is being watched, so Share hands out the video link.
  final bool asVideo;

  /// The active engine's position, read when Share is tapped so a video link
  /// starts where the member is.
  final Duration Function()? positionOf;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final target = sermon ?? ref.watch(currentSermonProvider);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        if (target != null)
          _ActionButton(
            icon: Icons.notes_rounded,
            label: 'Notes',
            onTap: () =>
                SermonNotesSheet.show(context, target, timeline: timeline),
          ),
        if (target != null)
          _ActionButton(
            icon: Icons.add_rounded,
            label: 'Playlist',
            onTap: () => showAddToPlaylistSheet(
              context,
              sermonId: target.id,
              sermonTitle: target.title,
            ),
          ),
        if (target != null && target.hasTranscript)
          _ActionButton(
            icon: Icons.article_outlined,
            label: 'Transcript',
            onTap: () => TranscriptSheet.show(context, target),
          ),
        if (target != null)
          _ActionButton(
            icon: Icons.ios_share_rounded,
            label: 'Share',
            onTap: () => unawaited(
              shareSermon(
                target,
                asVideo: asVideo,
                position: positionOf?.call(),
              ),
            ),
          ),
      ],
    );
  }
}

// ── Private icon + label button ───────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        // Icon + label is ~40 px; the box makes the target 56 x 48.
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 56, minHeight: 48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: context.kc.muted, size: 22),
              const SizedBox(height: AppSpacing.xs),
              Text(
                label,
                style: AppTypography.ui(
                  size: 10,
                  weight: FontWeight.w600,
                  color: context.kc.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
