import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_radius.dart';
import 'app_typography.dart';

/// Returns the Kharis app [ThemeData]. Dark-mode first.
///
/// Usage:
/// ```dart
/// MaterialApp(
///   theme: kharisTheme(),
/// )
/// ```
ThemeData kharisTheme() {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: AppColors.accent,
    brightness: Brightness.dark,
  ).copyWith(
    primary: AppColors.accent,
    onPrimary: AppColors.textPrimary,
    surface: AppColors.surfaceDark,
    onSurface: AppColors.textPrimary,
    surfaceContainerHighest: AppColors.surfaceElevated,
    error: AppColors.error,
    onError: AppColors.textPrimary,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: colorScheme,

    // ── Scaffold ─────────────────────────────────────────────────────────────
    scaffoldBackgroundColor: AppColors.surfaceDark,

    // ── Text ─────────────────────────────────────────────────────────────────
    textTheme: const TextTheme(
      displayLarge: AppTypography.display,
      headlineLarge: AppTypography.h1,
      headlineMedium: AppTypography.h2,
      headlineSmall: AppTypography.h3,
      bodyLarge: AppTypography.body,
      bodySmall: AppTypography.caption,
      labelSmall: AppTypography.overline,
      labelMedium: AppTypography.nav,
    ),

    // ── Cards ─────────────────────────────────────────────────────────────────
    cardTheme: CardThemeData(
      color: AppColors.surfaceElevated,
      elevation: 0,
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.cardBorder,
      ),
    ),

    // ── Elevated button — magenta/pink accent ─────────────────────────────────
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        shadowColor: Colors.transparent,
        textStyle: const TextStyle(
          fontFamily: 'Maven Pro',
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.buttonBorder,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 18),
      ),
    ),

    // ── App bar ───────────────────────────────────────────────────────────────
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      foregroundColor: AppColors.textPrimary,
      titleTextStyle: AppTypography.h3,
    ),

    // ── Bottom navigation — white active, #8A8A8A inactive ────────────────────
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Colors.transparent,
      selectedItemColor: Colors.white,
      unselectedItemColor: Color(0xFF8A8A8A),
      type: BottomNavigationBarType.fixed,
      elevation: 0,
      selectedLabelStyle: AppTypography.nav,
      unselectedLabelStyle: AppTypography.nav,
    ),

    // ── Input decoration ──────────────────────────────────────────────────────
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surfaceSubtle,
      border: OutlineInputBorder(
        borderRadius: AppRadius.inputBorder,
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: AppRadius.inputBorder,
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: AppRadius.inputBorder,
        borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: AppRadius.inputBorder,
        borderSide: const BorderSide(color: AppColors.error, width: 1),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
  );
}
