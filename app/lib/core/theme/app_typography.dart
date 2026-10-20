import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Type scale — Kharis Church design system v3 (design-handoff).
///
/// Two families, matching the new Kharis website:
/// - **Display** — Plus Jakarta Sans, ls −0.02em. Screen titles, the
///   "Kharis" wordmark, big headings.
/// - **UI / body** — Plus Jakarta Sans 400–800. Labels, buttons, list rows,
///   nav.
/// And for reading Scripture:
/// - **Serif accent** — Newsreader (often italic). Scripture, taglines,
///   devotional reading.
///
/// Existing v2 getter names are retained (re-pointed to the new families) so
/// every screen keeps compiling; use [display]/[ui]/[serif] for custom sizes.
abstract final class AppTypography {
  // ── Font builders ──────────────────────────────────────────────────────────

  /// Plus Jakarta Sans display (headings, wordmark), tracked tight as on the
  /// website.
  static TextStyle display({
    double size = 27,
    FontWeight weight = FontWeight.w700,
    double? height,
    Color? color,
  }) => GoogleFonts.plusJakartaSans(
    fontSize: size,
    fontWeight: weight,
    height: height,
    letterSpacing: size * -0.02,
    color: color,
  );

  /// Plus Jakarta Sans UI / body font.
  static TextStyle ui({
    double size = 15,
    FontWeight weight = FontWeight.w400,
    double? height,
    double? letterSpacing,
    Color? color,
  }) => GoogleFonts.plusJakartaSans(
    fontSize: size,
    fontWeight: weight,
    height: height,
    letterSpacing: letterSpacing,
    color: color,
  );

  /// The website's eyebrow over a section heading ("TEACHINGS"): 11.5px,
  /// 800, letter-spaced 0.18em. Callers upper-case the text.
  static TextStyle eyebrow({Color? color}) => GoogleFonts.plusJakartaSans(
    fontSize: 11.5,
    fontWeight: FontWeight.w800,
    letterSpacing: 11.5 * 0.18,
    height: 1,
    color: color,
  );

  /// Newsreader serif accent (scripture, taglines).
  static TextStyle serif({
    double size = 18,
    FontWeight weight = FontWeight.w400,
    bool italic = false,
    double? height,
    Color? color,
  }) => GoogleFonts.newsreader(
    fontSize: size,
    fontWeight: weight,
    fontStyle: italic ? FontStyle.italic : FontStyle.normal,
    height: height,
    color: color,
  );

  // ── Retained scale (re-pointed to new families) ────────────────────────────

  /// 48 px · Jakarta 700 · lh 56 — hero display.
  static TextStyle get displayLg =>
      display(size: 48, weight: FontWeight.w700, height: 56 / 48);

  /// 32 px · Jakarta 700 · lh 40 — screen title.
  static TextStyle get headlineLg =>
      display(size: 32, weight: FontWeight.w700, height: 40 / 32);

  /// 28 px · Jakarta 700 · lh 36 — mobile headline.
  static TextStyle get headlineLgMobile =>
      display(size: 28, weight: FontWeight.w700, height: 36 / 28);

  /// 20 px · Jakarta 600 · lh 28 — card / list-row title.
  static TextStyle get titleMd =>
      ui(size: 20, weight: FontWeight.w600, height: 28 / 20);

  /// 16 px · Jakarta 400 · lh 24 — body.
  static TextStyle get bodyLg => ui(size: 16, height: 24 / 16);

  /// 14 px · Jakarta 400 · lh 20 — small body.
  static TextStyle get bodySm => ui(size: 14, height: 20 / 14);

  /// 12 px · Jakarta 600 · lh 16 · ls 0.05em — label / eyebrow.
  static TextStyle get labelMd => ui(
    size: 12,
    weight: FontWeight.w600,
    height: 16 / 12,
    letterSpacing: 12 * 0.05,
  );
}
