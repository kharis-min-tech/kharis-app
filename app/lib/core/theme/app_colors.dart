import 'package:flutter/material.dart';

/// Kharis Church design-system colour tokens — v5 "Royal Plum & Champagne".
/// CRITICAL: secondary (champagne gold) = CTAs, active nav, progress.
///           primary (soft lavender) = brand, gradients, decorative.
abstract final class AppColors {
  // ── Brand ──────────────────────────────────────────────────────────────────

  /// Soft lavender — branding, gradients, secondary decorative use.
  static const Color primary = Color(0xFFB9A6E8);

  /// Text/icon on primary surfaces.
  static const Color onPrimary = Color(0xFF1E1433);

  /// Stronger plum — containers, pills.
  static const Color primaryContainer = Color(0xFF4A3670);

  /// Champagne gold — PRIMARY CTAs, active nav, Live badges, progress bars.
  static const Color secondary = Color(0xFFD9B36C);

  /// Text/icon on champagne (secondary) surfaces.
  static const Color onSecondary = Color(0xFF2E2005);

  /// Rose quartz — tertiary accents.
  static const Color tertiary = Color(0xFFD8B8C6);

  // ── Surfaces (dark mode) ───────────────────────────────────────────────────

  /// App background — deepest layer.
  static const Color surfaceDark = Color(0xFF150C1A);

  /// Deepest canvas behind the app shell.
  static const Color canvas = Color(0xFF0D0710);

  /// Cards, bottom bar — +1px white 10% border.
  static const Color surfaceElevated = Color(0xFF201226);

  /// Inputs, secondary surfaces.
  static const Color surfaceSubtle = Color(0xFF2A1932);

  /// Container surfaces (bottom sheets, separators).
  static const Color surfaceContainer = Color(0xFF1C1022);

  /// Low-emphasis container (mini player, deep backgrounds).
  static const Color surfaceContainerLow = Color(0xFF180E1E);

  // ── Content ────────────────────────────────────────────────────────────────

  /// Headings (h1, section titles) — brightest text.
  static const Color heading = Color(0xFFF5F1F7);

  /// Primary / body text on dark surfaces.
  static const Color onSurface = Color(0xFFB0A5BA);

  /// Secondary / supporting text — plum-tinted grey.
  static const Color onSurfaceVariant = Color(0xFF9A8FA4);

  /// Muted text, captions.
  static const Color textMuted = Color(0xFF837990);

  /// Faint text, chevrons, footer links, inactive icons.
  static const Color textFaint = Color(0xFF6B6175);

  // ── Outline / dividers ─────────────────────────────────────────────────────

  static const Color outline = Color(0xFF94899E);
  static const Color outlineVariant = Color(0xFF4A3E55);

  // ── Semantic states ────────────────────────────────────────────────────────

  static const Color error = Color(0xFFFFB4AB);
  static const Color errorContainer = Color(0xFF93000A);
  static const Color success = Color(0xFF22C55E);

  /// Warm gold — "Latest" badge, notification dot, live accents.
  static const Color accentPink = Color(0xFFE8C77E);
}
