import 'package:flutter/material.dart';

/// Corner-radius tokens — Kharis Church design system v2.
abstract final class AppRadius {
  /// 4 px — tight nudges.
  static const double sm = 4;

  /// 8 px — default radius (inputs, standard elements).
  static const double defaultRadius = 8;

  /// 12 px — medium surfaces.
  static const double md = 12;

  /// 16 px — cards and elevated surfaces.
  static const double lg = 16;

  /// 24 px — banners, large containers.
  static const double xl = 24;

  /// 8 px — standard CTA buttons (Kharis v2).
  static const double button = 8;

  /// 16 px — media/content cards.
  static const double card = 16;

  /// 8 px — form inputs.
  static const double input = 8;

  /// 9999 px — chips, tags, fully-rounded pills.
  static const double pill = 9999;

  // ── Composed BorderRadius ──────────────────────────────────────────────────

  /// BorderRadius for standard CTA buttons.
  static BorderRadius get buttonBorder => BorderRadius.circular(button);

  /// BorderRadius for cards.
  static BorderRadius get cardBorder => BorderRadius.circular(card);

  /// BorderRadius for form inputs.
  static BorderRadius get inputBorder => BorderRadius.circular(input);

  /// BorderRadius for chips and pill-shaped tags.
  static BorderRadius get pillBorder => BorderRadius.circular(pill);
}
