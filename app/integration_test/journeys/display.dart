import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kharis_app/features/calendar/presentation/screens/calendar_screen.dart';
import 'package:kharis_app/features/giving/presentation/screens/giving_screen.dart';
import 'package:kharis_app/features/home/presentation/screens/home_screen.dart';
import 'package:kharis_app/features/home/presentation/screens/reading_screen.dart';
import 'package:kharis_app/features/messages/presentation/screens/messages_screen.dart';
import 'package:kharis_app/features/settings/presentation/screens/settings_screen.dart';
import 'package:kharis_app/main.dart';
import 'package:kharis_app/shared/providers/theme_provider.dart';

import '../support/actions.dart';
import '../support/harness.dart';

/// Scrolls [screen]'s main vertical list from top to bottom and back, so
/// every section lays out at least once.
Future<void> _sweep(Journey j, Type screen, String name) async {
  final t = j.tester;
  await pumpUntilFound(t, find.byType(screen), reason: '$name on screen');
  await pumpFor(t, const Duration(seconds: 3));
  final scrollables = find.descendant(
    of: find.byType(screen),
    matching: find.byWidgetPredicate(
      (w) =>
          w is Scrollable &&
          axisDirectionToAxis(w.axisDirection) == Axis.vertical,
    ),
  );
  if (scrollables.evaluate().isEmpty) return;
  final main = scrollables.first;
  await j.shot('$name-top');
  for (var i = 0; i < 12; i++) {
    await t.drag(main, const Offset(0, -500), warnIfMissed: false);
    await pumpFor(t, const Duration(milliseconds: 350));
  }
  await j.shot('$name-bottom');
  await t.drag(main, const Offset(0, 20000), warnIfMissed: false);
  await pumpFor(t, const Duration(milliseconds: 600));
}

/// (k) Light / Dark render Home and Messages cleanly; at a large system
/// text size Home, Messages, Events, Giving and the Bible lay out without
/// any FlutterError (overflow included: the harness fails the journey on
/// every FlutterError it sees).
Future<void> displayJourney(Journey j) async {
  final t = j.tester;
  await j.launch();
  await pumpUntilFound(t, find.byType(HomeScreen));
  j.note('default theme: ${j.c.read(themeModeProvider)}');

  for (final (label, mode, brightness) in const [
    ('Light', ThemeMode.light, Brightness.light),
    ('Dark', ThemeMode.dark, Brightness.dark),
  ]) {
    await openMoreRow(t, label);
    j.check(
      await pumpUntil(t, () => j.c.read(themeModeProvider) == mode),
      'theme "$label" selected',
    );
    j.check(
      prefs.getString('settings_theme_mode') == mode.name,
      '"$label" saved on the device',
    );
    await tapNav(t, 'Home');
    j.check(
      Theme.of(t.element(find.byType(HomeScreen))).brightness == brightness,
      'Home renders $brightness',
    );
    await _sweep(j, HomeScreen, 'home-${mode.name}');
    await tapNav(t, 'Messages');
    j.check(
      Theme.of(t.element(find.byType(MessagesScreen))).brightness == brightness,
      'Messages renders $brightness',
    );
    await _sweep(j, MessagesScreen, 'messages-${mode.name}');
  }

  // ── Large text ───────────────────────────────────────────────────────────
  t.platformDispatcher.textScaleFactorTestValue = 1.6;
  try {
    await pumpFor(t, const Duration(seconds: 1));
    await tapNav(t, 'Home');
    final applied =
        MediaQuery.textScalerOf(t.element(find.byType(HomeScreen))).scale(10) /
        10;
    j.note(
      'system text scale 1.6 -> app applies ${applied.toStringAsFixed(2)} '
      '(clamped to kMaxTextScale $kMaxTextScale)',
    );
    j.check(
      (applied - kMaxTextScale).abs() < 0.01,
      'large system text reaches the app, clamped to $kMaxTextScale (got $applied)',
    );
    await _sweep(j, HomeScreen, 'large-home');
    await tapNav(t, 'Messages');
    await _sweep(j, MessagesScreen, 'large-messages');
    await tapNav(t, 'Events');
    await _sweep(j, CalendarScreen, 'large-events');
    await tapNav(t, 'Giving');
    await _sweep(j, GivingScreen, 'large-giving');
    await tapNav(t, 'More');
    await _sweep(j, SettingsScreen, 'large-more');
    await openMoreRow(t, 'Bible');
    await _sweep(j, ReadingScreen, 'large-bible');
  } finally {
    t.platformDispatcher.clearTextScaleFactorTestValue();
  }
}
