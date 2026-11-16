import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:kharis_app/features/bible/presentation/bible_routes.dart';
import 'package:kharis_app/features/bible/presentation/screens/highlights_screen.dart';
import 'package:kharis_app/shared/providers/verse_marks_provider.dart';
import 'package:kharis_app/ui/components/components.dart';

/// The member's verse notes, most recently edited first (`/bible/notes`).
/// Each opens its verse in the reader with the verse sheet on it.
class VerseNotesScreen extends ConsumerWidget {
  const VerseNotesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notes = ref.watch(verseNotesProvider);
    return BibleListScaffold(
      title: 'My notes',
      empty: notes.isEmpty
          ? const KEmptyState(
              key: Key('verse-notes-empty'),
              icon: KIcons.note,
              title: 'No notes yet',
              hint: 'Tap a verse in the reader to write a note on it.',
            )
          : null,
      children: [
        for (final n in notes)
          KListRow(
            key: Key('verse-note-${n.ref.usfm}'),
            title: n.ref.reference,
            meta: n.body,
            leading: const KIconTile(KIcons.note),
            showChevron: true,
            onTap: () => unawaited(
              context.push(bibleReaderPath(n.ref.location, openVerse: true)),
            ),
          ),
      ],
    );
  }
}
