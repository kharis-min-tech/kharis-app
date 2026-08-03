import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/features/notes/presentation/screens/note_editor_screen.dart';
import 'package:kharis_app/shared/providers/audio_provider.dart';
import 'package:kharis_app/shared/providers/notes_provider.dart';

/// Row of secondary player actions shown below the transport controls:
/// Notes · Playlist · Share, each an icon over a small muted label. Notes opens
/// the note editor for the current sermon at the current playback position;
/// Playlist and Share confirm with a lightweight toast.
class PlayerActions extends ConsumerWidget {
  const PlayerActions({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _ActionButton(
          icon: Icons.notes_rounded,
          label: 'Notes',
          onTap: () => _openNoteEditor(context, ref),
        ),
        _ActionButton(
          icon: Icons.add_rounded,
          label: 'Playlist',
          onTap: () => _toast(context, 'Added to playlist'),
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

  void _openNoteEditor(BuildContext context, WidgetRef ref) {
    final sermon = ref.read(currentSermonProvider);
    final position = ref.read(positionProvider).valueOrNull ?? Duration.zero;

    Navigator.of(context)
        .push<void>(
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (_) => NoteEditorScreen(
              sermon: sermon,
              positionMs: position.inMilliseconds,
            ),
          ),
        )
        .then((_) {
      // Bump revision so any open NotesScreen list stays fresh.
      ref.read(notesRevisionProvider.notifier).state++;
    });
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
