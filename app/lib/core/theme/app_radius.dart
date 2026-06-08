import 'package:flutter/material.dart';

/// Corner-radius tokens sourced from kharis.org computed styles.
abstract final class AppRadius {
  /// 12 px — all CTA buttons on kharis.org.
  static const double button = 12;

  /// 15 px — feature cards (paired with the card box-shadow).
  static const double card = 15;

  /// 8 px — form input fields (derived; not explicit on kharis.org).
  static const double input = 8;

  /// 9999 px — fully-rounded pill shapes and social icon circles (50 %).
  static const double pill = 9999;

  // ── Composed BorderRadius ──────────────────────────────────────────────────

  /// BorderRadius for all CTA buttons.
  static BorderRadius get buttonBorder => BorderRadius.circular(button);

  /// BorderRadius for feature cards.
  static BorderRadius get cardBorder => BorderRadius.circular(card);

  /// BorderRadius for form input fields.
  static BorderRadius get inputBorder => BorderRadius.circular(input);
}
