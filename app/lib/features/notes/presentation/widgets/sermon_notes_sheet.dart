import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/features/notes/data/note_repository.dart';
import 'package:kharis_app/features/notes/data/note_timeline_key.dart';
import 'package:kharis_app/features/notes/presentation/note_anchor.dart';
import 'package:kharis_app/features/notes/presentation/screens/note_editor_screen.dart';
import 'package:kharis_app/features/notes/presentation/widgets/note_anchor_chip.dart';
import 'package:kharis_app/shared/models/sermon.dart';
import 'package:kharis_app/shared/providers/audio_provider.dart';
import 'package:kharis_app/shared/providers/notes_provider.dart';

/// Binds [SermonNotesSheet] to the engine that owns playback on the screen
/// that opened it.
///
/// Without a binding the sheet reads the audio service — the default, and the
/// only engine reachable outside the unified player. The video mode of the
/// unified player passes one so a new note is stamped with the VIDEO engine's
/// clock and an anchor tap seeks the video, instead of waking the stopped
/// audio source underneath it.
class NoteTimelineBinding {
  const NoteTimelineBinding({this.position, this.seek});

  /// Live playback position of the active engine. Null when the engine has no
  /// position channel (the web iframe embed) — notes are then written without
  /// a timestamp.
  final Stream<Duration>? position;

  /// Seeks the active engine to a note's anchor.
  final Future<void> Function(Duration target)? seek;
}

/// Everything the member has written against one message, in timeline order —
/// the "show what they wrote on that timeline" view. Opened from the player.
///
/// Notes are keyed by [NoteTimelineKey], so the audio and video variants of
/// the same message share ONE timeline: a note taken at 12:30 in audio shows
/// at 12:30 in video.
///
/// Tapping a note's timestamp seeks playback back to it; tapping the body
/// opens the note for editing.
class SermonNotesSheet extends ConsumerWidget {
  const SermonNotesSheet({super.key, required this.sermon, this.timeline});

  final Sermon sermon;

  /// The engine that owns playback where this sheet was opened; null falls
  /// back to the audio service.
  final NoteTimelineBinding? timeline;

