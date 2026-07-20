import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_radius.dart';
import 'app_typography.dart';

/// Returns the Kharis Church [ThemeData] — v2 design system.
///
/// Seed: secondary (gold) so Material3 generates a coherent palette from the
/// CTA colour.  Scaffold background is surfaceDark. Cards carry the 1px white
/// 10% border. ElevatedButtons are gold with dark text.
///
/// Usage:
/// ```dart
/// MaterialApp(
///   theme: kharisTheme(),
/// )
/// ```
ThemeData kharisTheme() {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: AppColors.secondary,
    brightness: Brightness.dark,
  ).copyWith(
    primary: AppColors.primary,
    onPrimary: AppColors.onPrimary,
    primaryContainer: AppColors.primaryContainer,
    secondary: AppColors.secondary,
    onSecondary: AppColors.onSecondary,
    tertiary: AppColors.tertiary,
    surface: AppColors.surfaceDark,
    onSurface: AppColors.onSurface,
    onSurfaceVariant: AppColors.onSurfaceVariant,
    surfaceContainerHighest: AppColors.surfaceElevated,
    surfaceContainer: AppColors.surfaceContainer,
    surfaceContainerLow: AppColors.surfaceContainerLow,
    error: AppColors.error,
    errorContainer: AppColors.errorContainer,
    onError: AppColors.onSurface,
    outline: AppColors.outline,
    outlineVariant: AppColors.outlineVariant,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: colorScheme,

    // ── Scaffold ─────────────────────────────────────────────────────────────
    scaffoldBackgroundColor: AppColors.surfaceDark,

    // ── Text ─────────────────────────────────────────────────────────────────
    textTheme: TextTheme(
      displayLarge: AppTypography.displayLg,
      headlineLarge: AppTypography.headlineLg,
      headlineMedium: AppTypography.headlineLgMobile,
      headlineSmall: AppTypography.titleMd,
      bodyLarge: AppTypography.bodyLg,
      bodySmall: AppTypography.bodySm,
      labelSmall: AppTypography.labelMd,
      labelMedium: AppTypography.labelMd,
    ),

    // ── Cards ─────────────────────────────────────────────────────────────────
    cardTheme: CardThemeData(
      color: AppColors.surfaceElevated,
      elevation: 0,
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.cardBorder,
        side: const BorderSide(color: Color(0x1AFFFFFF), width: 1),
      ),
    ),

    // ── Elevated button — gold CTA, 8px radius ──────────────────────────────
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.secondary,
        foregroundColor: AppColors.onSecondary,
        disabledBackgroundColor: Color(0x66FD7F20),
        disabledForegroundColor: AppColors.onSecondary,
        elevation: 0,
        shadowColor: Colors.transparent,
        textStyle: AppTypography.labelMd,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.buttonBorder,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 18),
      ),
    ),

    // ── App bar ───────────────────────────────────────────────────────────────
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      foregroundColor: AppColors.onSurface,
      titleTextStyle: AppTypography.titleMd,
    ),

    // ── Bottom navigation — gold active, textMuted inactive ──────────────────
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: AppColors.surfaceElevated,
      selectedItemColor: AppColors.secondary,
      unselectedItemColor: AppColors.textMuted,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
      selectedLabelStyle: AppTypography.labelMd,
      unselectedLabelStyle: AppTypography.labelMd,
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
        borderSide: const BorderSide(color: AppColors.secondary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: AppRadius.inputBorder,
        borderSide: const BorderSide(color: AppColors.error, width: 1),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
  );
}
