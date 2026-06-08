import 'package:flutter/material.dart';

/// Brand and semantic colour tokens sourced from kharis.org computed styles.
/// Do not invent values — every hex here traces back to the DESIGN.md reference.
abstract final class AppColors {
  // ── Brand ──────────────────────────────────────────────────────────────────

  /// Primary CTA. Every button on the website. Never use for decorative marks.
  static const Color orange = Color(0xFFFD7F20);

  /// Identity colour. Logo and social icons only — not for buttons or fills.
  static const Color purple = Color(0xFF6B34FA);

  /// Feature icon colour (50 px icon-box components on kharis.org).
  static const Color magenta = Color(0xFF800654);

  // ── Surfaces (dark mode) ───────────────────────────────────────────────────

  /// App background — deepest layer. Matches `dark` token from DESIGN.md.
  static const Color surfaceDark = Color(0xFF0D0D0D);

  /// Cards, bottom sheets, and modal surfaces. Matches `elevated` token.
  static const Color surfaceElevated = Color(0xFF1A1A1A);

  /// Input fields and secondary surface containers. Matches `subtle` token.
  static const Color surfaceSubtle = Color(0xFF252525);

  // ── Text ───────────────────────────────────────────────────────────────────

  /// White — headings on dark surfaces and button labels.
  static const Color textPrimary = Color(0xFFFFFFFF);

  /// Near-charcoal — section headings on light surfaces.
  static const Color textHeading = Color(0xFF32363D);

  /// Mid-grey — body copy and description text.
  static const Color textBody = Color(0xFF7A7A7A);

  /// Light grey — secondary metadata, timestamps, muted labels.
  static const Color textMuted = Color(0xFF999999);

  // ── Semantic states ────────────────────────────────────────────────────────

  /// Positive / success feedback.
  static const Color success = Color(0xFF22C55E);

  /// Destructive / error state.
  static const Color error = Color(0xFFEF4444);

  /// Caution / warning state. Derived — not present on kharis.org.
  static const Color warning = Color(0xFFF59E0B);

  /// Informational state. Derived — not present on kharis.org.
  static const Color info = Color(0xFF3B82F6);
}
