import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/notes/data/note_repository.dart';
import 'auth_provider.dart';
import 'branch_provider.dart';
import 'cache_provider.dart';

/// Hive-backed local note storage — offline capture and the legacy notes of
/// members upgrading from the local-only build.
final localNoteStoreProvider = Provider<LocalNoteStore>((ref) {
  return LocalNoteStore(ref.watch(cacheServiceProvider).notesBox);
});

/// Provides [NoteRepository] bound to the signed-in member.
///
/// Rebuilt on sign-in / sign-out so the repository never has to watch auth
/// itself; a null uid means "hold everything locally until we know who this
/// is", which also covers the frames before auth has resolved.
final notesRepositoryProvider = Provider<NoteRepository>((ref) {
  return NoteRepository(
    ref.watch(localNoteStoreProvider),
    uid: ref.watch(currentUserProvider).valueOrNull?.id,
    firestore: ref.watch(firestoreProvider),
  );
});

/// Every note the member owns, newest edit first. Subscribing also uploads
/// any notes still held locally.
final notesProvider = StreamProvider<List<Note>>((ref) {
  return ref.watch(notesRepositoryProvider).watchNotes();
});

/// Notes anchored to one sermon, in timeline order (a sermon-wide note with
/// no position sorts first). Derived from [notesProvider] so opening the
/// player costs no extra reads and works offline.
final sermonNotesProvider =
    Provider.autoDispose.family<List<Note>, String>((ref, sermonId) {
  final all = ref.watch(notesProvider).valueOrNull ?? const <Note>[];
  final scoped = all.where((n) => n.sermonId == sermonId).toList()
    ..sort((a, b) => (a.positionMs ?? -1).compareTo(b.positionMs ?? -1));
  return scoped;
});
