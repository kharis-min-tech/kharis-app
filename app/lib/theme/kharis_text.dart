import 'package:flutter/material.dart';

import 'kharis_tokens.g.dart';

/// Text styles for the Kharis type scale (Plus Jakarta Sans only).
///
/// Prefer `Theme.of(context).textTheme` (mapped below) or these named styles.
/// Never write `TextStyle(fontSize: ...)` outside lib/theme/.
///
/// These styles carry no colour, so text picks up the theme's colour. Add one
/// with `.copyWith(color: context.k.muted)` where the spec asks for it.
abstract final class KharisText {
  static FontWeight _weight(int w) => switch (w) {
        400 => FontWeight.w400,
        500 => FontWeight.w500,
        600 => FontWeight.w600,
        700 => FontWeight.w700,
        800 => FontWeight.w800,
        _ => FontWeight.w400,
      };

  /// Builds a TextStyle from a type token.
  static TextStyle style(KTypeToken t, {Color? color}) => TextStyle(
        fontFamily: KType.fontFamily,
        fontSize: t.size,
        height: t.height,
        fontWeight: _weight(t.weight),
        letterSpacing: t.letterSpacing,
        leadingDistribution: TextLeadingDistribution.even,
        color: color,
      );

  static final TextStyle display = style(KType.display);
  static final TextStyle screenTitle = style(KType.screenTitle);
  static final TextStyle pageTitle = style(KType.pageTitle);
  static final TextStyle headline = style(KType.headline);
  static final TextStyle section = style(KType.section);
  static final TextStyle title = style(KType.title);
  static final TextStyle reading = style(KType.reading);
  static final TextStyle body = style(KType.body);
  static final TextStyle button = style(KType.button);
  static final TextStyle link = style(KType.link);
  static final TextStyle itemTitle = style(KType.itemTitle);
  static final TextStyle meta = style(KType.meta);
  static final TextStyle caption = style(KType.caption);
  static final TextStyle small = style(KType.small);

  /// Eyebrow text. Uppercase the string yourself, or use `KOverline`.
  static final TextStyle overline = style(KType.overline);

  /// Material TextTheme mapping, so stock widgets also use the Kharis scale.
  static TextTheme textTheme(KharisColors c) => TextTheme(
        displayLarge: style(KType.display, color: c.text),
        displayMedium: style(KType.screenTitle, color: c.text),
        displaySmall: style(KType.pageTitle, color: c.text),
        headlineLarge: style(KType.pageTitle, color: c.text),
        headlineMedium: style(KType.headline, color: c.text),
        headlineSmall: style(KType.section, color: c.text),
        titleLarge: style(KType.title, color: c.text),
        titleMedium: style(KType.itemTitle, color: c.text),
        titleSmall: style(KType.link, color: c.primaryText),
        bodyLarge: style(KType.reading, color: c.text),
        bodyMedium: style(KType.body, color: c.text),
        bodySmall: style(KType.meta, color: c.muted),
        labelLarge: style(KType.button, color: c.text),
        labelMedium: style(KType.caption, color: c.muted),
        labelSmall: style(KType.small, color: c.muted),
      );
}
