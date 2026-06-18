import 'package:flutter/material.dart';

/// Kharis Church design-system colour tokens — v2.
/// CRITICAL: secondary (gold) = CTAs, active nav, progress.
///           primary (lavender) = brand, gradients, decorative.
abstract final class AppColors {
  // ── Brand ──────────────────────────────────────────────────────────────────

  /// Lavender purple — branding, gradients, secondary decorative use.
  static const Color primary = Color(0xFFD6BAFF);

  /// Text/icon on primary surfaces.
  static const Color onPrimary = Color(0xFF41107E);

  /// Stronger purple — containers, pills.
  static const Color primaryContainer = Color(0xFFBD92FF);

  /// Gold — PRIMARY CTAs, active nav, Live badges, progress bars.
  static const Color secondary = Color(0xFFE9C349);

  /// Text/icon on gold (secondary) surfaces.
  static const Color onSecondary = Color(0xFF3C2F00);

  /// Warm grey — tertiary accents.
  static const Color tertiary = Color(0xFFC8C6C5);

  // ── Surfaces (dark mode) ───────────────────────────────────────────────────

  /// App background — deepest layer.
  static const Color surfaceDark = Color(0xFF131313);

  /// Cards, bottom bar — +1px white 10% border.
  static const Color surfaceElevated = Color(0xFF1E1E1E);

  /// Inputs, secondary surfaces.
  static const Color surfaceSubtle = Color(0xFF2A2A2A);

  /// Container surfaces (bottom sheets, separators).
  static const Color surfaceContainer = Color(0xFF201F1F);

  /// Low-emphasis container (mini player, deep backgrounds).
  static const Color surfaceContainerLow = Color(0xFF1C1B1B);

  // ── Content ────────────────────────────────────────────────────────────────

  /// Primary text on dark surfaces.
  static const Color onSurface = Color(0xFFE5E2E1);

  /// Body / secondary text.
  static const Color onSurfaceVariant = Color(0xFFCCC3D3);

  /// Muted text, inactive icons.
  static const Color textMuted = Color(0xFF968E9D);

  // ── Outline / dividers ─────────────────────────────────────────────────────

  static const Color outline = Color(0xFF968E9D);
  static const Color outlineVariant = Color(0xFF4A4451);

  // ── Semantic states ────────────────────────────────────────────────────────

  static const Color error = Color(0xFFFFB4AB);
  static const Color errorContainer = Color(0xFF93000A);
  static const Color success = Color(0xFF22C55E);
}
