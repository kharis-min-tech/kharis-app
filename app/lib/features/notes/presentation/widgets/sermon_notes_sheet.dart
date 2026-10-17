import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/features/notes/data/note_timeline_key.dart';
import 'package:kharis_app/features/notes/presentation/note_anchor.dart';
import 'package:kharis_app/features/notes/presentation/widgets/notepad_editor.dart';
import 'package:kharis_app/shared/models/sermon.dart';
import 'package:kharis_app/shared/providers/notes_provider.dart';

/// Binds [SermonNotesSheet] to the engine that owns playback on the screen
/// that opened it.
///
/// Without a binding the sheet reads the audio service — the default, and the
/// only engine reachable outside the unified player. The video mode of the
/// unified player passes one so an inserted timestamp is the VIDEO engine's
/// clock and a timestamp tap seeks the video, instead of waking the stopped
/// audio source underneath it.
class NoteTimelineBinding {
  const NoteTimelineBinding({this.position, this.seek});

  /// Live playback position of the active engine. Null when the engine has no
  /// position channel (the web iframe embed) — Insert is then unavailable.
  final Stream<Duration>? position;

  /// Seeks the active engine to a timestamp.
  final Future<void> Function(Duration target)? seek;
}

/// The member's notepad for one message, opened from the player: free typing,
/// with "Insert" stamping the playback moment at the cursor and every stamp
/// tappable to seek back to it.
///
/// Notes are keyed by [NoteTimelineKey], so the audio and video variants of
/// the same message share ONE notepad: a stamp taken at 12:30 in audio seeks
/// to 12:30 in video.
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
    final key = NoteTimelineKey.of(sermon);
    // Wait for the notebook before opening the pad: the notepad is composed
    // once, from everything already written on this message.
    final notebook = ref.watch(notesProvider);
    final loaded = notebook.hasValue || notebook.hasError;

    final screen = MediaQuery.sizeOf(context).height;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    // Most of the screen, shrinking with the keyboard so the field, the
    // cursor and Insert stay in view; never under the status bar.
    final height = math.min(
      screen * 0.85,
      screen - keyboard - MediaQuery.paddingOf(context).top - AppSpacing.lg,
    );

    return Padding(
      // Lift the notepad over the keyboard.
      padding: EdgeInsets.only(bottom: keyboard),
      child: SafeArea(
        top: false,
        child: Container(
          height: height,
          decoration: BoxDecoration(
            color: context.kc.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              _grabber(context),
              _header(context),
              Expanded(
                child: loaded
                    ? NotepadEditor(
                        notes: ref.watch(sermonNotesProvider(key)),
                        messageKey: key.canonical,
                        title: sermon.title,
                        timeline: timeline,
                        isThisMessage: (playing) =>
                            NoteTimelineKey.of(playing).canonical ==
                                key.canonical ||
                            key.matches(playing.id),
                        onSeek: (position) =>
                            _seek(context, ref, key, position),
                      )
                    : Center(
                        child: CircularProgressIndicator(
                          color: context.kc.accentInk,
                          strokeWidth: 2,
                        ),
                      ),
              ),
            ],
          ),
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

  Widget _header(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.lg,
      AppSpacing.md,
      AppSpacing.sm,
      AppSpacing.sm,
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Notes',
                style: AppTypography.ui(
                  size: 18,
                  weight: FontWeight.w700,
                  color: context.kc.onBg,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                sermon.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.ui(size: 13, color: context.kc.muted),
              ),
            ],
          ),
        ),
        // Closing saves (the notepad flushes as it goes).
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Done',
            style: AppTypography.ui(
              size: 16,
              weight: FontWeight.w600,
              color: context.kc.accentInk,
            ),
          ),
        ),
      ],
    ),
  );

  // ── Actions ────────────────────────────────────────────────────────────────

  /// Seeks to a tapped timestamp and keeps the notepad open, so the member
  /// can listen back and keep writing.
  Future<void> _seek(
    BuildContext context,
    WidgetRef ref,
    NoteTimelineKey key,
    Duration position,
  ) async {
    // The opening screen's engine owns playback (video mode of the unified
    // player): seek IT — waking the audio engine here would double-play
    // underneath the video.
    final engineSeek = timeline?.seek;
    if (engineSeek != null) {
      await engineSeek(position);
      return;
    }

    final result = await NoteAnchor.play(ref, key.canonical, position);
    if (result == NoteAnchorResult.started || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(NoteAnchor.failureMessage(result)),
        backgroundColor: AppColors.errorContainer,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
