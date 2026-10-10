import 'package:flutter/material.dart';

import 'package:kharis_app/core/theme/theme.dart';

/// Flat brand fills shown behind artwork while it loads, and in its place
/// when a message or playlist has none. Brand colours only (purple, deep
/// purple, the splash magenta), flat rather than gradients: the old ten
/// rainbow gradient pairs (emerald, cyan, sky blue...) said nothing about
/// Kharis. White glyphs on every fill clear 6.7:1.
const _kFills = <Color>[
  AppColors.primaryDeep,
  AppColors.magenta,
  AppColors.primary,
];

/// The fill for artwork slot [index]; cycles so neighbouring placeholders
/// in a list differ.
Color artworkFill(int index) => _kFills[index % _kFills.length];
