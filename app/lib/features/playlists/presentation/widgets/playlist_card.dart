import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/features/playlists/data/playlist_repository.dart';
import 'package:kharis_app/features/playlists/providers/playlist_providers.dart';
import 'package:kharis_app/shared/widgets/artwork_image.dart';
import 'package:kharis_app/shared/widgets/press_effect.dart';

/// Stable gradient pick for a playlist — derived from the id so the artwork
/// never shuffles between launches.
int playlistGradientIndex(String playlistId) {
  var sum = 0;
  for (final unit in playlistId.codeUnits) {
    sum = (sum + unit) % 997;
  }
  return sum % 10;
}

/// Square playlist cover, reused by the library card, the Add to playlist
/// sheet and the detail header: a mosaic of the playlist's message artwork,
/// or a flat tile with a queue glyph when none of its messages has artwork.
class PlaylistArt extends ConsumerWidget {
  const PlaylistArt({
    super.key,
    required this.playlist,
    this.radius = 0,
    this.glyphSize = 44,
  });

  final Playlist playlist;
  final double radius;
  final double glyphSize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PlaylistMosaic(
      urls: ref.watch(playlistArtworkProvider(playlist.id)),
      fallbackIndex: playlistGradientIndex(playlist.id),
      radius: radius,
      glyphSize: glyphSize,
    );
  }
}

/// Lays out up to four artwork [urls]: one fills the square, two split it
/// side by side, three put one tall tile beside two stacked, four make a
/// 2x2 grid. No URLs falls back to the flat [fallbackIndex] tile.
class PlaylistMosaic extends StatelessWidget {
  const PlaylistMosaic({
    super.key,
    required this.urls,
    required this.fallbackIndex,
    this.radius = 0,
    this.glyphSize = 44,
  });

  final List<String> urls;
  final int fallbackIndex;
  final double radius;
  final double glyphSize;

  @override
  Widget build(BuildContext context) {
    if (urls.isEmpty) {
      return ArtworkImage(
        url: null,
        gradientIndex: fallbackIndex,
        radius: radius,
        overlay: Icon(
          Icons.queue_music_rounded,
          color: Colors.white70,
          size: glyphSize,
        ),
      );
    }
    Widget tile(int i) => Expanded(
      child: ArtworkImage(
        url: urls[i],
        gradientIndex: fallbackIndex,
        radius: 0,
      ),
    );
    final Widget grid = switch (urls.length) {
      1 => ArtworkImage(url: urls[0], gradientIndex: fallbackIndex, radius: 0),
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
      borderRadius: BorderRadius.circular(radius),
      child: grid,
    );
  }
}

/// Library grid card for one playlist. Mirrors the Messages collection-card
/// spec: artwork on top, title + count below, gold play badge.
class PlaylistCard extends StatelessWidget {
  const PlaylistCard({super.key, required this.playlist, required this.onTap});

  final Playlist playlist;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final count = playlist.sermonIds.length;
    return PressEffect(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: context.kc.surface,
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // The artwork takes whatever the grid cell leaves after the
            // labels, so larger text sizes shrink the art instead of
            // overflowing the fixed-ratio cell.
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  PlaylistArt(playlist: playlist),
                  Positioned(
                    right: 10,
                    bottom: 10,
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: context.kc.accent,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.play_arrow_rounded,
                        color: context.kc.onAccent,
                        size: 22,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    playlist.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.display(
                      size: 15,
                      weight: FontWeight.w700,
                      color: context.kc.onBg,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    count == 1 ? '1 message' : '$count messages',
                    style: AppTypography.labelMd.copyWith(
                      fontSize: 11.5,
                      color: context.kc.muted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
