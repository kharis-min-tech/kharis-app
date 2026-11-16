import 'package:flutter/widgets.dart';

import '../../theme/kharis_theme.dart';

/// True when the system text size is large enough that side-by-side rows
/// should stack (above 130%), so nothing clips as text grows to 200%.
bool kIsLargeText(BuildContext context) {
  final scaled = MediaQuery.textScalerOf(context).scale(KType.body.size);
  return scaled / KType.body.size > KRatio.largeTextScale;
}

/// A colour with no opacity, for borders and fills that must keep their
/// size while invisible.
Color kClear(Color color) => color.withValues(alpha: 0);
