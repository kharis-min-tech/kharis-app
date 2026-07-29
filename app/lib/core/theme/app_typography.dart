import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Type scale — Kharis Church design system v3 (design-handoff).
///
/// Three families:
/// - **Display** — Bricolage Grotesque 700, ls −0.015em. Screen titles,
///   "Kharis" wordmark, big headings.
/// - **UI / body** — Hanken Grotesk 400–800. Labels, buttons, list rows, nav.
/// - **Serif accent** — Newsreader (often italic). Scripture, taglines,
///   devotional reading.
///
/// Existing v2 getter names are retained (re-pointed to the new families) so
/// every screen keeps compiling; use [display]/[ui]/[serif] for custom sizes.
abstract final class AppTypography {
  // ── Font builders ──────────────────────────────────────────────────────────

  /// Bricolage Grotesque display font (headings, wordmark).
  static TextStyle display({
    double size = 27,
    FontWeight weight = FontWeight.w700,
    double? height,
    Color? color,
  }) =>
      GoogleFonts.bricolageGrotesque(
        fontSize: size,
        fontWeight: weight,
        height: height,
        letterSpacing: size * -0.015,
        color: color,
      );

  /// Hanken Grotesk UI / body font.
  static TextStyle ui({
    double size = 15,
    FontWeight weight = FontWeight.w400,
    double? height,
    double? letterSpacing,
    Color? color,
  }) =>
      GoogleFonts.hankenGrotesk(
        fontSize: size,
        fontWeight: weight,
        height: height,
        letterSpacing: letterSpacing,
        color: color,
      );

  /// Newsreader serif accent (scripture, taglines).
  static TextStyle serif({
    double size = 18,
    FontWeight weight = FontWeight.w400,
    bool italic = false,
    double? height,
    Color? color,
  }) =>
      GoogleFonts.newsreader(
        fontSize: size,
        fontWeight: weight,
        fontStyle: italic ? FontStyle.italic : FontStyle.normal,
        height: height,
        color: color,
      );

  // ── Retained scale (re-pointed to new families) ────────────────────────────

  /// 48 px · Bricolage 700 · lh 56 — hero display.
  static TextStyle get displayLg =>
      display(size: 48, weight: FontWeight.w700, height: 56 / 48);

  /// 32 px · Bricolage 700 · lh 40 — screen title.
  static TextStyle get headlineLg =>
      display(size: 32, weight: FontWeight.w700, height: 40 / 32);

  /// 28 px · Bricolage 700 · lh 36 — mobile headline.
  static TextStyle get headlineLgMobile =>
      display(size: 28, weight: FontWeight.w700, height: 36 / 28);

  /// 20 px · Hanken 600 · lh 28 — card / list-row title.
  static TextStyle get titleMd =>
      ui(size: 20, weight: FontWeight.w600, height: 28 / 20);

  /// 16 px · Hanken 400 · lh 24 — body.
  static TextStyle get bodyLg => ui(size: 16, height: 24 / 16);

  /// 14 px · Hanken 400 · lh 20 — small body.
  static TextStyle get bodySm => ui(size: 14, height: 20 / 14);

  /// 12 px · Hanken 600 · lh 16 · ls 0.05em — label / eyebrow.
  static TextStyle get labelMd => ui(
        size: 12,
        weight: FontWeight.w600,
        height: 16 / 12,
        letterSpacing: 12 * 0.05,
      );
}
