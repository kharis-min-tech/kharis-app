import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/notes/data/note_repository.dart';
import 'cache_provider.dart';

/// Provides [NoteRepository] backed by the Hive 'notes' box.
final notesRepositoryProvider = Provider<NoteRepository>((ref) {
  final cache = ref.watch(cacheServiceProvider);
  return NoteRepository(cache.notesBox);
});

/// Incremented whenever notes are mutated; consumers watch this to re-read.
final notesRevisionProvider = StateProvider<int>((ref) => 0);

/// Current list of notes, sorted by updatedAt desc.
/// Re-evaluated whenever [notesRevisionProvider] bumps.
final notesProvider = Provider<List<Note>>((ref) {
  ref.watch(notesRevisionProvider);
  return ref.read(notesRepositoryProvider).list();
});
