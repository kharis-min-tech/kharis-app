// App actions several journeys share: branch picker, More rows, the
// Messages browse state and the player.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kharis_app/features/onboarding/presentation/screens/branch_selection_screen.dart';
import 'package:kharis_app/features/onboarding/presentation/widgets/branch_tile.dart';
import 'package:kharis_app/features/player/presentation/screens/media_player_screen.dart';
import 'package:kharis_app/features/player/presentation/widgets/media_mode_toggle.dart';
import 'package:kharis_app/features/player/presentation/widgets/seek_bar.dart';
import 'package:kharis_app/features/messages/presentation/message_list.dart';
import 'package:kharis_app/features/messages/presentation/screens/message_search_screen.dart';
import 'package:kharis_app/features/settings/presentation/screens/settings_screen.dart';
import 'package:kharis_app/shared/providers/sermon_provider.dart';
import 'package:kharis_app/shared/widgets/branch_picker_sheet.dart';

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

/// In the open branch picker sheet, taps the row for [name] and waits for
/// the sheet to close.
Future<void> chooseBranchInSheet(Journey j, String name) async {
  final t = j.tester;
  final sheet = find.byType(BranchPickerSheet);
  await pumpUntilFound(t, sheet, reason: 'branch picker sheet');
  final row = find.byKey(ValueKey('branch-choice-$name'));
  await pumpUntilFound(
    t,
    find.byKey(ValueKey('branch-choice-$name'), skipOffstage: false),
    reason: 'row for $name',
  );
  await scrollUntilFound(t, row, scrollable: verticalScrollableIn(sheet));
  await tapVisible(t, row);
  await pumpUntil(
    t,
    () => sheet.evaluate().isEmpty,
    timeout: const Duration(seconds: 20),
  );
  await pumpFor(t, const Duration(milliseconds: 800));
}

// ── More tab ─────────────────────────────────────────────────────────────────

Finder get moreScroll => find.descendant(
  of: find.byType(SettingsScreen),
  matching: find.byType(Scrollable),
);

/// Opens the More tab and taps the row or tile labelled [label].
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

/// Opens the events list the way a member does: More's Events tile.
Future<void> openEvents(WidgetTester t) => openMoreRow(t, 'Events');

/// Opens Give the way a member does: More's Give tile.
Future<void> openGive(WidgetTester t) => openMoreRow(t, 'Give');

// ── Messages ─────────────────────────────────────────────────────────────────

Finder get messagesScroll => find.byWidgetPredicate(
  (w) =>
      w is CustomScrollView &&
      w.key == const PageStorageKey<String>('messages-scroll'),
);

/// The Messages tab's lists (For you / Books / Themes / Series / Downloads).
Finder get messagesTabs => find.byKey(const Key('messages-tabs'));

/// Messages tab with no search, no filter, newest first, at the top.
Future<void> openMessagesReset(Journey j) async {
  final t = j.tester;
  await tapNav(t, 'Messages');
  // The tab keeps its stack: Search (or a list) left open there comes back
  // with it; swipe back to the tab itself, as a member would.
  bool stacked() =>
      find.byType(MessageSearchScreen).evaluate().isNotEmpty ||
      find.byType(MessageListScreen).evaluate().isNotEmpty;
  for (var i = 0; i < 3 && stacked(); i++) {
    await goBack(t);
  }
  await pumpUntilFound(t, messagesScroll);
  final forYou = find.descendant(
    of: messagesTabs,
    matching: find.text('For you'),
  );
  if (forYou.evaluate().isNotEmpty) {
    await t.tap(forYou, warnIfMissed: false);
  }
  FocusManager.instance.primaryFocus?.unfocus();
  j.c.read(sermonSearchProvider.notifier).state = '';
  j.c.read(selectedCategoryProvider.notifier).state = 'All';
  j.c.read(selectedSeriesProvider.notifier).state = null;
  j.c.read(selectedSpeakerProvider.notifier).state = null;
  j.c.read(selectedArchiveYearProvider.notifier).state = null;
  j.c.read(sermonSortProvider.notifier).state = SermonSort.newest;
  await pumpFor(t, const Duration(milliseconds: 500));
  // Jump rather than drag: a long tab can sit far below the header.
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

/// Notes / Playlist / Transcript / Share sit below the fold. Centred
/// before the tap: at the very top they would sit under the player's
/// compact bar, which takes the touch.
Future<void> tapPlayerAction(WidgetTester t, String label) async {
  final target = inPlayer(find.text(label));
  await pumpUntilFound(t, target, reason: 'player action "$label"');
  await Scrollable.ensureVisible(t.element(target.first), alignment: 0.5);
  await pumpFor(t, const Duration(milliseconds: 400));
  await t.tap(target.first, warnIfMissed: false);
}

/// Closes the full player the way a member does: a swipe down on its grab
/// handle; when the page has scrolled the handle away, the swipe back.
Future<void> closePlayer(WidgetTester t) async {
  final handle = inPlayer(
    find.byKey(const Key('player-grab-handle')),
  ).hitTestable();
  if (handle.evaluate().isNotEmpty) {
    await t.fling(handle.first, const Offset(0, 300), 1500, warnIfMissed: false);
    await pumpUntil(
      t,
      () => player.evaluate().isEmpty,
      timeout: const Duration(seconds: 3),
    );
  }
  if (player.evaluate().isNotEmpty) await goBack(t);
  await pumpUntil(t, () => player.evaluate().isEmpty);
  await pumpFor(t, const Duration(milliseconds: 600));
}

String fmt(Duration d) =>
    '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
