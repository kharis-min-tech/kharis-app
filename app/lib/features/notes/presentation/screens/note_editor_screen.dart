import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/features/notes/data/note_repository.dart';
import 'package:kharis_app/shared/providers/notes_provider.dart';

/// Writes or edits a general note — one not tied to a message. Notes on a
/// message live in its notepad (`NotepadScreen`, or the player's notes
/// sheet).
class NoteEditorScreen extends ConsumerStatefulWidget {
  const NoteEditorScreen({super.key, this.existingNote});

  /// When editing an existing note.
  final Note? existingNote;

  @override
  ConsumerState<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends ConsumerState<NoteEditorScreen> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.existingNote?.body ?? '');
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
        ? widget.existingNote!.copyWith(body: text, updatedAt: now)
        : Note(id: repo.newId(), body: text, createdAt: now, updatedAt: now);

    await repo.upsert(note);

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: context.kc.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: context.kc.onBg),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          TextButton(
            onPressed: _save,
            child: Text(
              'Save',
              style: AppTypography.ui(
                size: 16,
                weight: FontWeight.w600,
                color: context.kc.accentInk,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: TextField(
          controller: _controller,
          autofocus: true,
          maxLines: null,
          expands: true,
          textAlignVertical: TextAlignVertical.top,
          style: AppTypography.ui(
            size: 16,
            color: context.kc.onBg,
            height: 1.6,
          ),
          cursorColor: context.kc.accentInk,
          decoration: InputDecoration(
            border: InputBorder.none,
            hintText: 'Start typing...',
            hintStyle: AppTypography.ui(size: 16, color: context.kc.muted),
          ),
        ),
      ),
    );
  }
}
