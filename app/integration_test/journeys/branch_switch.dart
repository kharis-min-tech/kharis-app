import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kharis_app/shared/providers/sermon_provider.dart';
import 'package:kharis_app/shared/providers/campus_config_provider.dart';
import 'package:kharis_app/features/home/presentation/widgets/next_service_card.dart';
import 'package:kharis_app/features/calendar/data/event_repository.dart';
import 'package:kharis_app/features/calendar/presentation/screens/calendar_screen.dart';
import 'package:kharis_app/features/calendar/presentation/widgets/event_card.dart';
import 'package:kharis_app/features/home/presentation/screens/branch_screen.dart';
import 'package:kharis_app/features/home/presentation/screens/home_screen.dart';
import 'package:kharis_app/features/home/presentation/widgets/upcoming_events_strip.dart';
import 'package:kharis_app/features/onboarding/presentation/screens/branch_selection_screen.dart';
import 'package:kharis_app/features/settings/presentation/screens/settings_screen.dart';
import 'package:kharis_app/shared/providers/branch_provider.dart';
import 'package:kharis_app/shared/providers/notification_feed_provider.dart';

import '../support/actions.dart';
import '../support/harness.dart';
import '../support/live_data.dart';

Finder get _homeScroll => verticalScrollableIn(find.byType(HomeScreen));

/// (b) Switch to a different branch (picked at random, seeded by the date)
/// from More > Switch branch; Home, announcements, events and service times
/// follow that branch's Studio data; then switch to All branches.
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

  // More > Switch branch.
  await openMoreRow(t, 'Switch branch');
  await pumpUntilFound(t, find.byType(BranchSelectionScreen));
  await chooseBranchInPicker(j, to);
  j.check(
    find.byType(SettingsScreen).evaluate().isNotEmpty,
    'choosing a branch returns to More',
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
  j.check(
    find
        .descendant(
          of: find.byType(SettingsScreen),
          matching: find.text(to.name),
        )
        .evaluate()
        .isNotEmpty,
    'More shows "${to.name}" on the Switch branch row',
  );
  await j.shot('more-after-switch');

  // Home: the Next service card; its Full timetable opens the Branch page
  // with every Studio service, the branch named once (in the app bar).
  await tapNav(t, 'Home');
  final card = find.byKey(const Key('home-next-service'));
  if (to.services.isEmpty) {
    j.note('DATA: "${to.name}" has no active services in the Studio');
    await pumpFor(t, const Duration(seconds: 2));
    j.check(card.evaluate().isEmpty, 'no Next service card without services');
  } else {
    await scrollUntilFound(t, card, scrollable: _homeScroll);
    await j.shot('home-next-service');
    final timetable = find.descendant(
      of: card,
      matching: find.byKey(const Key('next-service-timetable')),
    );
    await ensureCentred(t, timetable);
    await t.tap(timetable, warnIfMissed: false);
    final page = find.byType(BranchScreen);
    await pumpUntilFound(t, page);
    await pumpFor(t, const Duration(milliseconds: 800));
    j.check(
      find
              .descendant(of: page, matching: find.text(to.name))
              .evaluate()
              .length ==
          1,
      'the Branch page names "${to.name}" once',
    );
    final scroll = find
        .descendant(of: page, matching: find.byType(Scrollable))
        .first;
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
    await tapBack(t);
    await pumpUntilFound(t, find.byType(HomeScreen));
  }

  // Announcements scoped to the branch.
  await _checkAnnouncements(j, news, to.name);
  // Upcoming events scoped to the branch, less its weekly service: that is
  // the Next service card, not repeated in the strip.
  final campus = j.c.read(currentCampusProvider);
  final serviceIds = {
    if (campus != null)
      for (final e
          in j.c.read(upcomingEventsProvider(to.name)).valueOrNull ??
              const <Event>[])
        if (isBranchServiceEvent(e, campus)) e.id,
  };
  j.note('weekly service events shown as Next service: $serviceIds');
  final expected = events
      .where(
        (e) =>
            !e.isPast(now) &&
            e.visibleTo(to.name) &&
            !serviceIds.contains(e.id),
      )
      .toList();
  final hidden = events
      .where((e) => !e.isPast(now) && !e.visibleTo(to.name))
      .toList();
  await _checkHomeEvents(j, expected, hidden, to.name);

  // Events tab: branch chip -> All branches.
  await tapNav(t, 'Events');
  await pumpUntilFound(t, find.byType(CalendarScreen));
  final chip = find.descendant(
    of: find.byType(CalendarScreen),
    matching: find.text('YOUR BRANCH'),
  );
  await pumpUntilFound(t, chip);
  j.check(
    find
        .descendant(
          of: find.byType(CalendarScreen),
          matching: find.text(to.name),
        )
        .evaluate()
        .isNotEmpty,
    'Events chip shows "${to.name}"',
  );
  await t.tap(chip, warnIfMissed: false);
  final all = find.byKey(const ValueKey('branch-choice-all'));
  await pumpUntilFound(t, all, reason: 'branch picker sheet');
  await j.shot('branch-sheet');
  await t.tap(all, warnIfMissed: false);
  j.check(
    await pumpUntil(
      t,
      () =>
          j.c.read(currentBranchProvider).hasValue &&
          j.c.read(currentBranchProvider).valueOrNull == null,
      timeout: const Duration(seconds: 15),
    ),
    'All branches clears the active branch',
  );
  await pumpFor(t, const Duration(seconds: 2));
  j.check(
    find
        .descendant(
          of: find.byType(CalendarScreen),
          matching: find.text('All branches'),
        )
        .evaluate()
        .isNotEmpty,
    'Events chip shows "All branches"',
  );
  final allUpcoming = events.where((e) => !e.isPast(now)).toList();
  await pumpUntil(
    t,
    () => j.c.read(campusUpcomingEventsProvider).hasValue,
    timeout: const Duration(seconds: 30),
  );
  final shownIds = {
    for (final e
        in j.c.read(campusUpcomingEventsProvider).valueOrNull ?? const [])
      e.id,
  };
  j.check(
    shownIds.length == allUpcoming.map((e) => e.id).toSet().length &&
        allUpcoming.every((e) => shownIds.contains(e.id)),
    'All branches lists every upcoming Studio event '
    '(${allUpcoming.map((e) => e.title).toList()}, app ids $shownIds)',
  );
  for (final e in allUpcoming.take(3)) {
    j.check(
      find
          .descendant(
            of: find.byType(CalendarScreen),
            matching: find.byWidgetPredicate(
              (w) => w is EventCard && w.event.id == e.id,
            ),
          )
          .evaluate()
          .isNotEmpty,
      'Events tab card for "${e.title}"',
    );
  }
  await j.shot('events-all-branches');

  await tapNav(t, 'Home');
  await pumpFor(t, const Duration(seconds: 1));
  j.check(
    find.byKey(const Key('campus-card')).evaluate().isEmpty,
    'Home hides the Your branch card for All branches',
  );
  await _checkAnnouncements(j, news, null);
}

