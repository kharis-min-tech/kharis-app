import 'package:flutter/material.dart';

import '../../theme/kharis_theme.dart';
import 'k_badge.dart';
import 'k_thumbnail.dart';

/// Image shapes: artwork is square, video is 16:9, Shorts are 9:16.
enum KMediaAspect {
  square(1),
  video(16 / 9),
  short(9 / 16);

  const KMediaAspect(this.ratio);

  /// Width divided by height.
  final double ratio;
}

/// An image tile with a title and a meta line below it, and an optional
/// duration badge in the bottom-right corner of the image. Read as one item.
class KMediaTile extends StatelessWidget {
  const KMediaTile({
    super.key,
    required this.title,
    this.meta,
    this.image,
    this.duration,
    this.aspect = KMediaAspect.square,
    this.onTap,
  });

  final String title;
  final String? meta;

  /// Null shows the surface2 placeholder.
  final ImageProvider? image;

  /// For example "52 min".
  final String? duration;
  final KMediaAspect aspect;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    const radius = BorderRadius.all(Radius.circular(KRadius.tile));

    return MergeSemantics(
      child: Semantics(
        button: onTap != null,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            borderRadius: radius,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                AspectRatio(
                  aspectRatio: aspect.ratio,
                  child: ClipRRect(
                    borderRadius: radius,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        KImageFill(image: image),
                        if (duration != null)
                          PositionedDirectional(
                            end: KSpace.sm,
                            bottom: KSpace.sm,
                            child: KBadge(duration!),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: KSpace.md),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: KharisText.itemTitle.copyWith(color: k.text),
                ),
                if (meta != null)
                  Text(
                    meta!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: KharisText.caption.copyWith(color: k.muted),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
