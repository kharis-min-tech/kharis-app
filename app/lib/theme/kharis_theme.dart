// Kharis App theme. The only place colours, fonts, sizes and shapes are defined.
//
// Setup (see the Developer Handoff doc, "Flutter implementation guide"):
//   MaterialApp(
//     theme: KharisTheme.light(),
//     darkTheme: KharisTheme.dark(),
//     themeMode: ThemeMode.system,
//     ...
//   );
//
// In widgets:
//   final k = context.k;                 // colour roles (KharisColors)
//   Text('Messages', style: KharisText.screenTitle);
//   Padding(padding: const EdgeInsets.symmetric(horizontal: KSpace.gutter), ...);
//
// Brand rule: light mode = yellow primary + purple highlight;
//             dark mode  = purple primary + yellow highlight.
// The swap lives in KharisColors.light / .dark, so widgets never check brightness
// to pick a brand colour.

import 'package:flutter/material.dart';

import 'kharis_text.dart';
import 'kharis_tokens.g.dart';

export 'kharis_text.dart';
export 'kharis_tokens.g.dart';

abstract final class KharisTheme {
  static ThemeData light() => _build(Brightness.light, KharisColors.light);
  static ThemeData dark() => _build(Brightness.dark, KharisColors.dark);

  static ThemeData _build(Brightness brightness, KharisColors c) {
    final isDark = brightness == Brightness.dark;

    final scheme = ColorScheme(
      brightness: brightness,
      primary: c.primary,
      onPrimary: c.onPrimary,
      primaryContainer: c.primaryTint,
      onPrimaryContainer: c.primaryText,
      secondary: c.highlight,
      onSecondary: c.onHighlight,
      secondaryContainer: c.highlightTint,
      onSecondaryContainer: c.highlightText,
      tertiary: c.highlight,
      onTertiary: c.onHighlight,
      error: c.error,
      onError: c.onError,
      surface: c.surface,
      onSurface: c.text,
      onSurfaceVariant: c.muted,
      outline: c.line,
      outlineVariant: c.border,
      inverseSurface: c.inverse,
      onInverseSurface: c.onInverse,
      inversePrimary: c.highlight,
      scrim: c.scrim,
      shadow: const Color(0xFF000000),
      surfaceTint: const Color(0x00000000),
    );

    const buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(KRadius.button)),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.bg,
      canvasColor: c.bg,
      fontFamily: KType.fontFamily,
      textTheme: KharisText.textTheme(c),
      extensions: <ThemeExtension<dynamic>>[c],
      iconTheme: IconThemeData(color: c.text, size: KSize.icon),
      dividerTheme: DividerThemeData(color: c.line, thickness: 1, space: 1),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: isDark ? c.primaryText : c.highlightText,
        selectionColor: c.primaryTint,
        selectionHandleColor: isDark ? c.primaryText : c.highlightText,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: c.primary,
          foregroundColor: c.onPrimary,
          disabledBackgroundColor: c.surface2,
          disabledForegroundColor: c.muted,
          minimumSize: const Size(KSize.touchMin, KSize.button),
          padding: const EdgeInsets.symmetric(horizontal: KSpace.x3),
          shape: buttonShape,
          textStyle: KharisText.button,
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.text,
          side: BorderSide(color: c.line, width: 1.5),
          minimumSize: const Size(KSize.touchMin, KSize.button),
          padding: const EdgeInsets.symmetric(horizontal: KSpace.x3),
          shape: buttonShape,
          textStyle: KharisText.button,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.primaryText,
          minimumSize: const Size(KSize.touchMin, KSize.touchMin),
          padding: const EdgeInsets.symmetric(horizontal: KSpace.md),
          shape: buttonShape,
          textStyle: KharisText.link,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.sheet,
        modalBackgroundColor: c.sheet,
        surfaceTintColor: const Color(0x00000000),
        modalBarrierColor: c.scrim,
        elevation: 0,
        modalElevation: 0,
        showDragHandle: true,
        dragHandleColor: c.line,
        dragHandleSize: const Size(KSize.sheetHandleWidth, KSize.sheetHandleHeight),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(KRadius.sheet)),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.primary,
        linearTrackColor: c.surface2,
      ),
    );
  }
}

/// Shortcuts for reading the Kharis theme from a BuildContext.
extension KharisContext on BuildContext {
  /// Colour roles for the current mode.
  KharisColors get k => Theme.of(this).extension<KharisColors>()!;

  /// True in dark mode. Only for choosing between light/dark shadow tokens;
  /// never use it to pick a brand colour.
  bool get isDarkTheme => Theme.of(this).brightness == Brightness.dark;
}
