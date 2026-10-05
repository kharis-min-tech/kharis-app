import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/features/notes/data/note_timeline_key.dart';
import 'package:kharis_app/features/playlists/providers/playlist_providers.dart';
import 'package:kharis_app/shared/models/sermon.dart';
import 'package:kharis_app/shared/providers/auth_provider.dart';

/// The player's heart: files the message into the member's Favorites
/// (created on the first heart), a quick go-to list that persists, follows
/// the account and opens from More and the top of Playlists.
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
    final favoritesAsync = ref.watch(favoritesProvider);
    final favorites = favoritesAsync.valueOrNull;
    final isLiked =
        (favorites?.contains(key) ?? false) ||
        (favorites?.contains(sermon.id) ?? false);

    void notify(String message) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
    }

    final label = isLiked ? 'Remove from Favourites' : 'Add to Favourites';
    return Semantics(
      button: true,
      toggled: isLiked,
      label: label,
      excludeSemantics: true,
      child: Tooltip(
        message: label,
        excludeFromSemantics: true,
        child: GestureDetector(
          onTap: () {
            final repo = ref.read(playlistRepositoryProvider);
            if (!repo.hasUser) {
              ref.read(anonymousSignInProvider).ensure();
              notify('Still signing you in. Try again in a moment.');
              return;
            }
            // Until the first snapshot lands we cannot tell "no Favorites yet"
            // from "not loaded yet", and guessing the former would take the
            // create path over the member's existing favorites.
            if (!favoritesAsync.hasValue) {
              notify(
                'Your Favourites are still loading. Try again in a moment.',
              );
              return;
            }
            repo.setLiked(
              key,
              liked: !isLiked,
              favoritesExist: favorites != null,
              aliases: [if (sermon.id != key) sermon.id],
            );
          },
          behavior: HitTestBehavior.opaque,
          // 44 x 44 target; the heart stays top-right, level with the title.
          child: SizedBox(
            width: 44,
            height: 44,
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(
                  isLiked
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: context.kc.accentInk,
                  size: 24,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
