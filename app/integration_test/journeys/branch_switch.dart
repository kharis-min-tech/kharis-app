import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kharis_app/features/calendar/data/branch_service_events.dart';
import 'package:kharis_app/features/calendar/presentation/screens/calendar_screen.dart';
import 'package:kharis_app/features/home/presentation/screens/branch_screen.dart';
import 'package:kharis_app/features/home/presentation/screens/home_screen.dart';
import 'package:kharis_app/features/home/presentation/widgets/home_this_week.dart';
import 'package:kharis_app/features/settings/presentation/screens/settings_screen.dart';
import 'package:kharis_app/shared/providers/branch_provider.dart';
import 'package:kharis_app/shared/providers/campus_config_provider.dart';
import 'package:kharis_app/shared/providers/notification_feed_provider.dart';
import 'package:kharis_app/shared/widgets/branch_picker_sheet.dart';

import '../support/actions.dart';
import '../support/harness.dart';
import '../support/live_data.dart';

Finder get _homeScroll => verticalScrollableIn(find.byType(HomeScreen));

Finder get _sheet => find.byType(BranchPickerSheet);

/// (b) Switch to a different branch (picked at random, seeded by the date)
/// from More's Your branch card; More, the branch page, Home's announcements
/// and This week, and the events list follow that branch's Studio data. The
/// events list then browses All branches, which leaves the member's branch
/// (and Home) alone, and the member's own picker offers "Use my location",
/// never "All branches".
Future<void> branchSwitchJourney(Journey j) async {
  final t = j.tester;
  final branches = await studioBranches();
  if (branches.length < 2) {
    j.check(branches.isNotEmpty, 'Studio lists active branches');
    j.skip('the Studio has fewer than two active branches to switch between');
  }
  final r = seeded(effectiveSeed, 'branch-switch');
  final from = pick(r, branches);
  final to = pick(r, branches.where((b) => b.uuid != from.uuid).toList());
  j.note(
    'seed $effectiveSeed: start at "${from.name}", switch to "${to.name}"',
  );
  final events = await studioEvents();
  final news = await studioNews();
  final now = DateTime.now();

  await j.launch(branch: from.name);
  await pumpUntilFound(t, find.byType(HomeScreen));

  // More > Your branch > Change branch.
  await tapNav(t, 'More');
  await pumpUntilFound(t, find.byType(SettingsScreen));
  final change = find.byWidgetPredicate(
    (w) =>
        w.key == const Key('campus-change') ||
        w.key == const Key('more-choose-branch'),
  );
  await scrollUntilFound(t, change, scrollable: moreScroll);
  await tapVisible(t, change);
  await chooseBranchInSheet(j, to.name);
  j.check(
    find.byType(SettingsScreen).evaluate().isNotEmpty,
    'choosing a branch stays on More',
  );
  j.check(
    await pumpUntil(
      t,
      () => j.c.read(currentBranchProvider).valueOrNull == to.name,
      timeout: const Duration(seconds: 15),
    ),
    'active branch is "${to.name}" '
    '(got ${j.c.read(currentBranchProvider).valueOrNull})',
  );
  final campus = find.byKey(const Key('campus-card'));
  j.check(
    await pumpUntil(
      t,
      () => find
          .descendant(of: campus, matching: find.text(to.name))
          .evaluate()
          .isNotEmpty,
      timeout: const Duration(seconds: 15),
    ),
    'More\u2019s Your branch card shows "${to.name}"',
  );
  await j.shot('more-after-switch');

  // The branch page from More's card: every Studio service, the branch
  // named once (in the header).
  await tapVisible(t, campus);
  final page = find.byType(BranchScreen);
  await pumpUntilFound(t, page);
  await pumpFor(t, const Duration(milliseconds: 800));
  j.check(
    find.descendant(of: page, matching: find.text(to.name)).evaluate().length ==
        1,
    'the branch page names "${to.name}" once',
  );
  if (to.services.isEmpty) {
    j.note('DATA: "${to.name}" has no active services in the Studio');
  }
  final scroll = verticalScrollableIn(page);
  for (final s in to.services) {
    final row = find.byKey(Key('campus-service-${s['id']}'));
    await scrollUntilFound(t, row, scrollable: scroll);
    final texts = paintedTexts(within: row);
    final when = serviceWhen(s);
    j.check(
      texts.contains('${s['name']}'.trim()) &&
          (when == null || texts.contains(when)),
      'service "${s['name']}" shows "$when" (painted $texts)',
    );
  }
  await j.shot('branch-timetable');
  await goBack(t);
  await pumpUntil(t, () => page.evaluate().isEmpty);

  // Home: announcements and This week scoped to the branch.
  await tapNav(t, 'Home');
  await pumpUntilFound(t, find.byType(HomeScreen));
  await _checkAnnouncements(j, news, to.name);
  final expected = events
      .where((e) => !e.isPast(now) && e.visibleTo(to.name))
      .toList();
  final hidden = events
      .where((e) => !e.isPast(now) && !e.visibleTo(to.name))
      .toList();
  await _checkHomeEvents(j, expected, hidden, to.name);

  // Home's All events: the branch link -> All branches, a browse filter.
  final seeAll = find.byKey(const Key('home-events-see-all'));
  await scrollUntilFound(t, seeAll, scrollable: _homeScroll);
  await tapVisible(t, seeAll);
  final list = find.byType(CalendarScreen);
  await pumpUntilFound(t, list);
  final link = find.descendant(
    of: list,
    matching: find.text('Your branch \u00b7 ${to.name}'),
  );
  j.check(
    await pumpUntil(t, () => link.evaluate().isNotEmpty),
    'Events names "Your branch \u00b7 ${to.name}"',
  );
  await tapVisible(t, link);
  final all = find.byKey(const ValueKey('branch-choice-all'));
  await pumpUntilFound(t, all, reason: 'branch picker sheet');
  await j.shot('branch-sheet');
  await t.tap(all, warnIfMissed: false);
  j.check(
    await pumpUntil(
      t,
      () => find
          .descendant(
            of: list,
            matching: find.text('Showing \u00b7 $kAllCampusesLabel'),
          )
          .evaluate()
          .isNotEmpty,
    ),
    'Events shows "All branches"',
  );
  j.check(
    j.c.read(currentBranchProvider).valueOrNull == to.name,
    'browsing All branches keeps the member\'s branch "${to.name}" '
    '(got ${j.c.read(currentBranchProvider).valueOrNull})',
  );
  final allUpcoming = events.where((e) => !e.isPast(now)).toList();
  await pumpUntil(
    t,
    () => j.c.read(eventsUpcomingProvider).hasValue,
    timeout: const Duration(seconds: 30),
  );
  final shown = j.c.read(eventsUpcomingProvider).valueOrNull ?? const [];
  final shownIds = {
    for (final e in shown)
      if (!isBranchServiceEventId(e.id)) e.id,
  };
  j.check(
    shownIds.length == allUpcoming.map((e) => e.id).toSet().length &&
        allUpcoming.every((e) => shownIds.contains(e.id)),
    'All branches lists every upcoming Studio event '
    '(${allUpcoming.map((e) => e.title).toList()}, app ids $shownIds)',
  );
  final serviceBranches = {
    for (final e in shown)
      if (isBranchServiceEventId(e.id)) e.branch,
  };
  j.check(
    serviceBranches.every((b) => b == to.name),
    'All branches adds only the member\'s branch services '
    '(got $serviceBranches)',
  );
  // The list builds lazily and the branch's services sort in among the
  // Studio events, so scroll each card into view before checking it.
  final eventsList = verticalScrollableIn(list);
  for (final e in allUpcoming.take(3)) {
    final card = find.descendant(of: list, matching: find.text(e.title));
    var found = true;
    try {
      await scrollUntilFound(
        t,
        card,
        scrollable: eventsList,
        timeout: const Duration(seconds: 30),
      );
    } on Object {
      found = false;
    }
    j.check(found, 'Events card for "${e.title}"');
  }
  t.state<ScrollableState>(eventsList).position.jumpTo(0);
  await pumpFor(t, const Duration(milliseconds: 600));
  await j.shot('events-all-branches');

  // Home still follows the member's branch, and their own picker offers
  // "Use my location" and the branches, never "All branches".
  await goBack(t);
  await pumpUntil(t, () => list.evaluate().isEmpty);
  await pumpFor(t, const Duration(seconds: 1));
  j.check(
    j.c.read(homeBranchProvider).valueOrNull == to.name,
    'Home still shows "${to.name}" '
    '(got ${j.c.read(homeBranchProvider).valueOrNull})',
  );
  await _checkAnnouncements(j, news, to.name);
  // The greeting's branch control is in the hero: from the top.
  t.state<ScrollableState>(_homeScroll).position.jumpTo(0);
  await pumpFor(t, const Duration(milliseconds: 800));
  await tapVisible(t, find.byKey(const Key('home-branch-change')));
  final useLocation = find.byKey(const ValueKey('branch-use-location'));
  await pumpUntilFound(t, useLocation, reason: 'member branch picker');
  j.check(all.evaluate().isEmpty, 'the member picker has no "All branches"');
  await j.shot('member-branch-sheet');
  await goBack(t);
  j.check(
    await pumpUntil(t, () => _sheet.evaluate().isEmpty),
    'the branch picker dismisses',
  );
}

