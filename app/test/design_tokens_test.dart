// Token tests for the redesign: the JSON, the generated Dart and the
// contrast the roles promise.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kharis_app/theme/kharis_theme.dart';
import 'package:kharis_app/ui/gallery/component_gallery_screen.dart';

/// Every colour role in the spec ("Colour roles").
const _specRoles = <String>[
  'bg',
  'surface',
  'surface2',
  'sheet',
  'text',
  'muted',
  'line',
  'border',
  'primary',
  'onPrimary',
  'primaryText',
  'primaryTint',
  'primaryPressed',
  'highlight',
  'onHighlight',
  'highlightText',
  'highlightTint',
  'highlightLight',
  'highlightDeep',
  'verseHighlight1',
  'verseHighlight2',
  'inverse',
  'onInverse',
  'ink',
  'onInk',
  'navBg',
  'navBorder',
  'navActive',
  'navActiveBg',
  'scrim',
  'error',
  'onError',
  'success',
];

Map<String, dynamic> _tokens() =>
    jsonDecode(File('tokens/kharis_tokens.json').readAsStringSync())
        as Map<String, dynamic>;

/// Follows `{group.name}` references to the final value.
Object? _resolve(Map<String, dynamic> tokens, Object? value) {
  final match = value is String
      ? RegExp(r'^\{([^}]+)\}$').firstMatch(value)
      : null;
  if (match == null) return value;
  Object? node = tokens;
  for (final part in match.group(1)!.split('.')) {
    node = (node! as Map<String, dynamic>)[part];
  }
  return _resolve(tokens, (node! as Map<String, dynamic>)[r'$value']);
}

/// `#rrggbb` or `#rrggbbaa` as the generator writes it: `Color(0xAARRGGBB)`.
String _dartColor(String hex) {
  final h = hex.substring(1).toUpperCase();
  return h.length == 6
      ? 'Color(0xFF$h)'
      : 'Color(0x${h.substring(6)}${h.substring(0, 6)})';
}

Map<String, String> _roles(Map<String, dynamic> tokens, String mode) {
  final group =
      (tokens['color'] as Map<String, dynamic>)[mode] as Map<String, dynamic>;
  return {
    for (final entry in group.entries)
      if (!entry.key.startsWith(r'$'))
        entry.key:
            _resolve(tokens, (entry.value as Map<String, dynamic>)[r'$value'])!
                as String,
  };
}

/// WCAG 2.1 relative luminance of an opaque colour.
double _luminance(Color c) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

/// WCAG 2.1 contrast ratio of [fg] drawn on [bg]. Translucent colours are
/// flattened first: [bg] over [under], then [fg] over that.
double _contrast(Color fg, Color bg, {Color? under}) {
  final base = under == null ? bg : Color.alphaBlend(bg, under);
  final top = Color.alphaBlend(fg, base);
  final a = _luminance(top);
  final b = _luminance(base);
  return (math.max(a, b) + 0.05) / (math.min(a, b) + 0.05);
}

