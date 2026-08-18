import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'onboarding_provider.dart';

const _kThemeModeKey = 'settings_theme_mode';

/// The member's theme choice, persisted across launches.
///
/// The app is all-light or all-dark — there is no per-screen mix. Media
/// players are conventionally dark, so [ThemeMode.dark] is the default; a
/// member who prefers light can switch in Settings, and [ThemeMode.system]
/// follows the OS.
class ThemeModeController extends StateNotifier<ThemeMode> {
  ThemeModeController(this._ref) : super(_read(_ref));

  final Ref _ref;

  static ThemeMode _read(Ref ref) {
    final raw = ref.read(sharedPreferencesProvider).getString(_kThemeModeKey);
    return switch (raw) {
      'light' => ThemeMode.light,
      'system' => ThemeMode.system,
      _ => ThemeMode.dark,
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
