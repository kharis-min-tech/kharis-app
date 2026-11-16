import 'package:flutter/material.dart';

import '../../theme/kharis_theme.dart';
import 'k_icon.dart';

/// An image that fills its box and sits on surface2 while it loads or if it
/// fails. Decorative unless [semanticLabel] is set.
class KImageFill extends StatelessWidget {
  const KImageFill({super.key, this.image, this.semanticLabel});

  /// Null shows the surface2 placeholder.
  final ImageProvider? image;

  /// Alt text. Leave null when the title next to the image says it all.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.k.surface2,
      child: image == null
          ? const SizedBox.expand()
          : Image(
              image: image!,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              semanticLabel: semanticLabel,
              excludeFromSemantics: semanticLabel == null,
              errorBuilder: (_, _, _) => const SizedBox.expand(),
            ),
    );
  }
}

/// A square thumbnail with tile corners: artwork in a list row, the mini
/// player or a listening card.
class KThumbnail extends StatelessWidget {
  const KThumbnail({
    super.key,
    this.image,
    this.size = KSize.thumb,
    this.semanticLabel,
  });

  final ImageProvider? image;
  final double size;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.all(Radius.circular(KRadius.tile)),
      child: SizedBox.square(
        dimension: size,
        child: KImageFill(image: image, semanticLabel: semanticLabel),
      ),
    );
  }
}

/// A 40 square tile holding one icon, used as the leading item of a list row
/// or option card.
class KIconTile extends StatelessWidget {
  const KIconTile(this.icon, {super.key, this.emphasized = false});

  /// One of the [KIcons] paths.
  final String icon;

  /// Primary fill, for the selected option in a group.
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: emphasized ? k.primary : k.surface2,
        borderRadius: const BorderRadius.all(Radius.circular(KRadius.tile)),
      ),
      child: SizedBox.square(
        dimension: KSize.thumb,
        child: Center(
          child: KIcon(icon, color: emphasized ? k.onPrimary : k.text),
        ),
      ),
    );
  }
}
