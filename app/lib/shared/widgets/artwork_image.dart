import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:kharis_app/core/utils/artwork_gradient.dart';

/// Artwork tile that always has an on-brand fill: a gradient base with the
/// network [url] drawn over it (cover). If the image is missing or fails, the
/// gradient shows through, so cards never flash empty. An optional [overlay]
/// (play icon, equalizer) paints centred above, with an optional dark [scrim].
///
/// Uses [CachedNetworkImage] for disk caching and decodes at the tile's display
/// size (via `memCacheWidth`) so list thumbnails never decode full-resolution
/// artwork — this keeps scrolling smooth and memory low.
class ArtworkImage extends StatelessWidget {
  const ArtworkImage({
    super.key,
    required this.url,
    required this.gradientIndex,
    this.radius = 12,
    this.overlay,
    this.scrim = false,
  });

  final String? url;
  final int gradientIndex;
  final double radius;
  final Widget? overlay;
  final bool scrim;

  @override
  Widget build(BuildContext context) {
    final colors = sermonGradient(gradientIndex);
    final dpr = MediaQuery.of(context).devicePixelRatio;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: colors,
              ),
            ),
          ),
          if (url != null && url!.isNotEmpty)
            LayoutBuilder(
              builder: (context, constraints) {
                final w =
                    constraints.maxWidth.isFinite ? constraints.maxWidth : 400.0;
                final cacheW = (w * dpr).round().clamp(64, 1080);
                return CachedNetworkImage(
                  imageUrl: url!,
                  fit: BoxFit.cover,
                  memCacheWidth: cacheW,
                  fadeInDuration: const Duration(milliseconds: 120),
                  placeholder: (_, _) => const SizedBox.shrink(),
                  errorWidget: (_, _, _) => const SizedBox.shrink(),
                );
              },
            ),
          if (scrim)
            const DecoratedBox(
              decoration: BoxDecoration(color: Color(0x33000000)),
            ),
          if (overlay != null) Center(child: overlay),
        ],
      ),
    );
  }
}
