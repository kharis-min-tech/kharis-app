import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/notes/data/note_repository.dart';
import '../../features/notes/data/note_timeline_key.dart';
import '../models/sermon.dart';
import 'auth_provider.dart';
import 'branch_provider.dart';
import 'cache_provider.dart';
import 'sermon_provider.dart';

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

/// Notes anchored to one message, in timeline order (a sermon-wide note with
/// no position sorts first). Derived from [notesProvider] so opening the
/// player costs no extra reads and works offline.
///
/// Keyed by [NoteTimelineKey], not the raw sermon id: the audio and video
/// variants of the same message carry different ids, and this is what folds
/// them into one shared timeline.
///
/// [NoteTimelineKey.matches] covers the aliases derivable from the variant on
/// screen (canonical `yt_` key, raw id, bare videoId) — but a legacy note may
/// sit under an id the variant CANNOT derive: the numeric API id of a message
/// now opened via its `yt_`/feed variant. That link only exists in the sermon
/// catalogue, so any loaded sermon sharing this key's canonical contributes
/// its own raw id as an accepted alias. Offline or while the catalogue loads
/// this degrades to key-only matching, never breaking the direct cases.
final sermonNotesProvider =
    Provider.autoDispose.family<List<Note>, NoteTimelineKey>((ref, key) {
  final all = ref.watch(notesProvider).valueOrNull ?? const <Note>[];
  final catalogue = ref.watch(sermonsProvider).valueOrNull ?? const <Sermon>[];
  final aliases = <String>{
    for (final sermon in catalogue)
      if (NoteTimelineKey.of(sermon).canonical == key.canonical) sermon.id,
  };
  final scoped = all
      .where((n) => key.matches(n.sermonId) || aliases.contains(n.sermonId))
      .toList()
    ..sort((a, b) => (a.positionMs ?? -1).compareTo(b.positionMs ?? -1));
  return scoped;
});
