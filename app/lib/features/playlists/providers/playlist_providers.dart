import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kharis_app/features/playlists/data/playlist_repository.dart';
import 'package:kharis_app/shared/models/sermon.dart';
import 'package:kharis_app/shared/providers/auth_provider.dart';
import 'package:kharis_app/shared/providers/branch_provider.dart';
import 'package:kharis_app/shared/providers/sermon_provider.dart';

/// Provides [PlaylistRepository] bound to the current account.
///
/// Rebuilt on sign-in / sign-out. Anonymous guests carry a uid too, so their
/// playlists persist exactly like a member's.
final playlistRepositoryProvider = Provider<PlaylistRepository>((ref) {
  return PlaylistRepository(
    ref.watch(firestoreProvider),
    uid: ref.watch(currentUserProvider).valueOrNull?.id,
  );
});

/// Every playlist the member owns, most recently touched first.
final playlistsProvider = StreamProvider<List<Playlist>>((ref) {
  return ref.watch(playlistRepositoryProvider).watchPlaylists();
});

/// One playlist by id, live. Null while loading, or once it has been deleted
/// — the detail screen renders a graceful "no longer exists" state for that.
final playlistByIdProvider = Provider.autoDispose.family<Playlist?, String>((
  ref,
  playlistId,
) {
  final all = ref.watch(playlistsProvider).valueOrNull ?? const <Playlist>[];
  for (final playlist in all) {
    if (playlist.id == playlistId) return playlist;
  }
  return null;
});

/// The playlist's messages resolved against the loaded sermon catalogue, in
/// playlist order. Dangling ids — messages that have since left the library —
/// are skipped rather than breaking the list; the detail screen reports how
/// many were skipped via [Playlist.sermonIds] length vs this list's length.
final playlistSermonsProvider = Provider.autoDispose
    .family<List<Sermon>, String>((ref, playlistId) {
      final playlist = ref.watch(playlistByIdProvider(playlistId));
      if (playlist == null) return const [];
      final catalogue =
          ref.watch(sermonsProvider).valueOrNull ?? const <Sermon>[];
      final byId = {for (final sermon in catalogue) sermon.id: sermon};
      return playlist.sermonIds
          .map((id) => byId[id])
          .whereType<Sermon>()
          .toList();
    });
