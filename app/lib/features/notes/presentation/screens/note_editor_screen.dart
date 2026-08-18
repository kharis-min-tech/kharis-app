import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/features/notes/data/note_repository.dart';
import 'package:kharis_app/features/notes/data/note_timeline_key.dart';
import 'package:kharis_app/features/notes/presentation/note_anchor.dart';
import 'package:kharis_app/features/notes/presentation/widgets/note_anchor_chip.dart';
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

    final sermon = widget.sermon;
    final note = widget.existingNote != null
        ? widget.existingNote!.copyWith(body: text, updatedAt: now)
        : Note(
            id: repo.newId(),
            // Canonical key, not the raw sermon id: the audio and video
            // variants of one message must share a single note timeline.
            sermonId: sermon == null ? null : NoteTimelineKey.of(sermon).canonical,
            sermonTitle: sermon?.title,
            positionMs: widget.positionMs,
            body: text,
            createdAt: now,
            updatedAt: now,
          );

    await repo.upsert(note);

    if (mounted) Navigator.of(context).pop();
  }

  /// Plays the anchored sermon from the note's timestamp and closes the
  /// editor so the player is visible underneath.
  Future<void> _playFromAnchor() async {
    final note = widget.existingNote;
    if (note == null) return;
    final result = await NoteAnchor.play(ref, note);
    if (!mounted) return;
    if (result == NoteAnchorResult.sermonUnavailable ||
        result == NoteAnchorResult.playbackFailed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result == NoteAnchorResult.playbackFailed
                ? 'Couldn\u2019t play that message. Please try again.'
                : 'That message is no longer available',
          ),
          backgroundColor: AppColors.errorContainer,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final showTag =
        widget.sermon != null || widget.existingNote?.sermonTitle != null;
    final tagSermon = showTag ? _buildSermonTag() : null;

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
                  color: context.kc.onBg,
                  height: 1.6,
                ),
                cursorColor: AppColors.primary,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Start typing...',
                  hintStyle: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    color: context.kc.muted,
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
    if (title == null) return null;

    final posMs = widget.positionMs ?? widget.existingNote?.positionMs;
    // Only offer "jump back to this moment" when re-reading a saved note; a
    // note being written from the player is already at that moment.
    final canSeek =
        widget.sermon == null && (widget.existingNote?.isAnchored ?? false);

    return Align(
      alignment: Alignment.centerLeft,
      child: NoteAnchorChip(
        title: title,
        positionMs: posMs,
        maxWidth: 320,
        onTap: canSeek ? _playFromAnchor : null,
      ),
    );
  }
}
