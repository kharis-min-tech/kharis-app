import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:kharis_app/theme/kharis_theme.dart';

/// Artwork tile: the network [url] drawn (cover) over the surface2
/// placeholder. If the image is missing or fails, the placeholder shows
/// through, so cards never flash empty. An optional [overlay] (play icon,
/// equalizer) paints centred above, with an optional [scrim].
///
/// Uses [CachedNetworkImage] for disk caching and decodes at the tile's display
/// size (via `memCacheWidth`) so list thumbnails never decode full-resolution
/// artwork — this keeps scrolling smooth and memory low.
class ArtworkImage extends StatelessWidget {
  const ArtworkImage({
    super.key,
    required this.url,
    required this.gradientIndex,
    this.radius = KRadius.card,
    this.overlay,
    this.scrim = false,
  });

  final String? url;

  /// The message's artwork colour index. Every placeholder is surface2 now,
  /// so it no longer picks a fill; kept for the callers that pass it.
  final int gradientIndex;
  final double radius;
  final Widget? overlay;
  final bool scrim;

  /// Decode-width bounds, in physical pixels.
  static const int _minCacheWidth = 64;
  static const int _maxCacheWidth = 1080;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final dpr = MediaQuery.of(context).devicePixelRatio;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(color: k.surface2),
          if (url != null && url!.isNotEmpty)
            LayoutBuilder(
              builder: (context, constraints) {
                final w = constraints.maxWidth.isFinite
                    ? constraints.maxWidth
                    : KSize.designWidth;
                final cacheW = (w * dpr).round().clamp(
                  _minCacheWidth,
                  _maxCacheWidth,
                );
                return CachedNetworkImage(
                  imageUrl: url!,
                  fit: BoxFit.cover,
                  memCacheWidth: cacheW,
                  fadeInDuration: KMotion.fast,
                  placeholder: (_, _) => const SizedBox.shrink(),
                  errorWidget: (_, _, _) => const SizedBox.shrink(),
                );
              },
            ),
          if (scrim) ColoredBox(color: k.scrim),
          if (overlay != null) Center(child: overlay),
        ],
      ),
    );
  }
}
