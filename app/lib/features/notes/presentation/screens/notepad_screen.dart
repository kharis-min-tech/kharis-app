import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:kharis_app/features/notes/data/note_repository.dart';
import 'package:kharis_app/features/notes/data/note_timeline_key.dart';
import 'package:kharis_app/features/notes/presentation/note_anchor.dart';
import 'package:kharis_app/features/notes/presentation/widgets/note_page.dart';
import 'package:kharis_app/features/notes/presentation/widgets/notepad_editor.dart';
import 'package:kharis_app/ui/components/components.dart';

/// A message's notepad opened from the notebook. The same editor as the
/// player's notes sheet; a tapped timestamp plays the message from there and
/// opens the player.
class NotepadScreen extends ConsumerWidget {
  const NotepadScreen({
    super.key,
    required this.messageKey,
    required this.notes,
    this.title,
  });

  /// The key the message's notes share.
  final String messageKey;

  /// Everything written on the message.
  final List<Note> notes;

  /// The message title, when the notes carry one.
  final String? title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = messageKey;
    return NotePage(
      title: 'Notes',
      subtitle: title,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          KSpace.gutter,
          0,
          KSpace.gutter,
          KSpace.x3,
        ),
        child: NotepadEditor(
          notes: notes,
          messageKey: key,
          title: title,
          isThisMessage: (playing) => NoteTimelineKey.of(playing).matches(key),
          onSeek: (position) => _play(context, ref, key, position),
        ),
      ),
    );
  }

  Future<void> _play(
    BuildContext context,
    WidgetRef ref,
    String key,
    Duration position,
  ) async {
    final result = await NoteAnchor.play(ref, key, position);
    if (!context.mounted) return;
    if (result == NoteAnchorResult.started) {
      context.push('/player');
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(NoteAnchor.failureMessage(result)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
