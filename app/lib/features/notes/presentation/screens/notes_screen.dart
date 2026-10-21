import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/features/notes/data/notepad.dart';
import 'package:kharis_app/features/notes/presentation/note_anchor.dart';
import 'package:kharis_app/features/notes/presentation/widgets/note_anchor_chip.dart';
import 'package:kharis_app/features/notes/presentation/widgets/notepad_text.dart';
import 'package:kharis_app/shared/providers/notes_provider.dart';

import 'note_editor_screen.dart';
import 'notepad_screen.dart';

/// The member's whole notebook, newest edit first: the "go to their notes and
/// read as they go through" view. Each message is ONE entry — its notepad —
/// whose timestamps play the message from that moment.
class NotesScreen extends ConsumerWidget {
  const NotesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notebook = ref.watch(notebookProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: context.kc.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Notes',
          style: AppTypography.display(
            size: 28,
            weight: FontWeight.w700,
            color: context.kc.onBg,
          ),
        ),
      ),
      body: notebook.when(
        loading: () => Center(
          child: CircularProgressIndicator(
            color: context.kc.accentInk,
            strokeWidth: 2,
          ),
        ),
        error: (_, _) => _buildMessage(
          context,
          Icons.cloud_off_outlined,
          'Your notes couldn\u2019t be loaded. Check your connection and try '
          'again.',
          actionLabel: 'Retry',
          onAction: () => ref.invalidate(notesProvider),
        ),
        data: (entries) => entries.isEmpty
            ? _buildMessage(
                context,
                Icons.notes_outlined,
                'Take notes while you listen to any message. They will appear here.',
              )
            : _buildList(context, ref, entries),
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'New note',
        backgroundColor: context.kc.accent,
        foregroundColor: context.kc.onAccent,
        onPressed: () => _open(context, null),
        child: const Icon(Icons.edit_outlined),
      ),
    );
  }

  Widget _buildMessage(
    BuildContext context,
    IconData icon,
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 56, color: context.kc.muted),
            const SizedBox(height: AppSpacing.md),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTypography.ui(size: 16, color: context.kc.muted),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppSpacing.sm),
              TextButton(
                onPressed: onAction,
                child: Text(
                  actionLabel,
                  style: AppTypography.ui(
                    size: 14,
                    weight: FontWeight.w700,
                    color: context.kc.accentInk,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildList(
    BuildContext context,
    WidgetRef ref,
    List<NotebookEntry> entries,
  ) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.marginMobile,
        AppSpacing.sm,
        AppSpacing.marginMobile,
        96,
      ),
      itemCount: entries.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        final entry = entries[index];
        final key = entry.messageKey;
        return _NoteCard(
          // Keyed on the message (or the general note), so a card keeps its
          // identity while the notes behind it change.
          key: ValueKey(key ?? entry.notes.single.id),
          entry: entry,
          onTap: () => _open(context, entry),
          onTimestampTap: key == null
              ? null
              : (position) => _play(context, ref, key, position),
          onDelete: () {
            final repo = ref.read(notesRepositoryProvider);
            for (final note in entry.notes) {
              repo.delete(note.id);
            }
          },
        );
      },
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
        backgroundColor: AppColors.errorContainer,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

// ── Note card ─────────────────────────────────────────────────────────────────

class _NoteCard extends StatelessWidget {
  const _NoteCard({
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
    final title = entry.title;
    return Dismissible(
      key: ValueKey('dismiss-${entry.messageKey ?? entry.notes.single.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.danger,
          borderRadius: AppRadius.cardBorder,
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      // A notepad holds everything written on a message: ask first.
      confirmDismiss: entry.isMessage ? (_) => _confirmDelete(context) : null,
      onDismissed: (_) => onDelete(),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.gutter),
          decoration: BoxDecoration(
            color: context.kc.surface,
            borderRadius: AppRadius.cardBorder,
            boxShadow: AppShadows.card,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              NotepadText(
                entry.text.trim(),
                style: AppTypography.ui(
                  size: 15,
                  color: context.kc.onBg,
                  height: 1.4,
                ),
                maxLines: 3,
                onTimestampTap: onTimestampTap,
              ),
              const SizedBox(height: AppSpacing.xs),
              // Footer row. The chip region takes the free width (the chip
              // caps itself at 220): fixed, it overflowed a 360 px phone.
              Row(
                children: [
                  Expanded(
                    child: title == null
                        ? const SizedBox.shrink()
                        : Align(
                            alignment: Alignment.centerLeft,
                            child: NoteAnchorChip(title: title),
                          ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    _relativeDate(entry.updatedAt),
                    style: AppTypography.ui(size: 12, color: context.kc.muted),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: dialogContext.kc.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        title: Text(
          'Delete these notes?',
          style: AppTypography.display(
            size: 20,
            weight: FontWeight.w700,
            color: dialogContext.kc.onBg,
          ),
        ),
        content: Text(
          entry.title == null
              ? 'Everything you wrote on this message will be deleted.'
              : 'Everything you wrote on "${entry.title}" will be deleted.',
          style: AppTypography.bodySm.copyWith(
            fontSize: 14,
            height: 1.5,
            color: dialogContext.kc.muted,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              'Cancel',
              style: AppTypography.ui(
                size: 14,
                weight: FontWeight.w600,
                color: dialogContext.kc.muted,
              ),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            child: Text(
              'Delete',
              style: AppTypography.ui(
                size: 14,
                weight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
    return confirmed ?? false;
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
