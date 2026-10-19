// App actions several journeys share: branch picker, More rows, the
// Messages browse state and the player.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kharis_app/features/onboarding/presentation/screens/branch_selection_screen.dart';
import 'package:kharis_app/features/onboarding/presentation/widgets/branch_tile.dart';
import 'package:kharis_app/features/player/presentation/screens/media_player_screen.dart';
import 'package:kharis_app/features/player/presentation/widgets/media_mode_toggle.dart';
import 'package:kharis_app/features/player/presentation/widgets/seek_bar.dart';
import 'package:kharis_app/features/settings/presentation/screens/settings_screen.dart';
import 'package:kharis_app/shared/providers/sermon_provider.dart';

import 'harness.dart';
import 'live_data.dart';

// ── Branch picker ────────────────────────────────────────────────────────────

/// Searches the branch picker for [b] and taps its tile; returns the names
/// the search left on screen.
Future<List<String>> chooseBranchInPicker(Journey j, StudioBranch b) async {
  final t = j.tester;
  final screen = find.byType(BranchSelectionScreen);
  await t.enterText(
    find.descendant(of: screen, matching: find.byType(TextField)),
    b.name,
  );
  await pumpFor(t, const Duration(milliseconds: 800));
  final tiles = find.descendant(
    of: screen,
    matching: find.byWidgetPredicate(
      (w) => w is BranchTile && w.name == b.tileName,
    ),
  );
  await pumpUntilFound(t, tiles, reason: 'tile for ${b.name}');
  final shown = [
    for (final e
        in find
            .descendant(of: screen, matching: find.byType(BranchTile))
            .evaluate())
      (e.widget as BranchTile).name,
  ];
  // "Birmingham" also matches "KP2 Birmingham": main tiles come first.
  await tapVisible(t, b.isPhaseTwo ? tiles.last : tiles.first);
  await pumpUntil(
    t,
    () => find.byType(BranchSelectionScreen).evaluate().isEmpty,
    timeout: const Duration(seconds: 20),
  );
  await pumpFor(t, const Duration(milliseconds: 800));
  return shown;
}

// ── More tab ─────────────────────────────────────────────────────────────────

Finder get moreScroll => find.descendant(
  of: find.byType(SettingsScreen),
  matching: find.byType(Scrollable),
);

/// Opens the More tab and taps the row labelled [label].
Future<void> openMoreRow(WidgetTester t, String label) async {
  if (find.byType(SettingsScreen).evaluate().isEmpty) await tapNav(t, 'More');
  await pumpUntilFound(t, find.byType(SettingsScreen));
  final row = find.descendant(
    of: find.byType(SettingsScreen),
    matching: find.text(label),
  );
  await scrollUntilFound(t, row, scrollable: moreScroll);
  await t.tap(row.first, warnIfMissed: false);
  await pumpFor(t, const Duration(milliseconds: 600));
}

// ── Messages ─────────────────────────────────────────────────────────────────

Finder get messagesScroll => find.byWidgetPredicate(
  (w) =>
      w is CustomScrollView &&
      w.key == const PageStorageKey<String>('messages-scroll'),
);

/// Clears the Messages search through its own button (the query lives in
/// the field's controller too).
Future<void> clearMessagesSearch(WidgetTester t) async {
  final clear = find.byTooltip('Clear search');
  if (clear.evaluate().isNotEmpty) {
    await t.tap(clear.first, warnIfMissed: false);
    await pumpFor(t, const Duration(milliseconds: 500));
  }
  FocusManager.instance.primaryFocus?.unfocus();
  await pumpFor(t, const Duration(milliseconds: 300));
}

/// Messages tab with no search, no filter, newest first, at the top.
Future<void> openMessagesReset(Journey j) async {
  final t = j.tester;
  await tapNav(t, 'Messages');
  await pumpUntilFound(t, messagesScroll);
  await clearMessagesSearch(t);
  j.c.read(selectedCategoryProvider.notifier).state = 'All';
  j.c.read(selectedSeriesProvider.notifier).state = null;
  j.c.read(selectedSpeakerProvider.notifier).state = null;
  j.c.read(selectedArchiveYearProvider.notifier).state = null;
  j.c.read(sermonSortProvider.notifier).state = SermonSort.newest;
  await pumpFor(t, const Duration(milliseconds: 500));
  // Jump rather than drag: with paging the list can be hundreds of rows
  // long, further than any single fling.
  final scrollable = find.descendant(
    of: messagesScroll,
    matching: find.byType(Scrollable),
  );
  if (scrollable.evaluate().isNotEmpty) {
    t.state<ScrollableState>(scrollable.first).position.jumpTo(0);
  }
  await pumpFor(t, const Duration(milliseconds: 800));
}

/// Waits for the whole archive to be in memory.
Future<bool> waitArchiveHydrated(Journey j) => pumpUntil(
  j.tester,
  () {
    final lib = j.c.read(sermonLibraryProvider);
    return lib.loaded && !lib.hasMore && !lib.hydrating;
  },
  timeout: const Duration(minutes: 5),
  step: const Duration(seconds: 1),
);

/// The horizontal list holding any widget [content] matches, re-resolved
/// on every use so it survives sliver rebuilds.
Finder railOf(Finder content, String description) {
  Element? rail;
  for (final hit in content.evaluate()) {
    final scrollables = find
        .ancestor(
          of: find.byElementPredicate((e) => identical(e, hit)),
          matching: find.byWidgetPredicate(
            (w) => w is Scrollable && w.axisDirection == AxisDirection.right,
          ),
        )
        .evaluate();
    if (scrollables.isNotEmpty) {
      rail = scrollables.first;
      break;
    }
  }
  return find.byElementPredicate(
    (e) => rail != null && identical(e, rail),
    description: description,
  );
}

// ── Player ───────────────────────────────────────────────────────────────────

Finder get player => find.byType(MediaPlayerScreen);

Finder inPlayer(Finder f) => find.descendant(of: player, matching: f);

SeekBar seekBarOf(WidgetTester t) =>
    t.widget<SeekBar>(inPlayer(find.byType(SeekBar)).first);

MediaModeToggle modeToggleOf(WidgetTester t) =>
    t.widget<MediaModeToggle>(inPlayer(find.byType(MediaModeToggle)));

Future<void> tapMode(WidgetTester t, String label) => t.tap(
  find.descendant(of: find.byType(MediaModeToggle), matching: find.text(label)),
  warnIfMissed: false,
);

/// Notes / Playlist / Transcript / Share sit below the fold.
Future<void> tapPlayerAction(WidgetTester t, String label) async {
  final target = inPlayer(find.text(label));
  await pumpUntilFound(t, target, reason: 'player action "$label"');
  await t.ensureVisible(target.first);
  await pumpFor(t, const Duration(milliseconds: 400));
  await t.tap(target.first, warnIfMissed: false);
}

Future<void> closePlayer(WidgetTester t) async {
  await t.tap(
    inPlayer(find.byIcon(Icons.keyboard_arrow_down_rounded)).first,
    warnIfMissed: false,
  );
  await pumpUntil(t, () => player.evaluate().isEmpty);
  await pumpFor(t, const Duration(milliseconds: 600));
}

String fmt(Duration d) =>
    '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
