import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:kharis_app/core/theme/app_colors.dart';
import 'package:kharis_app/core/theme/app_spacing.dart';
import 'package:kharis_app/features/notes/data/note_repository.dart';
import 'package:kharis_app/shared/models/sermon.dart';
import 'package:kharis_app/shared/providers/notes_provider.dart';

class NoteEditorScreen extends ConsumerStatefulWidget {
  const NoteEditorScreen({
    super.key,
    this.existingNote,
    this.sermon,
    this.positionMs,
  });

  /// When editing an existing note.
  final Note? existingNote;

  /// When opened from the player: pre-tags the note with this sermon.
  final Sermon? sermon;

  /// Playback position at the moment the editor was opened (milliseconds).
  final int? positionMs;

  @override
  ConsumerState<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends ConsumerState<NoteEditorScreen> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.existingNote?.text ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      Navigator.of(context).pop();
      return;
    }

    final repo = ref.read(notesRepositoryProvider);
    final now = DateTime.now();

    final note = widget.existingNote != null
        ? widget.existingNote!.copyWith(
            text: text,
            updatedAt: now,
          )
        : Note(
            id: NoteRepository.generateId(),
            sermonId: widget.sermon?.id,
            sermonTitle: widget.sermon?.title,
            positionMs: widget.positionMs,
            text: text,
            createdAt: now,
            updatedAt: now,
          );

    await repo.upsert(note);
    ref.read(notesRevisionProvider.notifier).state++;

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final showTag =
        widget.sermon != null || widget.existingNote?.sermonTitle != null;
    final tagSermon = showTag ? _buildSermonTag() : null;

    return Scaffold(
      backgroundColor: AppColors.surfaceDark,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceDark,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.onSurface),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          TextButton(
            onPressed: _save,
            child: Text(
              'Save',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (tagSermon != null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              child: tagSermon,
            ),
          ],
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: TextField(
                controller: _controller,
                autofocus: true,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  color: AppColors.onSurface,
                  height: 1.6,
                ),
                cursorColor: AppColors.primary,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Start typing...',
                  hintStyle: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget? _buildSermonTag() {
    // Prefer live sermon (opened from player); fall back to existing note tag.
    final title = widget.sermon?.title ?? widget.existingNote?.sermonTitle;
    final posMs = widget.positionMs ?? widget.existingNote?.positionMs;

    if (title == null) return null;

    final label = posMs != null ? '$title @ ${_formatMs(posMs)}' : title;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.headphones_outlined,
            size: 14,
            color: AppColors.primary,
          ),
          const SizedBox(width: AppSpacing.xs),
          Flexible(
            child: Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: AppColors.primary,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
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