  static Future<void> show(
    BuildContext context,
    Sermon sermon, {
    NoteTimelineBinding? timeline,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SermonNotesSheet(sermon: sermon, timeline: timeline),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notes = ref.watch(sermonNotesProvider(NoteTimelineKey.of(sermon)));

    return SafeArea(
      top: false,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.75,
        ),
        decoration: BoxDecoration(
          color: context.kc.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _grabber(context),
            _header(context, notes.length),
            Flexible(
              child: notes.isEmpty
                  ? _empty(context)
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        0,
                        AppSpacing.lg,
                        AppSpacing.md,
                      ),
                      shrinkWrap: true,
                      itemCount: notes.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: AppSpacing.sm),
                      itemBuilder: (context, index) => _TimelineNoteTile(
                        note: notes[index],
                        onSeek: () => _seek(context, ref, notes[index]),
                        onEdit: () => _openEditor(context, note: notes[index]),
                        onDelete: () =>
                            ref.read(notesRepositoryProvider).delete(
                                  notes[index].id,
                                ),
                      ),
                    ),
            ),
            _addButton(context),
          ],
        ),
      ),
    );
  }

  // ── Chrome ─────────────────────────────────────────────────────────────────

  Widget _grabber(BuildContext context) => Container(
        margin: const EdgeInsets.only(top: AppSpacing.sm),
        height: 4,
        width: 40,
        decoration: BoxDecoration(
          color: context.kc.divider,
          borderRadius: BorderRadius.circular(2),
        ),
      );

  Widget _header(BuildContext context, int count) => Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.md,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              count == 1 ? '1 note on this message' : '$count notes on this message',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: context.kc.onBg,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              sermon.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: context.kc.muted,
              ),
            ),
          ],
        ),
      );

  Widget _empty(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.xl,
        ),
        child: Text(
          'Nothing written on this message yet. Notes you add here are stamped '
          'with the moment you wrote them.',
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            height: 1.5,
            color: context.kc.muted,
          ),
        ),
      );

  /// Rebuilt on its own so the ticking playback position does not repaint the
  /// whole sheet.
  ///
  /// The position comes from the ACTIVE engine: the [timeline] binding when
  /// the opening screen passed one (video mode), otherwise the audio service.
  Widget _addButton(BuildContext context) {
    final binding = timeline;
    final Widget button;
    if (binding != null) {
      final position = binding.position;
      button = position == null
          ? _addButtonBody(context, null)
          : StreamBuilder<Duration>(
              stream: position,
              builder: (context, snapshot) =>
                  _addButtonBody(context, snapshot.data?.inMilliseconds),
            );
    } else {
      button = Consumer(
        builder: (context, ref, _) =>
            _addButtonBody(context, _livePositionMs(ref)),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: SizedBox(width: double.infinity, child: button),
    );
  }

  Widget _addButtonBody(BuildContext context, int? positionMs) =>
      FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: context.kc.accent,
          foregroundColor: context.kc.onAccent,
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        onPressed: () => _openEditor(context, capturePositionMs: positionMs),
        icon: const Icon(Icons.edit_outlined, size: 18),
        label: Text(
          positionMs == null
              ? 'Add a note'
              : 'Add a note at ${formatNotePosition(positionMs)}',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      );

  // ── Actions ────────────────────────────────────────────────────────────────

  /// The current audio playback position, but only when this sheet's message
  /// is the one actually loaded — otherwise a new note would be stamped with
  /// an unrelated timestamp. Variants are matched through [NoteTimelineKey]
  /// so the audio service holding a different id of the SAME message still
  /// counts.
  int? _livePositionMs(WidgetRef ref) {
    final playing = ref.watch(currentSermonProvider);
    if (playing == null || !NoteTimelineKey.of(sermon).matches(playing.id)) {
      return null;
    }
    return ref.watch(positionProvider).valueOrNull?.inMilliseconds;
  }

  void _openEditor(
    BuildContext context, {
    Note? note,
    int? capturePositionMs,
  }) {
    // Capture the navigator before the sheet is popped: `context` is defunct
    // once its route is gone.
    final navigator = Navigator.of(context);
    navigator.pop();
    navigator.push<void>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => NoteEditorScreen(
          existingNote: note,
          sermon: note == null ? sermon : null,
          positionMs: note == null ? capturePositionMs : null,
        ),
      ),
    );
  }

  Future<void> _seek(BuildContext context, WidgetRef ref, Note note) async {
    // The opening screen's engine owns playback (video mode of the unified
    // player): seek IT — waking the audio engine here would double-play
    // underneath the video.
    final engineSeek = timeline?.seek;
    final positionMs = note.positionMs;
    if (engineSeek != null && positionMs != null) {
      await engineSeek(Duration(milliseconds: positionMs));
      if (context.mounted) Navigator.of(context).pop();
      return;
    }

    final result = await NoteAnchor.play(ref, note);
    if (!context.mounted) return;
    if (result == NoteAnchorResult.started) {
      Navigator.of(context).pop();
      return;
    }
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
  }
}

// ── Row ───────────────────────────────────────────────────────────────────────

class _TimelineNoteTile extends StatelessWidget {
  const _TimelineNoteTile({
    required this.note,
    required this.onSeek,
    required this.onEdit,
    required this.onDelete,
  });

  final Note note;
  final VoidCallback onSeek;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final positionMs = note.positionMs;

    return Dismissible(
      key: ValueKey(note.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      onDismissed: (_) => onDelete(),
      child: GestureDetector(
        onTap: onEdit,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: context.kc.surfaceAlt,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (positionMs != null)
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.md),
                  child: _SeekPill(positionMs: positionMs, onTap: onSeek),
                ),
              Expanded(
                child: Text(
                  note.body,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    height: 1.4,
                    color: context.kc.onBg,
                  ),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SeekPill extends StatelessWidget {
  const _SeekPill({required this.positionMs, required this.onTap});

  final int positionMs;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Play from ${formatNotePosition(positionMs)}',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.play_arrow_rounded,
                size: 14,
                color: AppColors.primary,
              ),
              const SizedBox(width: 2),
              Text(
                formatNotePosition(positionMs),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
