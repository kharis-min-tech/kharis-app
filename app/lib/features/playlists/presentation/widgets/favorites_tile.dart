import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kharis_app/features/playlists/presentation/widgets/collection_labels.dart';
import 'package:kharis_app/features/playlists/providers/playlist_providers.dart';
import 'package:kharis_app/ui/components/components.dart';

/// The pinned Favourites row at the top of Collections: the quick go-to for
/// hearted messages. It sits in its own group with a heart, apart from the
/// collections below it, since Favourites is not a collection.
class FavoritesTile extends ConsumerWidget {
  const FavoritesTile({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count =
        ref.watch(favoritesProvider).valueOrNull?.sermonIds.length ?? 0;
    return KListGroup(
      children: [
        KListRow(
          title: 'Favourites',
          meta: count == 0
              ? 'Tap the heart in the player to save a message here'
              : messageCountLabel(count),
          leading: const KIconTile(KIcons.heart),
          showChevron: true,
          onTap: onTap,
        ),
      ],
    );
  }
}