Future<void> _checkAnnouncements(
  Journey j,
  List<Map<String, dynamic>> news,
  String? branch,
) async {
  final t = j.tester;
  final card = find.byKey(const Key('home-announcement-latest'));
  final now = DateTime.now();
  final visible = news.where((n) {
    final b = '${n['branch_name'] ?? n['branch'] ?? ''}'.trim();
    final exp = DateTime.tryParse(
      '${n['expires_at'] ?? n['expiry_date'] ?? ''}',
    );
    return (branch == null || b.isEmpty || b == branch) &&
        (exp == null || exp.isAfter(now));
  }).toList();
  // Sections sit above the branch card: start from the top.
  await t.drag(_homeScroll, const Offset(0, 20000), warnIfMissed: false);
  await pumpFor(t, const Duration(milliseconds: 600));
  if (visible.isEmpty) {
    // Nothing published: Home hides the whole block, heading included.
    final heading = find.byKey(const Key('home-announcements-see-all'));
    j.note('DATA: no live announcements for ${branch ?? 'All branches'}');
    await pumpUntil(
      t,
      () => heading.evaluate().isEmpty,
      timeout: const Duration(seconds: 30),
    );
    j.check(
      heading.evaluate().isEmpty && card.evaluate().isEmpty,
      'Announcements block hidden with nothing to show',
    );
  } else {
    // The card stays hidden until the feed answers.
    await pumpUntil(
      t,
      () => j.c.read(campusNewsProvider).hasValue,
      timeout: const Duration(seconds: 30),
    );
    await scrollUntilFound(t, card, scrollable: _homeScroll);
    final feed = j.c.read(campusNewsProvider).valueOrNull ?? const [];
    final visibleIds = {for (final n in visible) '${n['id']}'};
    j.check(
      feed.every((n) => visibleIds.contains(n.id)),
      'announcement feed holds only ${branch ?? 'All branches'} notices',
    );
    j.check(feed.isNotEmpty, 'announcement feed answered with notices');
    if (feed.isNotEmpty) {
      final newest = feed.first;
      j.check(
        find
            .descendant(of: card, matching: find.text(newest.title))
            .evaluate()
            .isNotEmpty,
        'newest announcement "${newest.title}" shown for '
        '${branch ?? 'All branches'}',
      );
    }
  }
  await j.shot('home-announcements-${branch ?? 'all'}');
}

Future<void> _checkHomeEvents(
  Journey j,
  List<StudioEvent> expected,
  List<StudioEvent> hidden,
  String branch,
) async {
  final t = j.tester;
  final strip = find.byType(UpcomingEventsStrip);
  await t.drag(_homeScroll, const Offset(0, 20000), warnIfMissed: false);
  await pumpFor(t, const Duration(milliseconds: 600));
  await scrollUntilFound(t, strip, scrollable: _homeScroll);
  await pumpUntil(
    t,
    () => find.byKey(const Key('events-strip-skeleton')).evaluate().isEmpty,
    timeout: const Duration(seconds: 30),
  );
  await pumpFor(t, const Duration(seconds: 1));
  final texts = paintedTexts(within: strip);
  if (expected.isEmpty) {
    j.note('DATA: no upcoming Studio events visible to $branch');
    j.check(
      texts.contains('No upcoming events at $branch yet.'),
      'events strip empty state for $branch (painted $texts)',
    );
  } else {
    final shown = {
      for (final e
          in j.c.read(campusUpcomingEventsProvider).valueOrNull ?? const [])
        e.id,
    };
    for (final e in expected) {
      j.check(shown.contains(e.id), 'event "${e.title}" listed for $branch');
    }
    j.check(
      texts.any((s) => s.contains(expected.first.title)) ||
          // The strip is horizontal; later cards may be off screen.
          find
              .descendant(
                of: strip,
                matching: find.text(expected.first.title, skipOffstage: false),
              )
              .evaluate()
              .isNotEmpty,
      'strip shows "${expected.first.title}"',
    );
  }
  for (final e in hidden) {
    j.check(
      !(j.c.read(campusUpcomingEventsProvider).valueOrNull ?? const []).any(
        (x) => x.id == e.id,
      ),
      'event "${e.title}" (branch ${e.branch}) is hidden from $branch',
    );
  }
  await j.shot('home-events-$branch');
}
