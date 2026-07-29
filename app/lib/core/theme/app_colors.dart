import 'package:flutter/material.dart';

/// Kharis Church design-system colour tokens — v3 (design-handoff palette).
///
/// The app is **light-first** (Home, Events, Giving, More, Role, Branch) with
/// **dark** screens for Splash, Messages, and the Player. Brand purple is for
/// branding / icons / gradients; gold is for CTAs, active chips, and progress.
///
/// Token names from v2 are preserved (admin CMS + existing screens depend on
/// them); `primary` and `secondary` are re-pointed to the new brand values.
abstract final class AppColors {
  // ── Brand ────────────────────────────────────────────────────────────────

  /// Purple — primary brand, icons, links, gradient start.
  static const Color primary = Color(0xFF5D3FD3);

  /// Deep purple — gradient end, link hover / pressed.
  static const Color primaryDeep = Color(0xFF451EBB);

  /// Text/icon on purple surfaces.
  static const Color onPrimary = Color(0xFFFFFFFF);

  /// Stronger purple container / pills.
  static const Color primaryContainer = Color(0xFF451EBB);

  /// Gold — PRIMARY CTAs, active chips, EQ bars, highlights, progress.
  static const Color secondary = Color(0xFFF8B537);

  /// Alias for [secondary] under the design-handoff name.
  static const Color gold = Color(0xFFF8B537);

  /// Text/icon on gold (secondary) surfaces.
  static const Color onSecondary = Color(0xFF1A1205);

  /// Alias for [onSecondary] — "gold ink".
  static const Color goldInk = Color(0xFF1A1205);

  /// Warm grey — tertiary accents.
  static const Color tertiary = Color(0xFFC8C6C5);

  /// Magenta — splash gradient accent.
  static const Color magenta = Color(0xFF7A1F47);

  // ── Light surfaces (Home / Events / Giving / More / Role / Branch) ─────────

  /// Light screen background.
  static const Color lightBg = Color(0xFFFAF7F2);

  /// White cards on light screens.
  static const Color cardWhite = Color(0xFFFFFFFF);

  /// Body text on light surfaces.
  static const Color textPrimary = Color(0xFF171717);

  /// Secondary text on light surfaces.
  static const Color textMutedLight = Color(0xFF8A8580);

  /// Purple-tint icon-tile background on light screens.
  static const Color chipLight = Color(0xFFF0ECFF);

  /// HQ branch card tint background.
  static const Color hqTint = Color(0xFFFFF6E5);

  /// HQ branch card stroke.
  static const Color hqStroke = Color(0xFFE09B1F);

  // ── Dark surfaces (Splash / Messages / Player) ─────────────────────────────

  /// Ink / black base for dark screens (player, messages).
  static const Color ink = Color(0xFF0B0A10);

  /// Mini-player / dark card surface.
  static const Color darkSurface = Color(0xFF241F30);

  /// Inactive dark chips / deep dark cards.
  static const Color darkSurface2 = Color(0xFF1C1826);

  /// Muted text on dark (strongest of the three).
  static const Color darkMuted = Color(0xFF9B93B5);

  /// Muted text on dark (mid).
  static const Color darkMuted2 = Color(0xFFCABCEA);

  /// Muted text on dark (faint lavender).
  static const Color darkMuted3 = Color(0xFFE6DDFF);

  // ── v2 dark surfaces (retained for admin CMS + carry-over screens) ─────────

  static const Color surfaceDark = Color(0xFF131313);
  static const Color canvas = Color(0xFF08070A);
  static const Color surfaceElevated = Color(0xFF1E1E1E);
  static const Color surfaceSubtle = Color(0xFF2A2A2A);
  static const Color surfaceContainer = Color(0xFF201F1F);
  static const Color surfaceContainerLow = Color(0xFF1C1B1B);

  // ── Content (v2 dark-surface text; retained) ───────────────────────────────

  static const Color heading = Color(0xFFF2EEF4);
  static const Color onSurface = Color(0xFFE9E6EA);
  static const Color onSurfaceVariant = Color(0xFF9A929E);
  static const Color textMuted = Color(0xFF8B838F);
  static const Color textFaint = Color(0xFF6E6A70);

  // ── Outline / dividers ─────────────────────────────────────────────────────

  static const Color outline = Color(0xFF968E9D);
  static const Color outlineVariant = Color(0xFF4A4451);

  /// Hairline divider on light surfaces.
  static const Color dividerLight = Color(0x14171717);

  // ── Semantic states ────────────────────────────────────────────────────────

  static const Color error = Color(0xFFFFB4AB);
  static const Color errorContainer = Color(0xFF93000A);
  static const Color success = Color(0xFF22C55E);

  /// Destructive / sign-out (design-handoff danger).
  static const Color danger = Color(0xFFE11D48);

  /// Vivid pink — "Latest" badge, notification dot, live accents.
  static const Color accentPink = Color(0xFFF531B3);
}
