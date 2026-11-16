import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kharis_app/features/notes/data/note_repository.dart';
import 'package:kharis_app/features/notes/presentation/widgets/note_page.dart';
import 'package:kharis_app/shared/providers/notes_provider.dart';
import 'package:kharis_app/ui/components/components.dart';

/// Writes or edits a general note: one not tied to a message. Notes on a
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
    final k = context.k;
    return NotePage(
      title: widget.existingNote == null ? 'New note' : 'Note',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: KSpace.gutter),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                autofocus: true,
                maxLines: null,
                expands: true,
                keyboardType: TextInputType.multiline,
                textCapitalization: TextCapitalization.sentences,
                textAlignVertical: TextAlignVertical.top,
                style: KharisText.body.copyWith(color: k.text),
                cursorColor: k.primaryText,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Start typing',
                  hintStyle: KharisText.body.copyWith(color: k.muted),
                ),
              ),
            ),
            const SizedBox(height: KSpace.md),
            KButton(label: 'Save', expand: true, onPressed: _save),
            const SizedBox(height: KSpace.x3),
          ],
        ),
      ),
    );
  }
}
