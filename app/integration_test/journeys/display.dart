import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kharis_app/features/bible/presentation/screens/bible_screen.dart';
import 'package:kharis_app/features/bible/presentation/screens/reading_screen.dart';
import 'package:kharis_app/features/calendar/presentation/screens/calendar_screen.dart';
import 'package:kharis_app/features/giving/presentation/screens/giving_screen.dart';
import 'package:kharis_app/features/home/presentation/screens/home_screen.dart';
import 'package:kharis_app/features/messages/presentation/screens/messages_screen.dart';
import 'package:kharis_app/features/settings/presentation/screens/settings_screen.dart';
import 'package:kharis_app/main.dart';
import 'package:kharis_app/shared/providers/text_size_provider.dart';
import 'package:kharis_app/shared/providers/theme_provider.dart';
import 'package:kharis_app/ui/components/components.dart';

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

/// Opens More's [row] and picks [option] in its choice sheet.
Future<void> _choose(Journey j, String row, String option) async {
  final t = j.tester;
  await openMoreRow(t, row);
  final sheet = find.byWidgetPredicate((w) => w is KSortSheet);
  await pumpUntilFound(t, sheet, reason: '$row choices');
  await tapVisible(t, find.descendant(of: sheet, matching: find.text(option)));
  await pumpUntil(t, () => sheet.evaluate().isEmpty);
  await pumpFor(t, const Duration(milliseconds: 600));
}

/// (k) More's Appearance: Light / Dark render Home and Messages cleanly. At
/// a large system text size with More's Text size on Large, Home, Messages,
/// Events, Give, More, the Bible tab and the reader lay out without any
/// FlutterError (overflow included: the harness fails the journey on every
/// FlutterError it sees).
Future<void> displayJourney(Journey j) async {
  final t = j.tester;
  await j.launch();
  await pumpUntilFound(t, find.byType(HomeScreen));
  j.note('default theme: ${j.c.read(themeModeProvider)}');

  for (final (label, mode, brightness) in const [
    ('Light', ThemeMode.light, Brightness.light),
    ('Dark', ThemeMode.dark, Brightness.dark),
  ]) {
    await _choose(j, 'Appearance', label);
    j.check(
      await pumpUntil(t, () => j.c.read(themeModeProvider) == mode),
      'theme "$label" selected',
    );
    j.check(
      prefs.getString('settings_theme_mode') == mode.name,
      '"$label" saved on the device',
    );
    j.check(
      find
          .descendant(
            of: find.byKey(const Key('more-row-appearance')),
            matching: find.text(label),
          )
          .evaluate()
          .isNotEmpty,
      'Appearance reads "$label"',
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
    await _choose(j, 'Text size', TextSizeChoice.large.label);
    j.check(
      j.c.read(textSizeProvider) == TextSizeChoice.large,
      'Text size "Large" selected',
    );
    await tapNav(t, 'Home');
    final applied =
        MediaQuery.textScalerOf(t.element(find.byType(HomeScreen))).scale(10) /
        10;
    final want = (1.6 * TextSizeChoice.large.factor).clamp(1.0, kMaxTextScale);
    j.note(
      'system text scale 1.6 x Large -> app applies '
      '${applied.toStringAsFixed(2)} (max $kMaxTextScale)',
    );
    j.check(
      (applied - want).abs() < 0.01,
      'large system text and Large reach the app: $want (got $applied)',
    );
    await _sweep(j, HomeScreen, 'large-home');
    await tapNav(t, 'Messages');
    await _sweep(j, MessagesScreen, 'large-messages');
    await openEvents(t);
    await _sweep(j, CalendarScreen, 'large-events');
    await goBack(t);
    await openGive(t);
    await _sweep(j, GivingScreen, 'large-giving');
    await goBack(t);
    await _sweep(j, SettingsScreen, 'large-more');
    await tapNav(t, 'Bible');
    await _sweep(j, BibleScreen, 'large-bible-tab');
    final daily = find.byKey(const Key('bible-daily-reading'));
    if (daily.evaluate().isEmpty) {
      j.note('DATA: no daily reading; the reader opens on John 3');
      final field = find.descendant(
        of: find.byKey(const Key('bible-landing-search')),
        matching: find.byType(EditableText),
      );
      await scrollUntilFound(
        t,
        field,
        scrollable: verticalScrollableIn(find.byType(BibleScreen)),
        step: const Offset(0, 300),
      );
      await t.tap(field, warnIfMissed: false);
      await t.enterText(field, 'John 3');
      await t.testTextInput.receiveAction(TextInputAction.search);
    } else {
      await tapVisible(t, daily);
    }
    await _sweep(j, ReadingScreen, 'large-bible');
  } finally {
    t.platformDispatcher.clearTextScaleFactorTestValue();
  }
}
