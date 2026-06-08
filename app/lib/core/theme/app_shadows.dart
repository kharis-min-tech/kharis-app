import 'package:flutter/material.dart';

/// Shadow tokens. The card value is sourced directly from kharis.org computed styles.
/// All other levels are derived to fill the elevation scale.
abstract final class AppShadows {
  /// `0 0 30px rgba(0,0,0,0.18)` — feature cards on kharis.org.
  /// Alpha: 0.18 × 255 ≈ 46 = 0x2E.
  static const List<BoxShadow> card = [
    BoxShadow(
      color: Color(0x2E000000),
      blurRadius: 30,
      offset: Offset(0, 0),
    ),
  ];

  /// Subtle — small chips, inline badges, and floating action elements.
  /// Alpha: 0.12 × 255 ≈ 31 = 0x1F.
  static const List<BoxShadow> sm = [
    BoxShadow(
      color: Color(0x1F000000),
      blurRadius: 4,
      offset: Offset(0, 1),
    ),
  ];

  /// Standard — panels, drawers, popovers.
  /// Alpha: 0.20 × 255 ≈ 51 = 0x33.
  static const List<BoxShadow> md = [
    BoxShadow(
      color: Color(0x33000000),
      blurRadius: 12,
      offset: Offset(0, 4),
    ),
  ];

  /// High — modal dialogs and full-screen overlays.
  /// Alpha: 0.30 × 255 ≈ 77 = 0x4D.
  static const List<BoxShadow> lg = [
    BoxShadow(
      color: Color(0x4D000000),
      blurRadius: 24,
      offset: Offset(0, 8),
    ),
  ];
}