Future<void> _checkAnnouncements(
  Journey j,
  List<Map<String, dynamic>> news,
  String branch,
) async {
  final t = j.tester;
  final block = find.byKey(const Key('home-announcements'));
  final now = DateTime.now();
  final visible = news.where((n) {
    final b = '${n['branch_name'] ?? n['branch'] ?? ''}'.trim();
    final exp = DateTime.tryParse(
      '${n['expires_at'] ?? n['expiry_date'] ?? ''}',
    );
    return (b.isEmpty || b == branch) && (exp == null || exp.isAfter(now));
  }).toList();
  t.state<ScrollableState>(_homeScroll).position.jumpTo(0);
  await pumpFor(t, const Duration(milliseconds: 600));
  await pumpUntil(
    t,
    () => j.c.read(campusNewsProvider).hasValue,
    timeout: const Duration(seconds: 30),
  );
  if (visible.isEmpty) {
    // Nothing published: Home leaves the announcements out.
    j.note('DATA: no live announcements for $branch');
    await pumpFor(t, const Duration(seconds: 1));
    j.check(
      block.evaluate().isEmpty,
      'Announcements hidden with nothing to show',
    );
  } else {
    await scrollUntilFound(t, block, scrollable: _homeScroll);
    final feed = j.c.read(campusNewsProvider).valueOrNull ?? const [];
    final visibleIds = {for (final n in visible) '${n['id']}'};
    j.check(
      feed.every((n) => visibleIds.contains(n.id)),
      'announcement feed holds only $branch notices',
    );
    j.check(feed.isNotEmpty, 'announcement feed answered with notices');
    if (feed.isNotEmpty) {
      final newest = feed.first;
      final card = find.byKey(Key('home-announcement-${newest.id}'));
      j.check(
        find
            .descendant(of: card, matching: find.text(newest.title))
            .evaluate()
            .isNotEmpty,
        'newest announcement "${newest.title}" shown first for $branch',
      );
      for (final n in feed) {
        j.check(
          find
              .byKey(Key('home-announcement-${n.id}'), skipOffstage: false)
              .evaluate()
              .isNotEmpty,
          'announcement "${n.title}" has a card for $branch',
        );
      }
    }
  }
  await j.shot('home-announcements-$branch');
}

