import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_radius.dart';
import 'app_typography.dart';

/// Returns the Kharis Church [ThemeData] — v3 design system (design-handoff).
///
/// **Light-first**: scaffold is [AppColors.lightBg], body text is
/// [AppColors.textPrimary]. Dark screens (Splash, Messages, Player) set their
/// own dark backgrounds and colours explicitly. Cards are white with an 18px
/// radius and a soft shadow; the primary CTA is gold with a 15px radius.
ThemeData kharisTheme() {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    brightness: Brightness.light,
  ).copyWith(
    primary: AppColors.primary,
    onPrimary: AppColors.onPrimary,
    primaryContainer: AppColors.primaryContainer,
    onPrimaryContainer: AppColors.onPrimary,
    secondary: AppColors.secondary,
    onSecondary: AppColors.onSecondary,
    tertiary: AppColors.tertiary,
    surface: AppColors.cardWhite,
    onSurface: AppColors.textPrimary,
    onSurfaceVariant: AppColors.textMutedLight,
    error: AppColors.danger,
    onError: Colors.white,
    outlineVariant: AppColors.dividerLight,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: AppColors.lightBg,

    // ── Text — Hanken body, dark ink on light ──────────────────────────────
    textTheme: TextTheme(
      displayLarge: AppTypography.displayLg.copyWith(color: AppColors.textPrimary),
      headlineLarge: AppTypography.headlineLg.copyWith(color: AppColors.textPrimary),
      headlineMedium:
          AppTypography.headlineLgMobile.copyWith(color: AppColors.textPrimary),
      headlineSmall: AppTypography.titleMd.copyWith(color: AppColors.textPrimary),
      titleMedium: AppTypography.titleMd.copyWith(color: AppColors.textPrimary),
      bodyLarge: AppTypography.bodyLg.copyWith(color: AppColors.textPrimary),
      bodyMedium: AppTypography.bodyLg.copyWith(color: AppColors.textPrimary),
      bodySmall: AppTypography.bodySm.copyWith(color: AppColors.textMutedLight),
      labelSmall: AppTypography.labelMd.copyWith(color: AppColors.textMutedLight),
      labelMedium: AppTypography.labelMd.copyWith(color: AppColors.textPrimary),
    ),

    // ── Cards — white, 18px, soft shadow ────────────────────────────────────
    cardTheme: CardThemeData(
      color: AppColors.cardWhite,
      elevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.cardBorder),
    ),

    // ── Elevated button — gold CTA, 15px radius, gold ink ──────────────────
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.secondary,
        foregroundColor: AppColors.onSecondary,
        disabledBackgroundColor: const Color(0x66F8B537),
        disabledForegroundColor: AppColors.onSecondary,
        elevation: 0,
        shadowColor: Colors.transparent,
        textStyle: AppTypography.ui(size: 16, weight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.buttonBorder),
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      ),
    ),

    // ── App bar — transparent, Bricolage title, ink foreground ─────────────
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      foregroundColor: AppColors.textPrimary,
      titleTextStyle: AppTypography.display(size: 20, weight: FontWeight.w700)
          .copyWith(color: AppColors.textPrimary),
    ),

    // ── Input — white fill, 15px, gold focus ────────────────────────────────
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.cardWhite,
      hintStyle: AppTypography.bodySm.copyWith(color: AppColors.textMutedLight),
      border: OutlineInputBorder(
        borderRadius: AppRadius.inputBorder,
        borderSide: const BorderSide(color: AppColors.dividerLight),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: AppRadius.inputBorder,
        borderSide: const BorderSide(color: AppColors.dividerLight),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: AppRadius.inputBorder,
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: AppRadius.inputBorder,
        borderSide: const BorderSide(color: AppColors.danger, width: 1),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
  );
}
