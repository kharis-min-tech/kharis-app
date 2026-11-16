import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kharis_app/features/playlists/data/playlist_repository.dart';
import 'package:kharis_app/features/playlists/presentation/widgets/collection_labels.dart';
import 'package:kharis_app/features/playlists/providers/playlist_providers.dart';
import 'package:kharis_app/ui/components/components.dart';

/// Square collection cover, reused by the library row, the Add to collection
/// sheet and the detail header: a mosaic of the collection's message artwork,
/// or a plain tile with the collection icon when none of its messages has
/// artwork.
class PlaylistArt extends ConsumerWidget {
  const PlaylistArt({
    super.key,
    required this.playlist,
    this.size = KSize.thumb,
  });

  final Playlist playlist;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox.square(
      dimension: size,
      child: PlaylistMosaic(
        urls: ref.watch(playlistArtworkProvider(playlist.id)),
      ),
    );
  }
}

/// Lays out up to four artwork [urls]: one fills the square, two split it
/// side by side, three put one tall tile beside two stacked, four make a
/// 2x2 grid. No URLs shows the collection icon on the placeholder fill.
class PlaylistMosaic extends StatelessWidget {
  const PlaylistMosaic({super.key, required this.urls});

  final List<String> urls;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    Widget tile(int i) => Expanded(child: _MosaicTile(urls[i]));
    final Widget content = switch (urls.length) {
      0 => ColoredBox(
        color: k.surface2,
        child: Center(child: KIcon(KIcons.collection, color: k.muted)),
      ),
      1 => _MosaicTile(urls[0]),
      2 => Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [tile(0), tile(1)],
      ),
      3 => Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          tile(0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [tile(1), tile(2)],
            ),
          ),
        ],
      ),
      _ => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [tile(0), tile(1)],
            ),
          ),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [tile(2), tile(3)],
            ),
          ),
        ],
      ),
    };
    return ClipRRect(
      borderRadius: const BorderRadius.all(Radius.circular(KRadius.tile)),
      child: content,
    );
  }
}

/// One image of the mosaic, decoded at the size it is drawn so a list of
/// covers never holds full-resolution artwork.
class _MosaicTile extends StatelessWidget {
  const _MosaicTile(this.url);

  final String url;

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : KSize.designWidth;
        return KImageFill(
          image: ResizeImage(
            CachedNetworkImageProvider(url),
            width: (width * dpr).round().clamp(64, 1080),
          ),
        );
      },
    );
  }
}

/// One of the member's collections in the library list: cover, name, and
/// "8 messages · 3 h 40 min".
class PlaylistCard extends ConsumerWidget {
  const PlaylistCard({super.key, required this.playlist, required this.onTap});

  final Playlist playlist;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return KListRow(
      title: playlist.name,
      meta: collectionMeta(
        playlist.sermonIds.length,
        ref.watch(playlistResolutionProvider(playlist.id)),
      ),
      leading: PlaylistArt(playlist: playlist),
      showChevron: true,
      onTap: onTap,
    );
  }
}
