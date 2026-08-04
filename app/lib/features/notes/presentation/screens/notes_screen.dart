import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/features/notes/data/note_repository.dart';
import 'package:kharis_app/features/notes/presentation/note_anchor.dart';
import 'package:kharis_app/features/notes/presentation/widgets/note_anchor_chip.dart';
import 'package:kharis_app/shared/providers/notes_provider.dart';

import 'note_editor_screen.dart';

/// The member's whole notebook, newest edit first — the "go to their notes and
/// read as they go through" view. Notes anchored to a message carry a chip that
/// jumps playback back to the moment they were written.
class NotesScreen extends ConsumerWidget {
  const NotesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notesAsync = ref.watch(notesProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: context.kc.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Notes',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: context.kc.onBg,
          ),
        ),
      ),
      body: notesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => _buildMessage(
          context,
          Icons.cloud_off_outlined,
          "Your notes couldn't be loaded",
        ),
        data: (notes) => notes.isEmpty
            ? _buildMessage(
                context,
                Icons.notes_outlined,
                'Take notes during any sermon',
              )
            : _buildList(context, ref, notes),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: context.kc.accent,
        foregroundColor: context.kc.onAccent,
        onPressed: () => _openEditor(context),
        child: const Icon(Icons.edit_outlined),
      ),
    );
  }

  Widget _buildMessage(BuildContext context, IconData icon, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: context.kc.muted),
          const SizedBox(height: AppSpacing.lg),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              color: context.kc.muted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(BuildContext context, WidgetRef ref, List<Note> notes) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      itemCount: notes.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        final note = notes[index];
        return _NoteCard(
          note: note,
          onTap: () => _openEditor(context, note: note),
          onPlay: note.isAnchored ? () => _playAnchor(context, ref, note) : null,
          onDelete: () => ref.read(notesRepositoryProvider).delete(note.id),
        );
      },
    );
  }

  void _openEditor(BuildContext context, {Note? note}) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => NoteEditorScreen(existingNote: note),
      ),
    );
  }

  Future<void> _playAnchor(
    BuildContext context,
    WidgetRef ref,
    Note note,
  ) async {
    final result = await NoteAnchor.play(ref, note);
    if (!context.mounted) return;
    if (result == NoteAnchorResult.started) {
      context.push('/player');
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('That message is no longer available'),
        backgroundColor: AppColors.errorContainer,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

// ── Note card ─────────────────────────────────────────────────────────────────

class _NoteCard extends StatelessWidget {
  const _NoteCard({
    required this.note,
    required this.onTap,
    required this.onDelete,
    this.onPlay,
  });

  final Note note;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  /// Non-null only for notes anchored to a playback position.
  final VoidCallback? onPlay;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(note.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.xl),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      onDismissed: (_) => onDelete(),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: context.kc.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Body text preview
              Text(
                note.body,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  color: context.kc.onBg,
                  height: 1.4,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppSpacing.sm),
              // Footer row
              Row(
                children: [
                  if (note.sermonTitle != null) ...[
                    NoteAnchorChip(
                      title: note.sermonTitle!,
                      positionMs: note.positionMs,
                      onTap: onPlay,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  const Spacer(),
                  Text(
                    _relativeDate(note.updatedAt),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: context.kc.muted,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _relativeDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
