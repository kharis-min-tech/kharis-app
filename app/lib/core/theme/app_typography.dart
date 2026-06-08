import 'package:flutter/material.dart';

/// Type scale sourced from kharis.org computed styles.
///
/// Maven Pro is the heading face; DM Sans is the body and UI face.
/// Font assets must be registered in pubspec.yaml under `flutter.fonts`
/// before these family strings resolve at runtime.
abstract final class AppTypography {
  // ── Headings (Maven Pro) ───────────────────────────────────────────────────

  /// 42 px · Maven Pro 700 · tracking −1.134
  /// Hero headings ("WELCOME TO KHARIS").
  static const TextStyle display = TextStyle(
    fontFamily: 'Maven Pro',
    fontSize: 42,
    fontWeight: FontWeight.w700,
    letterSpacing: -1.134,
    height: 1.1,
  );

  /// 32 px · Maven Pro 700 · tracking −0.648
  /// Large page-level titles — one step below display.
  static const TextStyle h1 = TextStyle(
    fontFamily: 'Maven Pro',
    fontSize: 32,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.648,
    height: 1.2,
  );

  /// 24 px · Maven Pro 700 · tracking −0.648
  /// Section subheads ("About Us", "Locations").
  static const TextStyle h2 = TextStyle(
    fontFamily: 'Maven Pro',
    fontSize: 24,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.648,
    height: 1.25,
  );

  /// 18 px · Maven Pro 600
  /// Card titles, sermon names, list section headers.
  static const TextStyle h3 = TextStyle(
    fontFamily: 'Maven Pro',
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 1.35,
  );

  // ── Body / UI (DM Sans) ────────────────────────────────────────────────────

  /// 17 px · DM Sans 400
  /// Default body copy and descriptions.
  static const TextStyle body = TextStyle(
    fontFamily: 'DM Sans',
    fontSize: 17,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  /// 14 px · DM Sans 400
  /// Metadata, timestamps, helper text.
  static const TextStyle caption = TextStyle(
    fontFamily: 'DM Sans',
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );

  /// 11 px · DM Sans 600 · uppercase tracking
  /// Labels, badges, category chips.
  static const TextStyle overline = TextStyle(
    fontFamily: 'DM Sans',
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.8,
    height: 1.4,
  );

  /// 12 px · DM Sans 700
  /// Bottom navigation labels and nav link text.
  static const TextStyle nav = TextStyle(
    fontFamily: 'DM Sans',
    fontSize: 12,
    fontWeight: FontWeight.w700,
    height: 1.0,
  );
}
