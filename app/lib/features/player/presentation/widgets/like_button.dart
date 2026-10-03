import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/features/playlists/data/playlist_repository.dart';
import 'package:kharis_app/features/playlists/providers/playlist_providers.dart';
import 'package:kharis_app/shared/providers/auth_provider.dart';

/// The player's heart: files the message into the member's "Liked messages"
/// playlist (created on the first like), so a like persists, follows the
/// account and can be played back from Playlists.
class LikeButton extends ConsumerWidget {
  const LikeButton({super.key, required this.sermonId});

  final String sermonId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlists = ref.watch(playlistsProvider).valueOrNull;
    Playlist? liked;
    for (final playlist in playlists ?? const <Playlist>[]) {
      if (playlist.id == PlaylistRepository.likedPlaylistId) liked = playlist;
    }
    final isLiked = liked?.contains(sermonId) ?? false;

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
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Still signing you in. Try again in a moment.'),
                behavior: SnackBarBehavior.floating,
              ),
            );
            return;
          }
          repo.setLiked(
            sermonId,
            liked: !isLiked,
            playlistExists: liked != null,
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
