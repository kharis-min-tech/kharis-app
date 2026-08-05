import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/features/notes/presentation/widgets/sermon_notes_sheet.dart';
import 'package:kharis_app/features/playlists/presentation/widgets/add_to_playlist_sheet.dart';
import 'package:kharis_app/shared/models/sermon.dart';
import 'package:kharis_app/shared/providers/audio_provider.dart';

/// Row of secondary player actions shown below the transport controls:
/// Notes · Playlist · Share, each an icon over a small muted label.
///
/// Notes opens [SermonNotesSheet] for the message on screen — everything
/// already written against it, in timeline order, plus a "add a note at
/// MM:SS" action stamped with the live playback position. Playlist opens
/// [AddToPlaylistSheet], filing the message into the member's persisted
/// playlists. Both are only rendered when a message is actually resolvable;
/// Share confirms with a lightweight toast.
class PlayerActions extends ConsumerWidget {
  const PlayerActions({super.key, this.sermon, this.timeline});

  /// The message on screen. Supplied by the video player, whose sermon is not
  /// the one loaded into the audio service. Falls back to whatever the audio
  /// service is playing.
  final Sermon? sermon;

  /// The engine that owns playback on the hosting screen, handed through to
  /// [SermonNotesSheet] so note capture and anchor seeks drive the ACTIVE
  /// engine. Null means the audio service (the sheet's default).
  final NoteTimelineBinding? timeline;

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
        _ActionButton(
          icon: Icons.ios_share_rounded,
          label: 'Share',
          onTap: () => _toast(context, 'Share link copied'),
        ),
      ],
    );
  }

  void _toast(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 1700),
      ),
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
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
    );
  }
}
