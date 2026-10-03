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

/// The member's own playlists (their categorisations), most recently touched
/// first. Never includes Favorites; see [favoritesProvider].
final playlistsProvider = StreamProvider<List<Playlist>>((ref) {
  return ref.watch(playlistRepositoryProvider).watchPlaylists();
});

/// The member's Favorites (the player's heart), live. Null until the first
/// heart creates it.
final favoritesProvider = StreamProvider<Playlist?>((ref) {
  return ref.watch(playlistRepositoryProvider).watchFavorites();
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

/// A playlist's messages, resolved id by id.
class PlaylistResolution {
  const PlaylistResolution({
    this.sermons = const [],
    this.ids = const [],
    this.pending = 0,
    this.missing = 0,
  });

  /// Resolved messages, in list order.
  final List<Sermon> sermons;

  /// The stored id each of [sermons] was resolved from (same order). It can
  /// differ from the sermon's own id (a `yt_` key resolving to its audio
  /// twin), and it is the id to remove.
  final List<String> ids;

  /// Ids not found yet that may still arrive (the archive is still loading).
  final int pending;

  /// Ids that are definitively gone from every source.
  final int missing;
}

/// Resolves [ids] through [sermonByIdProvider] (library, video feed,
/// recent-play snapshots and CMS docs), so a fresh install shows the list
/// before the archive finishes loading and only reports a message as gone
/// once it really is.
PlaylistResolution _resolve(Ref ref, Iterable<String> ids) {
  final sermons = <Sermon>[];
  final resolvedIds = <String>[];
  var pending = 0;
  var missing = 0;
  for (final id in ids) {
    final lookup = ref.watch(sermonByIdProvider(id));
    final sermon = lookup.valueOrNull;
    if (sermon != null) {
      sermons.add(sermon);
      resolvedIds.add(id);
    } else if (lookup.isLoading) {
      pending++;
    } else {
      missing++;
    }
  }
  return PlaylistResolution(
    sermons: sermons,
    ids: resolvedIds,
    pending: pending,
    missing: missing,
  );
}

/// A playlist's messages, in playlist order. See [_resolve].
final playlistResolutionProvider = Provider.autoDispose
    .family<PlaylistResolution, String>((ref, playlistId) {
      final playlist = ref.watch(playlistByIdProvider(playlistId));
      if (playlist == null) return const PlaylistResolution();
      return _resolve(ref, playlist.sermonIds);
    });

/// Favorites, newest favorited first. Favorites carry no per-message
/// timestamp; the stored order is favoriting order (the heart appends, and
/// re-favoriting after a removal appends again), so reversing it puts the
/// latest heart on top. See [_resolve].
final favoritesResolutionProvider = Provider.autoDispose<PlaylistResolution>((
  ref,
) {
  final favorites = ref.watch(favoritesProvider).valueOrNull;
  if (favorites == null) return const PlaylistResolution();
  return _resolve(ref, favorites.sermonIds.reversed);
});

/// The playlist's resolved messages, in playlist order. See
/// [playlistResolutionProvider] for the pending and missing counts.
final playlistSermonsProvider = Provider.autoDispose
    .family<List<Sermon>, String>(
      (ref, playlistId) =>
          ref.watch(playlistResolutionProvider(playlistId)).sermons,
    );
