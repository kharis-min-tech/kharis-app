import 'package:flutter/widgets.dart';

import '../../theme/kharis_theme.dart';

/// Brand images. The dove is an image, never an icon.
abstract final class KBrandAssets {
  static const String _dir = 'assets/brand';

  /// The Kharis dove as a white mask. Draw it with [KDoveMark] so it takes a
  /// theme colour.
  static const String doveWhite = '$_dir/kharis-dove-white.png';

  /// The Kharis dove in brand purple, for places that cannot tint an image.
  static const String dovePurple = '$_dir/kharis-dove-purple.png';
}

/// The Kharis dove in a theme colour: the logo in a header, and the mark on
/// the Grace button.
class KDoveMark extends StatelessWidget {
  const KDoveMark({
    super.key,
    required this.size,
    this.color,
    this.semanticLabel,
  });

  /// Width and height of the box the dove is fitted into.
  final double size;

  /// Defaults to the theme's text colour.
  final Color? color;

  /// Leave null when the dove is decorative.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      KBrandAssets.doveWhite,
      width: size,
      height: size,
      fit: BoxFit.contain,
      color: color ?? context.k.text,
      colorBlendMode: BlendMode.srcIn,
      filterQuality: FilterQuality.medium,
      semanticLabel: semanticLabel,
      excludeFromSemantics: semanticLabel == null,
    );
  }
}