void main() {
  final tokens = _tokens();
  final light = _roles(tokens, 'light');
  final dark = _roles(tokens, 'dark');
  final generated = File('lib/theme/kharis_tokens.g.dart').readAsStringSync();

  group('colour roles', () {
    test('every spec role is defined in light and in dark', () {
      expect(light.keys, containsAll(_specRoles));
      expect(dark.keys, containsAll(_specRoles));
    });

    test('light and dark define the same roles in the same order', () {
      expect(dark.keys.toList(), light.keys.toList());
    });

    test('the generated KharisColors carries every role in both modes', () {
      String block(String mode) {
        final start = generated.indexOf(
          'static const KharisColors $mode = KharisColors(',
        );
        expect(start, isNonNegative, reason: 'KharisColors.$mode is missing');
        return generated.substring(start, generated.indexOf(');', start));
      }

      for (final (mode, roles) in [('light', light), ('dark', dark)]) {
        final body = block(mode);
        for (final role in roles.entries) {
          expect(
            body,
            contains('    ${role.key}: ${_dartColor(role.value)},\n'),
            reason: 'KharisColors.$mode.${role.key} should be ${role.value}',
          );
        }
      }
    });

    test('the brand swaps: yellow leads in light, purple leads in dark', () {
      expect(KharisColors.light.primary, KBrand.yellow);
      expect(KharisColors.light.highlight, KBrand.purple);
      expect(KharisColors.dark.primary, KBrand.purple);
      expect(KharisColors.dark.highlight, KBrand.yellow);
    });

    test('the theme exposes the roles through the ThemeExtension', () {
      expect(
        KharisTheme.light().extension<KharisColors>(),
        same(KharisColors.light),
      );
      expect(
        KharisTheme.dark().extension<KharisColors>(),
        same(KharisColors.dark),
      );
      expect(
        KharisTheme.light().scaffoldBackgroundColor,
        KharisColors.light.bg,
      );
      expect(KharisTheme.dark().brightness, Brightness.dark);
    });
  });

  group('contrast (WCAG 2.1 AA, text 4.5:1)', () {
    for (final (mode, k) in [
      ('light', KharisColors.light),
      ('dark', KharisColors.dark),
    ]) {
      // Each "on" role against its fill, and each text role against the
      // surfaces the spec gives it. Tints and the nav are translucent, so
      // they are measured over the surface they sit on.
      final pairs = <String, double>{
        'text on bg': _contrast(k.text, k.bg),
        'text on surface': _contrast(k.text, k.surface),
        'text on surface2': _contrast(k.text, k.surface2),
        'text on sheet': _contrast(k.text, k.sheet),
        'muted on bg': _contrast(k.muted, k.bg),
        'muted on surface': _contrast(k.muted, k.surface),
        'muted on surface2': _contrast(k.muted, k.surface2),
        'muted on sheet': _contrast(k.muted, k.sheet),
        'onPrimary on primary': _contrast(k.onPrimary, k.primary),
        'onPrimary on primaryPressed': _contrast(k.onPrimary, k.primaryPressed),
        'primaryText on bg': _contrast(k.primaryText, k.bg),
        'primaryText on surface': _contrast(k.primaryText, k.surface),
        'primaryText on sheet': _contrast(k.primaryText, k.sheet),
        'primaryText on primaryTint over surface': _contrast(
          k.primaryText,
          k.primaryTint,
          under: k.surface,
        ),
        'text on primaryTint over surface': _contrast(
          k.text,
          k.primaryTint,
          under: k.surface,
        ),
        'onHighlight on highlight': _contrast(k.onHighlight, k.highlight),
        'highlightText on bg': _contrast(k.highlightText, k.bg),
        'highlightText on surface': _contrast(k.highlightText, k.surface),
        'highlightText on highlightTint over surface': _contrast(
          k.highlightText,
          k.highlightTint,
          under: k.surface,
        ),
        'onInverse on inverse': _contrast(k.onInverse, k.inverse),
        'onInk on ink': _contrast(k.onInk, k.ink),
        'navActive on the active nav pill': _contrast(
          k.navActive,
          k.navActiveBg,
          under: Color.alphaBlend(k.navBg, k.bg),
        ),
        'muted on the nav': _contrast(k.muted, k.navBg, under: k.bg),
        'onError on error': _contrast(k.onError, k.error),
        'error on surface': _contrast(k.error, k.surface),
        'success on surface': _contrast(k.success, k.surface),
      };

      for (final pair in pairs.entries) {
        test('$mode: ${pair.key}', () {
          expect(
            pair.value,
            greaterThanOrEqualTo(4.5),
            reason: '${pair.key} is ${pair.value.toStringAsFixed(2)}:1',
          );
        });
      }
    }

    test('the contrast maths matches the WCAG reference values', () {
      const black = Color(0xFF000000);
      const white = Color(0xFFFFFFFF);
      expect(_contrast(black, white), closeTo(21, 0.001));
      expect(_contrast(white, white), closeTo(1, 0.001));
      // #767676 on white is the well-known 4.54:1 boundary grey.
      expect(_contrast(const Color(0xFF767676), white), closeTo(4.54, 0.01));
    });
  });

  group('type, sizes and motion', () {
    test('all fifteen type tokens are defined, with no text under 11 '
        'except the overline', () {
      final type = (tokens['typography'] as Map<String, dynamic>).keys
          .where((key) => !key.startsWith(r'$'))
          .toList();
      expect(type, [
        'display',
        'screenTitle',
        'pageTitle',
        'headline',
        'section',
        'title',
        'reading',
        'body',
        'button',
        'link',
        'itemTitle',
        'meta',
        'caption',
        'small',
        'overline',
      ]);
      expect(KType.small.size, greaterThanOrEqualTo(11));
      expect(KType.overline.uppercase, isTrue);
    });

    test('the Material text theme uses the Kharis scale and family', () {
      final text = KharisTheme.light().textTheme;
      expect(text.displayMedium!.fontSize, KType.screenTitle.size);
      expect(text.bodyMedium!.fontSize, KType.body.size);
      expect(text.labelLarge!.fontWeight, FontWeight.w800);
      expect(text.bodyMedium!.fontFamily, 'PlusJakartaSans');
      expect(KharisText.overline.letterSpacing, closeTo(0.6, 0.0001));
    });

    test('touch, nav and Grace sizes match the spec', () {
      expect(KSize.touchMin, 44);
      expect(KSize.navHeight, 68);
      expect(KSize.navInsetBottom, 18);
      expect(KSize.graceSize, 56);
      expect(KSize.graceBobTravel, 5);
      expect(KMotion.graceBob, const Duration(milliseconds: 2800));
      expect(KRatio.graceHalo, 0.28);
    });

    test('shadows come as light and dark lists; dark cards are flat', () {
      expect(KShadow.cardLight, hasLength(2));
      expect(KShadow.cardDark, isEmpty);
      expect(KShadow.floatingLight, hasLength(1));
      expect(KShadow.floatingDark, hasLength(1));
    });
  });

  group('assets', () {
    test('the icon set is the 49 SVGs in assets/icons, all in KIcons', () {
      final files =
          Directory('assets/icons')
              .listSync()
              .map((entity) => entity.uri.pathSegments.last)
              .where((name) => name.endsWith('.svg'))
              .map((name) => 'assets/icons/$name')
              .toList()
            ..sort();
      expect(files, hasLength(49));
      expect(galleryIcons.values.toList()..sort(), files);
    });

    test('the bundled fonts and their licence are declared in pubspec', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(pubspec, contains('- family: PlusJakartaSans'));
      for (final weight in ['Regular', 'SemiBold', 'Bold', 'ExtraBold']) {
        final path = 'assets/fonts/PlusJakartaSans-$weight.ttf';
        expect(File(path).existsSync(), isTrue, reason: path);
        expect(pubspec, contains('- asset: $path'));
      }
      expect(File('assets/fonts/OFL.txt').existsSync(), isTrue);
    });

    test('the new theme never loads fonts at runtime', () {
      for (final file in Directory('lib/theme').listSync().whereType<File>()) {
        expect(
          file.readAsStringSync(),
          isNot(contains('google_fonts')),
          reason: file.path,
        );
      }
    });
  });
}
