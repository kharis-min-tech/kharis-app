import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:kharis_app/features/notes/data/notepad.dart';
import 'package:kharis_app/features/notes/presentation/note_anchor.dart';
import 'package:kharis_app/features/notes/presentation/widgets/notepad_text.dart';
import 'package:kharis_app/features/playlists/presentation/widgets/library_scaffold.dart';
import 'package:kharis_app/features/playlists/presentation/widgets/library_sheets.dart';
import 'package:kharis_app/shared/providers/notes_provider.dart';
import 'package:kharis_app/ui/components/components.dart';

import 'note_editor_screen.dart';
import 'notepad_screen.dart';

/// The member's whole notebook, newest edit first: the "go to their notes and
/// read as they go through" view. Each message is ONE entry (its notepad)
/// whose timestamps play the message from that moment.
class NotesScreen extends ConsumerWidget {
  const NotesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notebook = ref.watch(notebookProvider);

    return LibraryScaffold(
      title: 'Notes',
      actions: [
        KIconButton(
          icon: KIcons.pen,
          label: 'New note',
          variant: KIconButtonVariant.filled,
          onPressed: () => _open(context, null),
        ),
      ],
      slivers: [
        notebook.when(
          loading: () => const LibrarySection(child: LibraryListSkeleton()),
          error: (_, _) => LibraryFill(
            child: KErrorState(
              message:
                  'Your notes didn\u2019t load. Check your connection and '
                  'retry.',
              onRetry: () => ref.invalidate(notesProvider),
            ),
          ),
          data: (entries) => entries.isEmpty
              ? LibraryFill(
                  child: KEmptyState(
                    icon: KIcons.note,
                    title: 'No notes yet',
                    hint:
                        'Take notes while you listen to any message. They '
                        'will appear here.',
                    action: KButton(
                      label: 'Write a note',
                      onPressed: () => _open(context, null),
                    ),
                  ),
                )
              : LibrarySection(child: _buildList(context, ref, entries)),
        ),
      ],
    );
  }

  Widget _buildList(
    BuildContext context,
    WidgetRef ref,
    List<NotebookEntry> entries,
  ) {
    return KListGroup(
      children: [
        for (final entry in entries)
          _NoteRow(
            // Keyed on the message (or the general note), so a row keeps its
            // identity while the notes behind it change.
            key: ValueKey(entry.messageKey ?? entry.notes.single.id),
            entry: entry,
            onTap: () => _open(context, entry),
            onTimestampTap: switch (entry.messageKey) {
              final key? => (position) => _play(context, ref, key, position),
              null => null,
            },
            onDelete: () {
              final repo = ref.read(notesRepositoryProvider);
              for (final note in entry.notes) {
                repo.delete(note.id);
              }
            },
          ),
      ],
    );
  }

  /// A message's notepad, a general note, or (null) a new general note.
  void _open(BuildContext context, NotebookEntry? entry) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => switch (entry?.messageKey) {
          final key? => NotepadScreen(
            messageKey: key,
            notes: entry!.notes,
            title: entry.title,
          ),
          null => NoteEditorScreen(existingNote: entry?.notes.single),
        },
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

// ── Note row ──────────────────────────────────────────────────────────────────

/// One notebook entry, laid out as a list row: the message title (or "Note"
/// for a general note), a two-line snippet whose timestamps stay tappable,
/// and when it was last edited.
class _NoteRow extends StatelessWidget {
  const _NoteRow({
    super.key,
    required this.entry,
    required this.onTap,
    required this.onDelete,
    this.onTimestampTap,
  });

  final NotebookEntry entry;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  /// Non-null for a message's notepad: plays the message from a timestamp.
  final ValueChanged<Duration>? onTimestampTap;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return Dismissible(
      key: ValueKey('dismiss-${entry.messageKey ?? entry.notes.single.id}'),
      direction: DismissDirection.endToStart,
      background: ColoredBox(
        color: k.error,
        child: Align(
          alignment: AlignmentDirectional.centerEnd,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: KSpace.x3),
            child: Text(
              'Delete',
              style: KharisText.link.copyWith(color: k.onError),
            ),
          ),
        ),
      ),
      // A notepad holds everything written on a message: ask first.
      confirmDismiss: entry.isMessage
          ? (_) => showConfirmSheet(
              context,
              title: 'Delete these notes?',
              message: entry.title == null
                  ? 'Everything you wrote on this message will be deleted.'
                  : 'Everything you wrote on "${entry.title}" will be '
                        'deleted.',
              confirmLabel: 'Delete',
            )
          : null,
      onDismissed: (_) => onDelete(),
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: KSize.listRow),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: KSpace.x3,
              vertical: KSpace.lg,
            ),
            child: Row(
              children: [
                KIconTile(entry.isMessage ? KIcons.audio : KIcons.note),
                const SizedBox(width: KSpace.xl),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        entry.title ?? 'Note',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: KharisText.itemTitle.copyWith(color: k.text),
                      ),
                      NotepadText(
                        entry.text.trim(),
                        style: KharisText.meta.copyWith(color: k.muted),
                        maxLines: 2,
                        onTimestampTap: onTimestampTap,
                      ),
                      const SizedBox(height: KSpace.xxs),
                      Text(
                        _editedLabel(entry.updatedAt),
                        style: KharisText.caption.copyWith(color: k.muted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: KSpace.md),
                KIcon(KIcons.chevronRight, size: KSize.iconSm, color: k.muted),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// "Just now", "12 min ago", "3 h ago", "Yesterday", then "Sun 15 Nov"
  /// (with the year once it is not this one).
  static String _editedLabel(DateTime at) {
    final now = DateTime.now();
    final age = now.difference(at);
    if (age.inSeconds < 60) return 'Just now';
    if (age.inMinutes < 60) return '${age.inMinutes} min ago';
    if (age.inHours < 24) return '${age.inHours} h ago';
    if (age.inDays == 1) return 'Yesterday';
    return DateFormat(
      at.year == now.year ? 'EEE d MMM' : 'd MMM yyyy',
    ).format(at);
  }
}
