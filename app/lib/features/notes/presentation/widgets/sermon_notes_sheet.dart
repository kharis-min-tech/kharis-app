import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kharis_app/features/notes/data/note_timeline_key.dart';
import 'package:kharis_app/features/notes/presentation/note_anchor.dart';
import 'package:kharis_app/features/notes/presentation/widgets/notepad_editor.dart';
import 'package:kharis_app/shared/models/sermon.dart';
import 'package:kharis_app/shared/providers/notes_provider.dart';
import 'package:kharis_app/ui/components/components.dart';

/// Binds [SermonNotesSheet] to the engine that owns playback on the screen
/// that opened it.
///
/// Without a binding the sheet reads the audio service: the default, and the
/// only engine reachable outside the unified player. The video mode of the
/// unified player passes one so an inserted timestamp is the VIDEO engine's
/// clock and a timestamp tap seeks the video, instead of waking the stopped
/// audio source underneath it.
class NoteTimelineBinding {
  const NoteTimelineBinding({this.position, this.seek});

  /// Live playback position of the active engine. Null when the engine has no
  /// position channel (the web iframe embed): Insert is then unavailable.
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

  /// How much of the screen height the notepad asks for. The sheet gives it
  /// less when the keyboard or the status bar leave less.
  static const double _heightFactor = 0.7;

  static Future<void> show(
    BuildContext context,
    Sermon sermon, {
    NoteTimelineBinding? timeline,
  }) {
    return showKBottomSheet<void>(
      context: context,
      title: 'Notes',
      builder: (_) => SermonNotesSheet(sermon: sermon, timeline: timeline),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final k = context.k;
    final key = NoteTimelineKey.of(sermon);
    // Wait for the notebook before opening the pad: the notepad is composed
    // once, from everything already written on this message.
    final notebook = ref.watch(notesProvider);
    final loaded = notebook.hasValue || notebook.hasError;

    return Padding(
      // Lift the notepad over the keyboard, so the field, the cursor and
      // Insert stay in view.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * _heightFactor,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    sermon.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: KharisText.meta.copyWith(color: k.muted),
                  ),
                ),
                const SizedBox(width: KSpace.md),
                // Closing saves (the notepad flushes as it goes).
                KTextLink(
                  label: 'Done',
                  semanticLabel: 'Done, close notes',
                  onTap: () => Navigator.of(context).pop(),
                ),
              ],
            ),
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
                      onSeek: (position) => _seek(context, ref, key, position),
                    )
                  : const Align(
                      alignment: Alignment.topCenter,
                      child: Padding(
                        padding: EdgeInsets.only(top: KSpace.xl),
                        child: KSkeleton(
                          height: KSpace.xxl,
                          radius: KRadius.xs,
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

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
    // player): seek IT. Waking the audio engine here would double-play
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
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
