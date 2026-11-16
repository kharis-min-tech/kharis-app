import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/home/data/verse_marks_repository.dart';
import 'cache_provider.dart';
import 'clock_provider.dart';

export '../../features/home/data/verse_marks_repository.dart'
    show ChapterMarks, VerseHighlight, VerseNote, VerseRef;

/// Verse highlights and verse notes on this device. Change them through it:
/// `setHighlight`, `clearHighlight`, `saveNote`, `deleteNote`.
final verseMarksRepositoryProvider = Provider<VerseMarksRepository>((ref) {
  return VerseMarksRepository(
    ref.watch(cacheServiceProvider),
    clock: ref.watch(clockProvider),
  );
});

/// Re-runs the watching provider whenever a mark changes.
VerseMarksRepository _watchMarks(Ref ref) {
  final repository = ref.watch(verseMarksRepositoryProvider);
  void changed() => ref.invalidateSelf();
  repository.changes.addListener(changed);
  ref.onDispose(() => repository.changes.removeListener(changed));
  return repository;
}

/// The highlights and notes on one chapter, by verse number, for the
/// reader. `book` is the USFM code.
final chapterMarksProvider = Provider.autoDispose
    .family<ChapterMarks, ({String book, int chapter})>(
      (ref, at) => _watchMarks(ref).chapter(at.book, at.chapter),
    );

/// Every highlight, most recently made first, with its reference, version
/// and verse text.
final verseHighlightsProvider = Provider<List<VerseHighlight>>(
  (ref) => _watchMarks(ref).highlights(),
);

/// Every verse note, most recently edited first, with its reference, version
/// and verse text.
final verseNotesProvider = Provider<List<VerseNote>>(
  (ref) => _watchMarks(ref).notes(),
);

/// How many verses are highlighted.
final verseHighlightCountProvider = Provider<int>(
  (ref) => ref.watch(verseHighlightsProvider).length,
);

/// How many verses carry a note.
final verseNoteCountProvider = Provider<int>(
  (ref) => ref.watch(verseNotesProvider).length,
);
