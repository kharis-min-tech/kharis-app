import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kharis_app/core/theme/app_colors.dart';
import 'package:kharis_app/core/theme/app_spacing.dart';
import 'package:kharis_app/core/theme/app_typography.dart';
import 'package:kharis_app/features/notes/presentation/screens/note_editor_screen.dart';
import 'package:kharis_app/shared/providers/audio_provider.dart';
import 'package:kharis_app/shared/providers/notes_provider.dart';

/// Row of secondary player actions shown below the playback controls.
/// Currently exposes the Notes action; extend with additional buttons as needed.
class PlayerActions extends ConsumerWidget {
  const PlayerActions({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _ActionButton(
          icon: Icons.edit_note_outlined,
          label: 'Notes',
          onTap: () => _openNoteEditor(context, ref),
        ),
      ],
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.onSurfaceVariant, size: 26),
          const SizedBox(height: AppSpacing.xs),
          Text(
            label,
            style: AppTypography.labelMd.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppColors.onSurfaceVariant,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}
