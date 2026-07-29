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

  /// 15 px — standard CTA buttons (design-handoff).
  static const double button = 15;

  /// 18 px — media/content cards (design-handoff).
  static const double card = 18;

  /// 15 px — form inputs / search.
  static const double input = 15;

  /// 9999 px — chips, tags, fully-rounded pills.
  static const double pill = 9999;

  /// 13 px — icon tiles (`ib`), mini-player.
  static const double tile = 13;

  // ── Composed BorderRadius ──────────────────────────────────────────────────

  /// BorderRadius for standard CTA buttons.
  static BorderRadius get buttonBorder => BorderRadius.circular(button);

  /// BorderRadius for cards.
  static BorderRadius get cardBorder => BorderRadius.circular(card);

  /// BorderRadius for form inputs.
  static BorderRadius get inputBorder => BorderRadius.circular(input);

  /// BorderRadius for icon tiles / mini-player.
  static BorderRadius get tileBorder => BorderRadius.circular(tile);

  /// BorderRadius for chips and pill-shaped tags.
  static BorderRadius get pillBorder => BorderRadius.circular(pill);
}
