import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_radius.dart';
import 'app_typography.dart';
import 'kharis_colors.dart';

/// Returns the Kharis Church [ThemeData] — v3 design system (design-handoff).
///
/// The app ships a full light theme and a full dark theme; the member chooses
/// which in Settings. Screens must read brightness-dependent colours from
/// `context.kc` ([KharisColors]) rather than picking `AppColors.lightBg` or
/// `AppColors.surfaceDark` directly, so a single toggle moves the whole app —
/// including the bottom navigation bar.
///
/// Brand purple, error and success are the same in both themes. Gold is not:
/// dark mode uses a deeper amber ([KharisColors.accent]) because pure #F8B537
/// vibrates against dark surfaces, and gold-as-text uses
/// [KharisColors.accentInk], which darkens on light backgrounds where raw gold
/// fails contrast.
ThemeData kharisTheme({Brightness brightness = Brightness.light}) {
  final isDark = brightness == Brightness.dark;
  final kc = isDark ? KharisColors.dark : KharisColors.light;

  final colorScheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    brightness: brightness,
  ).copyWith(
    primary: AppColors.primary,
    onPrimary: AppColors.onPrimary,
    primaryContainer: AppColors.primaryContainer,
    onPrimaryContainer: AppColors.onPrimary,
    secondary: kc.accent,
    onSecondary: kc.onAccent,
    tertiary: AppColors.tertiary,
    surface: kc.surface,
    onSurface: kc.onBg,
    onSurfaceVariant: kc.muted,
    error: AppColors.danger,
    onError: Colors.white,
    outlineVariant: kc.divider,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: kc.bg,
    extensions: <ThemeExtension<dynamic>>[kc],

    // ── Text — Hanken body, ink that follows the active brightness ──────────
    textTheme: TextTheme(
      displayLarge: AppTypography.displayLg.copyWith(color: kc.onBg),
      headlineLarge: AppTypography.headlineLg.copyWith(color: kc.onBg),
      headlineMedium: AppTypography.headlineLgMobile.copyWith(color: kc.onBg),
      headlineSmall: AppTypography.titleMd.copyWith(color: kc.onBg),
      titleMedium: AppTypography.titleMd.copyWith(color: kc.onBg),
      bodyLarge: AppTypography.bodyLg.copyWith(color: kc.onBg),
      bodyMedium: AppTypography.bodyLg.copyWith(color: kc.onBg),
      bodySmall: AppTypography.bodySm.copyWith(color: kc.muted),
      labelSmall: AppTypography.labelMd.copyWith(color: kc.muted),
      labelMedium: AppTypography.labelMd.copyWith(color: kc.onBg),
    ),

    // ── Cards — surface, 18px, no tint ──────────────────────────────────────
    cardTheme: CardThemeData(
      color: kc.surface,
      elevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.cardBorder),
    ),

    // ── Bottom navigation — follows the theme so it never looks bolted on ───
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: kc.surface,
      selectedItemColor: kc.accentInk,
      unselectedItemColor: kc.muted,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: kc.surface,
      indicatorColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
    ),

    dividerTheme: DividerThemeData(color: kc.divider, thickness: 1, space: 1),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: kc.surface,
      surfaceTintColor: Colors.transparent,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: kc.surface,
      surfaceTintColor: Colors.transparent,
    ),

    // Toasts stay a fixed dark plate in BOTH themes, the way Material's
    // inverse-surface snackbar does. Flipping them with the theme would put a
    // gold action on a near-white plate, which is the exact low-contrast
    // pairing the design review called out. The action therefore always uses
    // the bright gold, which only reads correctly on this dark plate.
    snackBarTheme: SnackBarThemeData(
      backgroundColor: KharisColors.dark.surface,
      contentTextStyle:
          AppTypography.bodySm.copyWith(color: KharisColors.dark.onBg),
      actionTextColor: AppColors.secondary,
      behavior: SnackBarBehavior.floating,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.inputBorder),
    ),

    // ── Elevated button — gold CTA, 15px radius, gold ink ──────────────────
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: kc.accent,
        foregroundColor: kc.onAccent,
        disabledBackgroundColor: kc.accent.withValues(alpha: 0.4),
        disabledForegroundColor: kc.onAccent,
        elevation: 0,
        shadowColor: Colors.transparent,
        textStyle: AppTypography.ui(size: 16, weight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.buttonBorder),
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      ),
    ),

    // ── App bar — transparent, Bricolage title ─────────────────────────────
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      foregroundColor: kc.onBg,
      titleTextStyle: AppTypography.display(size: 20, weight: FontWeight.w700)
          .copyWith(color: kc.onBg),
    ),

    // ── Input — surface fill, 15px, purple focus ────────────────────────────
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: isDark ? kc.surfaceAlt : kc.surface,
      hintStyle: AppTypography.bodySm.copyWith(color: kc.muted),
      border: OutlineInputBorder(
        borderRadius: AppRadius.inputBorder,
        borderSide: BorderSide(color: kc.divider),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: AppRadius.inputBorder,
        borderSide: BorderSide(color: kc.divider),
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
