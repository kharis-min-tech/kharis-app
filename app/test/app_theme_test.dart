import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kharis_app/main.dart';
import 'package:kharis_app/shared/providers/onboarding_provider.dart';
import 'package:kharis_app/shared/providers/theme_provider.dart';
import 'package:kharis_app/theme/kharis_theme.dart';

Future<ProviderContainer> _container(Map<String, Object> saved) async {
  SharedPreferences.setMockInitialValues(saved);
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('the app theme is purely the new theme', () {
    for (final brightness in Brightness.values) {
      final dark = brightness == Brightness.dark;
      final theme = kharisAppTheme(brightness);
      final base = dark ? KharisTheme.dark() : KharisTheme.light();
      expect(theme.brightness, brightness);
      expect(theme.colorScheme, base.colorScheme);
      expect(theme.extension<KharisColors>(), base.extension<KharisColors>());
      expect(theme.extensions.keys, unorderedEquals(base.extensions.keys));
    }
  });

  test('appearance follows the system until the member chooses', () async {
    expect((await _container({})).read(themeModeProvider), ThemeMode.system);
    for (final (saved, mode) in [
      ('light', ThemeMode.light),
      ('dark', ThemeMode.dark),
      ('system', ThemeMode.system),
    ]) {
      final c = await _container({'settings_theme_mode': saved});
      expect(c.read(themeModeProvider), mode, reason: saved);
    }
  });

  testWidgets('the system bars follow the theme', (tester) async {
    for (final brightness in Brightness.values) {
      final dark = brightness == Brightness.dark;
      late Color bg;
      await tester.pumpWidget(
        MaterialApp(
          theme: kharisAppTheme(brightness),
          builder: (context, child) {
            bg = context.k.bg;
            return themedSystemUi(context, child!);
          },
          home: const SizedBox(),
        ),
      );
      // The theme animates from the previous brightness.
      await tester.pumpAndSettle();
      final style = tester
          .widget<AnnotatedRegion<SystemUiOverlayStyle>>(
            find.byType(AnnotatedRegion<SystemUiOverlayStyle>).first,
          )
          .value;
      final icons = dark ? Brightness.light : Brightness.dark;
      expect(style.statusBarIconBrightness, icons);
      expect(style.systemNavigationBarIconBrightness, icons);
      expect(style.statusBarBrightness, brightness);
      expect(style.systemNavigationBarColor, bg);
    }
  });
}
