import 'package:flutter/material.dart';

/// Kharis Church design-system colour tokens — v4 "Ember & Ash".
/// CRITICAL: secondary (brand orange) = CTAs, active nav, progress.
///           primary (muted heather) = brand, gradients, decorative.
abstract final class AppColors {
  // ── Brand ──────────────────────────────────────────────────────────────────

  /// Muted heather — branding, gradients, secondary decorative use.
  static const Color primary = Color(0xFF9A8FB8);

  /// Text/icon on primary surfaces.
  static const Color onPrimary = Color(0xFF17122B);

  /// Stronger heather — containers, pills.
  static const Color primaryContainer = Color(0xFF3A3350);

  /// Brand orange — PRIMARY CTAs, active nav, Live badges, progress bars.
  static const Color secondary = Color(0xFFFD7F20);

  /// Text/icon on orange (secondary) surfaces.
  static const Color onSecondary = Color(0xFF2B1300);

  /// Warm sand — tertiary accents.
  static const Color tertiary = Color(0xFFCBB9A2);

  // ── Surfaces (dark mode) ───────────────────────────────────────────────────

  /// App background — deepest layer.
  static const Color surfaceDark = Color(0xFF0E0E11);

  /// Deepest canvas behind the app shell.
  static const Color canvas = Color(0xFF060607);

  /// Cards, bottom bar — +1px white 10% border.
  static const Color surfaceElevated = Color(0xFF17171B);

  /// Inputs, secondary surfaces.
  static const Color surfaceSubtle = Color(0xFF1F2024);

  /// Container surfaces (bottom sheets, separators).
  static const Color surfaceContainer = Color(0xFF1A1A1E);

  /// Low-emphasis container (mini player, deep backgrounds).
  static const Color surfaceContainerLow = Color(0xFF121215);

  // ── Content ────────────────────────────────────────────────────────────────

  /// Headings (h1, section titles) — brightest text.
  static const Color heading = Color(0xFFF4F2EF);

  /// Primary / body text on dark surfaces.
  static const Color onSurface = Color(0xFFEAE7E3);

  /// Secondary / supporting text — neutral grey.
  static const Color onSurfaceVariant = Color(0xFFA9A6A1);

  /// Muted text, captions.
  static const Color textMuted = Color(0xFF7E7B76);

  /// Faint text, chevrons, footer links, inactive icons.
  static const Color textFaint = Color(0xFF6C6965);

  // ── Outline / dividers ─────────────────────────────────────────────────────

  static const Color outline = Color(0xFF948F89);
  static const Color outlineVariant = Color(0xFF46443F);

  // ── Semantic states ────────────────────────────────────────────────────────

  static const Color error = Color(0xFFFFB4AB);
  static const Color errorContainer = Color(0xFF93000A);
  static const Color success = Color(0xFF22C55E);

  /// Vivid ember — "Latest" badge, notification dot, live accents.
  static const Color accentPink = Color(0xFFFF8A3C);
}
