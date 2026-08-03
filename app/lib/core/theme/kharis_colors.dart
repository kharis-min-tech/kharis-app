import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Brightness-dependent colour tokens.
///
/// [AppColors] holds the raw palette and keeps brightness in the token names
/// (`lightBg`, `surfaceDark`, `cardWhite`, `darkMuted`). That was fine while
/// each screen was permanently light or permanently dark, but it cannot
/// express "this surface, in whichever theme is active".
///
/// This extension provides the semantic layer: read `context.kc.bg` instead of
/// picking `AppColors.lightBg` or `AppColors.surfaceDark` by hand, and the
/// screen follows the active theme. Brand colours that do not flip (purple,
/// error, success) stay on [AppColors].
@immutable
class KharisColors extends ThemeExtension<KharisColors> {
  const KharisColors({
    required this.bg,
    required this.surface,
    required this.surfaceAlt,
    required this.surfaceMuted,
    required this.onBg,
    required this.muted,
    required this.faint,
    required this.divider,
    required this.outline,
    required this.chipBg,
    required this.onChip,
    required this.accent,
    required this.onAccent,
    required this.accentInk,
    required this.scrim,
  });

  /// Screen background.
  final Color bg;

  /// Card / sheet surface sitting on [bg].
  final Color surface;

  /// Elevated or inset fill (search fields, secondary cards).
  final Color surfaceAlt;

  /// Inactive chips and muted fills.
  final Color surfaceMuted;

  /// Primary text and icons on [bg] / [surface].
  final Color onBg;

  /// Secondary text.
  final Color muted;

  /// Tertiary / disabled text.
  final Color faint;

  /// Hairline dividers.
  final Color divider;

  /// Borders on interactive elements.
  final Color outline;

  /// Tinted icon-tile background.
  final Color chipBg;

  /// Icon/text drawn on [chipBg].
  ///
  /// Brand purple works on the light lavender tile, but on the dark tile it
  /// lands around 2:1 — so dark mode lifts to a light lavender instead of
  /// keeping `AppColors.primary`.
  final Color onChip;

  /// Gold CTA fill. Dark mode uses a deeper amber — pure #F8B537 vibrates
  /// against dark surfaces.
  final Color accent;

  /// Ink on top of [accent].
  final Color onAccent;

  /// Gold used as *text or icon* on [bg]. Raw gold on a light background fails
  /// contrast and reads harsh, so light mode darkens it; dark mode can use the
  /// bright gold directly.
  final Color accentInk;

  /// Overlay behind modals and over imagery.
  final Color scrim;

  static const light = KharisColors(
    bg: AppColors.lightBg,
    surface: AppColors.cardWhite,
    surfaceAlt: Color(0xFFF2EEE8),
    surfaceMuted: AppColors.chipLight,
    onBg: AppColors.textPrimary,
    muted: AppColors.textMutedLight,
    faint: Color(0xFFA8A29B),
    divider: AppColors.dividerLight,
    outline: Color(0x1F171717),
    chipBg: AppColors.chipLight,
    onChip: AppColors.primary,
    accent: AppColors.secondary,
    onAccent: AppColors.onSecondary,
    accentInk: Color(0xFF8A5A06),
    scrim: Color(0x8C0B0A10),
  );

  static const dark = KharisColors(
    bg: AppColors.ink,
    surface: AppColors.darkSurface,
    surfaceAlt: AppColors.surfaceElevated,
    surfaceMuted: AppColors.darkSurface2,
    onBg: AppColors.heading,
    muted: AppColors.darkMuted,
    faint: AppColors.textFaint,
    divider: Color(0x14FFFFFF),
    outline: AppColors.outlineVariant,
    chipBg: AppColors.darkSurface2,
    onChip: Color(0xFFC6B4FF),
    accent: Color(0xFFE0A32B),
    onAccent: AppColors.onSecondary,
    accentInk: AppColors.secondary,
    scrim: Color(0xB30B0A10),
  );

  @override
  KharisColors copyWith({
    Color? bg,
    Color? surface,
    Color? surfaceAlt,
    Color? surfaceMuted,
    Color? onBg,
    Color? muted,
    Color? faint,
    Color? divider,
    Color? outline,
    Color? chipBg,
    Color? onChip,
    Color? accent,
    Color? onAccent,
    Color? accentInk,
    Color? scrim,
  }) {
    return KharisColors(
      bg: bg ?? this.bg,
      surface: surface ?? this.surface,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      onBg: onBg ?? this.onBg,
      muted: muted ?? this.muted,
      faint: faint ?? this.faint,
      divider: divider ?? this.divider,
      outline: outline ?? this.outline,
      chipBg: chipBg ?? this.chipBg,
      onChip: onChip ?? this.onChip,
      accent: accent ?? this.accent,
      onAccent: onAccent ?? this.onAccent,
      accentInk: accentInk ?? this.accentInk,
      scrim: scrim ?? this.scrim,
    );
  }

  @override
  KharisColors lerp(ThemeExtension<KharisColors>? other, double t) {
    if (other is! KharisColors) return this;
    return KharisColors(
      bg: Color.lerp(bg, other.bg, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      surfaceMuted: Color.lerp(surfaceMuted, other.surfaceMuted, t)!,
      onBg: Color.lerp(onBg, other.onBg, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      faint: Color.lerp(faint, other.faint, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      outline: Color.lerp(outline, other.outline, t)!,
      chipBg: Color.lerp(chipBg, other.chipBg, t)!,
      onChip: Color.lerp(onChip, other.onChip, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      accentInk: Color.lerp(accentInk, other.accentInk, t)!,
      scrim: Color.lerp(scrim, other.scrim, t)!,
    );
  }
}

/// `context.kc.surface` — the active brightness-dependent palette.
extension KharisColorsX on BuildContext {
  KharisColors get kc =>
      Theme.of(this).extension<KharisColors>() ?? KharisColors.light;
}
