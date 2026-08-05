import 'package:flutter/material.dart';

import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/features/playlists/data/playlist_repository.dart';
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

/// Square gradient artwork for a playlist with a queue glyph, reused by the
/// library card and the detail header.
class PlaylistArt extends StatelessWidget {
  const PlaylistArt({super.key, required this.playlist, this.radius = 0});

  final Playlist playlist;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ArtworkImage(
          url: null,
          gradientIndex: playlistGradientIndex(playlist.id),
          radius: radius,
        ),
        const Center(
          child: Icon(
            Icons.queue_music_rounded,
            color: Colors.white70,
            size: 44,
          ),
        ),
      ],
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
            AspectRatio(
              aspectRatio: 1.12,
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
