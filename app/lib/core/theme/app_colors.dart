import 'package:flutter/material.dart';

/// Kharis Church design-system colour tokens — v6 "Daylight".
/// LIGHT theme faithful to kharis.org (see DESIGN.md).
/// CRITICAL: secondary (orange #FD7F20) = CTAs, active nav, progress.
///           primary (purple #6B34FA) = identity, decorative use only.
abstract final class AppColors {
  // ── Brand ──────────────────────────────────────────────────────────────────

  /// Brand purple — identity marks, decorative use. Never for buttons.
  static const Color primary = Color(0xFF6B34FA);

  /// Text/icon on primary surfaces.
  static const Color onPrimary = Color(0xFFFFFFFF);

  /// Soft purple tint — containers, pills.
  static const Color primaryContainer = Color(0xFFEDE6FE);

  /// Orange — PRIMARY CTAs, active nav, Live badges, progress bars.
  static const Color secondary = Color(0xFFFD7F20);

  /// Text/icon on orange (secondary) surfaces.
  static const Color onSecondary = Color(0xFFFFFFFF);

  /// Magenta — feature-icon accent (icon boxes on kharis.org).
  static const Color tertiary = Color(0xFF800654);

  // ── Surfaces (light mode) ──────────────────────────────────────────────────

  /// App background — website page white. (Token name kept from the dark
  /// era; this is the scaffold/app background.)
  static const Color surfaceDark = Color(0xFFFFFFFF);

  /// Deepest canvas behind the app shell.
  static const Color canvas = Color(0xFFFFFFFF);

  /// Cards, bottom bar — pair with AppShadows.cardShadow.
  static const Color surfaceElevated = Color(0xFFFDFDFD);

  /// Inputs, secondary surfaces.
  static const Color surfaceSubtle = Color(0xFFF1F3F8);

  /// Container surfaces (bottom sheets, separators) — section-alt tint.
  static const Color surfaceContainer = Color(0xFFF9FAFE);

  /// Low-emphasis container (mini player, deep backgrounds) — section-alt.
  static const Color surfaceContainerLow = Color(0xFFF9FAFE);

  // ── Content ────────────────────────────────────────────────────────────────

  /// Headings (h1, section titles) — darkest text.
  static const Color heading = Color(0xFF32363D);

  /// Primary / body text on light surfaces.
  static const Color onSurface = Color(0xFF32363D);

  /// Secondary / supporting text — body grey.
  static const Color onSurfaceVariant = Color(0xFF7A7A7A);

  /// Muted text, captions.
  static const Color textMuted = Color(0xFF999999);

  /// Faint text, chevrons, footer links, inactive icons.
  static const Color textFaint = Color(0xFF999999);

  // ── Outline / dividers ─────────────────────────────────────────────────────

  static const Color outline = Color(0xFFC9C5CF);
  static const Color outlineVariant = Color(0xFFE7E4EC);

  // ── Semantic states ────────────────────────────────────────────────────────

  static const Color error = Color(0xFFBA1A1A);
  static const Color errorContainer = Color(0xFFFFDAD6);
  static const Color success = Color(0xFF15803D);

  /// Orange accent — "Latest" badge, notification dot, live accents.
  static const Color accentPink = Color(0xFFFD7F20);
}
