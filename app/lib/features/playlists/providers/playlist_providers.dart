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

/// A playlist's messages, resolved id by id.
class PlaylistResolution {
  const PlaylistResolution({
    this.sermons = const [],
    this.pending = 0,
    this.missing = 0,
  });

  /// Resolved messages, in playlist order.
  final List<Sermon> sermons;

  /// Ids not found yet that may still arrive (the archive is still loading).
  final int pending;

  /// Ids that are definitively gone from every source.
  final int missing;
}

/// Resolves each playlist id through [sermonByIdProvider] (library, video
/// feed, recent-play snapshots and CMS docs), so a fresh install shows the
/// playlist before the archive finishes loading and only reports a message
/// as gone once it really is.
final playlistResolutionProvider = Provider.autoDispose
    .family<PlaylistResolution, String>((ref, playlistId) {
      final playlist = ref.watch(playlistByIdProvider(playlistId));
      if (playlist == null) return const PlaylistResolution();
      final sermons = <Sermon>[];
      var pending = 0;
      var missing = 0;
      for (final id in playlist.sermonIds) {
        final lookup = ref.watch(sermonByIdProvider(id));
        final sermon = lookup.valueOrNull;
        if (sermon != null) {
          sermons.add(sermon);
        } else if (lookup.isLoading) {
          pending++;
        } else {
          missing++;
        }
      }
      return PlaylistResolution(
        sermons: sermons,
        pending: pending,
        missing: missing,
      );
    });

/// The playlist's resolved messages, in playlist order. See
/// [playlistResolutionProvider] for the pending and missing counts.
final playlistSermonsProvider = Provider.autoDispose
    .family<List<Sermon>, String>(
      (ref, playlistId) =>
          ref.watch(playlistResolutionProvider(playlistId)).sermons,
    );
