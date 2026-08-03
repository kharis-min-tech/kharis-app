import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/features/notes/data/note_repository.dart';
import 'package:kharis_app/shared/providers/notes_provider.dart';

import 'note_editor_screen.dart';

class NotesScreen extends ConsumerWidget {
  const NotesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notes = ref.watch(notesProvider);

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
      body: notes.isEmpty
          ? _buildEmpty(context)
          : _buildList(context, ref, notes),
      floatingActionButton: FloatingActionButton(
        backgroundColor: context.kc.accent,
        foregroundColor: context.kc.onAccent,
        onPressed: () => _openEditor(context, ref),
        child: const Icon(Icons.edit_outlined),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notes_outlined,
            size: 64,
            color: context.kc.muted,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Take notes during any sermon',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              color: context.kc.muted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(
    BuildContext context,
    WidgetRef ref,
    List<Note> notes,
  ) {
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
          onTap: () => _openEditor(context, ref, note: note),
          onDelete: () async {
            await ref.read(notesRepositoryProvider).delete(note.id);
            ref.read(notesRevisionProvider.notifier).state++;
          },
        );
      },
    );
  }

  void _openEditor(BuildContext context, WidgetRef ref, {Note? note}) {
    Navigator.of(context)
        .push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => NoteEditorScreen(existingNote: note),
      ),
    )
        .then((_) {
      // Refresh list after returning from editor
      ref.read(notesRevisionProvider.notifier).state++;
    });
  }
}

// ── Note card ─────────────────────────────────────────────────────────────────

class _NoteCard extends StatelessWidget {
  const _NoteCard({
    required this.note,
    required this.onTap,
    required this.onDelete,
  });

  final Note note;
  final VoidCallback onTap;
  final VoidCallback onDelete;

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
                note.text,
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
                    _SermonChip(
                      title: note.sermonTitle!,
                      positionMs: note.positionMs,
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

// ── Sermon + timestamp chip ───────────────────────────────────────────────────

class _SermonChip extends StatelessWidget {
  const _SermonChip({required this.title, this.positionMs});

  final String title;
  final int? positionMs;

  @override
  Widget build(BuildContext context) {
    final label = positionMs != null
        ? '$title @ ${_formatMs(positionMs!)}'
        : title;

    return Container(
      constraints: const BoxConstraints(maxWidth: 220),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 11,
          color: AppColors.primary,
          fontWeight: FontWeight.w500,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  String _formatMs(int ms) {
    final d = Duration(milliseconds: ms);
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
