import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Type scale — Kharis Church design system v2.
/// All styles use Plus Jakarta Sans via google_fonts.
abstract final class AppTypography {
  // ── 7-step scale ──────────────────────────────────────────────────────────

  /// 48 px · 800 weight · lh 56 · ls −0.02em
  static TextStyle get displayLg => GoogleFonts.plusJakartaSans(
        fontSize: 48,
        fontWeight: FontWeight.w800,
        height: 56 / 48,
        letterSpacing: 48 * -0.02,
      );

  /// 32 px · 700 weight · lh 40 · ls −0.01em
  static TextStyle get headlineLg => GoogleFonts.plusJakartaSans(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        height: 40 / 32,
        letterSpacing: 32 * -0.01,
      );

  /// 28 px · 700 weight · lh 36 — mobile headline
  static TextStyle get headlineLgMobile => GoogleFonts.plusJakartaSans(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        height: 36 / 28,
      );

  /// 20 px · 600 weight · lh 28
  static TextStyle get titleMd => GoogleFonts.plusJakartaSans(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        height: 28 / 20,
      );

  /// 16 px · 400 weight · lh 24
  static TextStyle get bodyLg => GoogleFonts.plusJakartaSans(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 24 / 16,
      );

  /// 14 px · 400 weight · lh 20
  static TextStyle get bodySm => GoogleFonts.plusJakartaSans(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 20 / 14,
      );

  /// 12 px · 600 weight · lh 16 · ls 0.05em
  static TextStyle get labelMd => GoogleFonts.plusJakartaSans(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        height: 16 / 12,
        letterSpacing: 12 * 0.05,
      );
}
