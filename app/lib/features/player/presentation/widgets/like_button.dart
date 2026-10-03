import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/features/notes/data/note_timeline_key.dart';
import 'package:kharis_app/features/playlists/data/playlist_repository.dart';
import 'package:kharis_app/features/playlists/providers/playlist_providers.dart';
import 'package:kharis_app/shared/models/sermon.dart';
import 'package:kharis_app/shared/providers/auth_provider.dart';

/// The player's heart: files the message into the member's "Liked messages"
/// playlist (created on the first like), so a like persists, follows the
/// account and can be played back from Playlists.
///
/// A like is stored under the message's [NoteTimelineKey.canonical], so the
/// audio and video variants of one message share one heart (the player swaps
/// between them on the Audio | Video toggle). A like stored under the raw id
/// of the variant on screen still reads as liked, and unliking clears both.
class LikeButton extends ConsumerWidget {
  const LikeButton({super.key, required this.sermon});

  final Sermon sermon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = NoteTimelineKey.of(sermon).canonical;
    final playlists = ref.watch(playlistsProvider);
    Playlist? liked;
    for (final playlist in playlists.valueOrNull ?? const <Playlist>[]) {
      if (playlist.id == PlaylistRepository.likedPlaylistId) liked = playlist;
    }
    final isLiked =
        (liked?.contains(key) ?? false) ||
        (liked?.contains(sermon.id) ?? false);

    void notify(String message) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
    }

    return Semantics(
      button: true,
      toggled: isLiked,
      label: isLiked ? 'Remove from Liked messages' : 'Add to Liked messages',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () {
          final repo = ref.read(playlistRepositoryProvider);
          if (!repo.hasUser) {
            ref.read(anonymousSignInProvider).ensure();
            notify('Still signing you in. Try again in a moment.');
            return;
          }
          // Until the first snapshot lands we cannot tell "no Liked playlist
          // yet" from "not loaded yet", and guessing the former would take
          // the create path over the member's existing likes.
          if (!playlists.hasValue) {
            notify('Your playlists are still loading. Try again in a moment.');
            return;
          }
          repo.setLiked(
            key,
            liked: !isLiked,
            playlistExists: liked != null,
            aliases: [if (sermon.id != key) sermon.id],
          );
        },
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.only(top: 2, left: 6),
          child: Icon(
            isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            color: context.kc.accentInk,
            size: 24,
          ),
        ),
      ),
    );
  }
}
