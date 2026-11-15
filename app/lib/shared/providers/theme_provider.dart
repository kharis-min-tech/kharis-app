import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'onboarding_provider.dart';

const _kThemeModeKey = 'settings_theme_mode';

/// The member's theme choice, persisted across launches.
///
/// The app is all-light or all-dark: there is no per-screen mix. It follows
/// the system setting ([ThemeMode.system]) until the member picks Light or
/// Dark in Settings.
class ThemeModeController extends StateNotifier<ThemeMode> {
  ThemeModeController(this._ref) : super(_read(_ref));

  final Ref _ref;

  static ThemeMode _read(Ref ref) {
    final raw = ref.read(sharedPreferencesProvider).getString(_kThemeModeKey);
    return switch (raw) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  Future<void> set(ThemeMode mode) async {
    if (mode == state) return;
    state = mode;
    await _ref.read(sharedPreferencesProvider).setString(
          _kThemeModeKey,
          switch (mode) {
            ThemeMode.light => 'light',
            ThemeMode.dark => 'dark',
            ThemeMode.system => 'system',
          },
        );
  }
}

final themeModeProvider =
    StateNotifierProvider<ThemeModeController, ThemeMode>(
  ThemeModeController.new,
);
