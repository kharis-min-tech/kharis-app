import 'package:flutter/material.dart';

/// Kharis Church design-system colour tokens — v3 "Midnight & Copper".
/// Deep navy surfaces + copper accents: premium and warm, still cinematic.
/// CRITICAL: secondary (copper) = CTAs, active nav, progress.
///           primary (steel blue) = brand, gradients, decorative.
abstract final class AppColors {
  // ── Brand ──────────────────────────────────────────────────────────────────

  /// Steel blue — branding, gradients, secondary decorative use.
  static const Color primary = Color(0xFF8FA8CC);

  /// Text/icon on primary surfaces.
  static const Color onPrimary = Color(0xFF0E1B33);

  /// Stronger navy-blue — containers, pills.
  static const Color primaryContainer = Color(0xFF2E4368);

  /// Copper — PRIMARY CTAs, active nav, Live badges, progress bars.
  static const Color secondary = Color(0xFFC4794A);

  /// Text/icon on copper (secondary) surfaces.
  static const Color onSecondary = Color(0xFF2B1608);

  /// Warm sand — tertiary accents.
  static const Color tertiary = Color(0xFFC9BBA8);

  // ── Surfaces (dark mode) ───────────────────────────────────────────────────

  /// App background — deepest layer.
  static const Color surfaceDark = Color(0xFF0C1220);

  /// Deepest canvas behind the app shell.
  static const Color canvas = Color(0xFF060A12);

  /// Cards, bottom bar — +1px white 10% border.
  static const Color surfaceElevated = Color(0xFF131A2B);

  /// Inputs, secondary surfaces.
  static const Color surfaceSubtle = Color(0xFF1C2436);

  /// Container surfaces (bottom sheets, separators).
  static const Color surfaceContainer = Color(0xFF121A2C);

  /// Low-emphasis container (mini player, deep backgrounds).
  static const Color surfaceContainerLow = Color(0xFF0F1524);

  // ── Content ────────────────────────────────────────────────────────────────

  /// Headings (h1, section titles) — brightest text.
  static const Color heading = Color(0xFFF3F1EC);

  /// Primary / body text on dark surfaces.
  static const Color onSurface = Color(0xFFEAE8E4);

  /// Secondary / supporting text — cool grey-blue.
  static const Color onSurfaceVariant = Color(0xFF979CAB);

  /// Muted text, captions.
  static const Color textMuted = Color(0xFF818999);

  /// Faint text, chevrons, footer links, inactive icons.
  static const Color textFaint = Color(0xFF646D80);

  // ── Outline / dividers ─────────────────────────────────────────────────────

  static const Color outline = Color(0xFF8B93A5);
  static const Color outlineVariant = Color(0xFF3A4356);

  // ── Semantic states ────────────────────────────────────────────────────────

  static const Color error = Color(0xFFFFB4AB);
  static const Color errorContainer = Color(0xFF93000A);
  static const Color success = Color(0xFF22C55E);

  /// Copper ember — "Latest" badge, notification dot, live accents
  /// (replaces the old vivid pink pop).
  static const Color accentPink = Color(0xFFD98757);
}