/// Home's This week: the branch's events (the Studio's and its weekly
/// services) in the next seven days, each as a card; nothing for another
/// branch.
Future<void> _checkHomeEvents(
  Journey j,
  List<StudioEvent> expected,
  List<StudioEvent> hidden,
  String branch,
) async {
  final t = j.tester;
  await pumpUntil(
    t,
    () => j.c.read(homeThisWeekEventsProvider).hasValue,
    timeout: const Duration(seconds: 30),
  );
  final upcoming = {
    for (final e
        in j.c.read(campusUpcomingEventsProvider).valueOrNull ?? const [])
      e.id,
  };
  for (final e in expected) {
    j.check(upcoming.contains(e.id), 'event "${e.title}" listed for $branch');
  }
  for (final e in hidden) {
    j.check(
      !upcoming.contains(e.id),
      'event "${e.title}" (branch ${e.branch}) is hidden from $branch',
    );
  }

  final now = DateTime.now();
  final until = now.add(kHomeThisWeekWindow);
  final thisWeek = j.c.read(homeThisWeekEventsProvider).valueOrNull ?? const [];
  final ids = {for (final e in thisWeek) e.id};
  // One-off Studio events that start this week (weekly ones repeat under
  // per-occurrence dates the app works out).
  for (final e in expected.where(
    (e) => !e.weekly && !e.start.isBefore(now) && e.start.isBefore(until),
  )) {
    j.check(ids.contains(e.id), 'This week lists "${e.title}" for $branch');
  }
  for (final e in thisWeek) {
    j.check(
      !isBranchServiceEventId(e.id) || e.branch == branch,
      'This week\u2019s service "${e.title}" is $branch\u2019s',
    );
  }
  if (thisWeek.isEmpty) {
    j.note('DATA: nothing on this week for $branch');
    final empty = find.byKey(const Key('home-events-empty'));
    await scrollUntilFound(t, empty, scrollable: _homeScroll);
    j.check(empty.evaluate().isNotEmpty, 'This week says nothing is on');
  } else {
    for (final e in thisWeek.take(3)) {
      final card = find.byKey(Key('home-event-${e.id}'));
      var found = true;
      try {
        await scrollUntilFound(t, card, scrollable: _homeScroll);
      } on Object {
        found = false;
      }
      j.check(
        found &&
            find
                .descendant(of: card, matching: find.text(e.title))
                .evaluate()
                .isNotEmpty,
        'This week shows "${e.title}"',
      );
    }
  }
  await j.shot('home-events-$branch');
}
