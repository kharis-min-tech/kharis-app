import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kharis_app/features/calendar/presentation/screens/calendar_screen.dart';
import 'package:kharis_app/features/calendar/presentation/screens/event_detail_screen.dart';
import 'package:kharis_app/features/calendar/presentation/widgets/event_card.dart';
import 'package:kharis_app/shared/providers/sermon_provider.dart';

import '../support/channels.dart';
import '../support/harness.dart';
import '../support/live_data.dart';

Finder _inCalendar(Finder f) =>
    find.descendant(of: find.byType(CalendarScreen), matching: f);

Finder _cardFor(String id) => _inCalendar(
  find.byWidgetPredicate(
    (w) => w is EventCard && w.event.id == id,
    skipOffstage: false,
  ),
);

Future<void> _tab(WidgetTester t, String label) async {
  await t.tap(_inCalendar(find.text(label)).first, warnIfMissed: false);
  await pumpFor(t, const Duration(seconds: 2));
}

/// Next start of a weekly Studio event (local time), as a member would
/// expect it: the first listed weekday, at the Studio's start time, whose
/// occurrence has not ended yet.
DateTime _nextOccurrence(StudioEvent e, DateTime now) {
  final length = (e.end ?? e.start).difference(e.start);
  final today = DateTime(now.year, now.month, now.day);
  for (var d = 0; d <= 7; d++) {
    final day = today.add(Duration(days: d));
    if (!e.days.contains(day.weekday % 7)) continue;
    final start = DateTime(
      day.year,
      day.month,
      day.day,
      e.start.hour,
      e.start.minute,
    );
    if (start.add(length).isAfter(now)) return start;
  }
  return e.start;
}

/// (c) Events: Upcoming / Past / My RSVPs against the Studio; a weekly event
/// is one card labelled "Every (day)"; detail; directions and calendar hand
/// the right request to the platform (answered by the harness, nothing is
/// added); RSVP round trip, then undone.
Future<void> eventsJourney(Journey j) async {
  final t = j.tester;
  final now = DateTime.now();
  final events = await studioEvents();
  final upcoming = events.where((e) => !e.isPast(now)).toList();
  final past = events.where((e) => e.isPast(now)).toList()
    ..sort((a, b) => b.start.compareTo(a.start));
  j.note(
    'Studio events: upcoming ${upcoming.map((e) => '$e').toList()}, '
    'past ${past.map((e) => '$e').toList()}',
  );

  await j.launch(branch: ''); // All branches: every Studio event applies.
  await tapNav(t, 'Events');
  await pumpUntilFound(t, find.byType(CalendarScreen));
  await pumpUntil(
    t,
    () =>
        _inCalendar(find.byType(CircularProgressIndicator)).evaluate().isEmpty,
    timeout: const Duration(seconds: 30),
  );
  await pumpFor(t, const Duration(seconds: 1));

  // ── Upcoming ─────────────────────────────────────────────────────────────
  if (upcoming.isEmpty) {
    j.note('DATA: the Studio has no upcoming events');
    j.check(
      _inCalendar(find.text('No upcoming events')).evaluate().isNotEmpty,
      'Upcoming shows "No upcoming events"',
    );
  }
  for (final e in upcoming) {
    final cards = _cardFor(e.id);
    j.check(
      cards.evaluate().length == 1,
      '"${e.title}" has exactly one Upcoming card '
      '(got ${cards.evaluate().length})',
    );
    if (e.weekly && cards.evaluate().isNotEmpty) {
      j.check(
        paintedTexts(within: cards.first).contains(e.everyLabel),
        'weekly "${e.title}" card reads "${e.everyLabel}" '
        '(painted ${paintedTexts(within: cards.first)})',
      );
    }
  }
  final appUpcoming = t
      .widgetList<EventCard>(
        _inCalendar(find.byType(EventCard, skipOffstage: false)),
      )
      .map((c) => c.event.id)
      .toSet();
  j.check(
    setEquals(appUpcoming, upcoming.map((e) => e.id).toSet()),
    'Upcoming lists exactly the Studio upcoming events '
    '(app $appUpcoming)',
  );
  if (!upcoming.any((e) => e.weekly)) {
    j.note(
      'DATA: no weekly event in the Studio; the "Every <day>" card '
      'is not exercised this run',
    );
  }
  await j.shot('upcoming');

  // ── Past ─────────────────────────────────────────────────────────────────
  await _tab(t, 'Past');
  if (past.isEmpty) {
    j.note('DATA: the Studio has no past one-off events');
    j.check(
      _inCalendar(find.text('No past events')).evaluate().isNotEmpty,
      'Past shows "No past events"',
    );
  } else {
    for (final e in past.take(15)) {
      j.check(_cardFor(e.id).evaluate().isNotEmpty, 'Past lists "${e.title}"');
    }
  }
  for (final e in upcoming.where((e) => e.weekly)) {
    j.check(
      _cardFor(e.id).evaluate().isEmpty,
      'weekly "${e.title}" is not in Past',
    );
  }
  await j.shot('past');

  // ── My RSVPs (before) ────────────────────────────────────────────────────
  await _tab(t, 'My RSVPs');
  await pumpUntil(
    t,
    () => j.c.read(myRsvpEventsProvider).hasValue,
    timeout: const Duration(seconds: 30),
  );
  await j.shot('my-rsvps-before');

  if (upcoming.isEmpty) {
    j.skip(
      'no upcoming Studio event to open, RSVP to or add to a calendar '
      '(empty states checked)',
    );
  }
  final target = upcoming.firstWhere(
    (e) => e.weekly,
    orElse: () => upcoming.first,
  );
  j.note('detail / RSVP target: $target');
  final rsvpedBefore = j.c.read(isEventRsvpedProvider(target.id));
  j.check(!rsvpedBefore, 'not RSVPed to "${target.title}" before the journey');

  // ── Detail ───────────────────────────────────────────────────────────────
  await _tab(t, 'Upcoming');
  await _openDetail(j, target);
  final detail = find.byType(EventDetailScreen);
  if (target.weekly) {
    j.check(
      paintedTexts(
        within: find.byKey(const Key('event-detail-recurrence')),
      ).any((s) => s.contains(target.everyLabel)),
      'detail repeats "${target.everyLabel}"',
    );
  }
  await j.shot('detail');

  final location = '${target.row['location'] ?? ''}'.trim();
  if (location.isNotEmpty) {
    final directions = find.descendant(
      of: detail,
      matching: find.text('Get directions'),
    );
    await tapVisible(t, directions);
    await pumpUntil(
      t,
      () => launches.isNotEmpty,
      timeout: const Duration(seconds: 5),
    );
    final mapsHost = defaultTargetPlatform == TargetPlatform.iOS
        ? 'maps.apple.com'
        : 'www.google.com/maps';
    final l = launches.isEmpty ? null : launches.last;
    j.check(
      l != null &&
          l.external &&
          l.url.contains(mapsHost) &&
          Uri.decodeFull(l.url.replaceAll('+', ' ')).contains(location),
      'Get directions opens $mapsHost externally for "$location" (got $l)',
    );
  } else {
    j.note('DATA: "${target.title}" has no location; no Get directions');
  }

  final addCal = find.descendant(
    of: detail,
    matching: find.text('Add to calendar'),
  );
  await tapVisible(t, addCal);
  await pumpUntil(
    t,
    () => calendarAdds.isNotEmpty,
    timeout: const Duration(seconds: 5),
  );
  final add = calendarAdds.isEmpty ? null : calendarAdds.last;
  final wantStart = target.weekly ? _nextOccurrence(target, now) : target.start;
  final gotStart = add == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch((add['startDate'] as num).toInt());
  j.check(
    add != null && add['title'] == target.title,
    'Add to calendar sends "${target.title}" (got ${add?['title']})',
  );
  j.check(
    gotStart != null &&
        gotStart.difference(wantStart).abs() < const Duration(minutes: 1),
    'calendar start is $wantStart (got $gotStart)',
  );
  if (target.weekly) {
    j.check(
      '${add?['desc']}'.contains('Repeats weekly: ${target.everyLabel}.'),
      'calendar description says it repeats weekly',
    );
  }

  // ── RSVP round trip ──────────────────────────────────────────────────────
  final rsvp = find.descendant(of: detail, matching: find.text('RSVP'));
  final going = find.descendant(
    of: detail,
    matching: find.text('Going \u2713'),
  );
  await tapVisible(t, rsvp);
  j.check(
    await pumpUntil(
      t,
      () => going.evaluate().isNotEmpty,
      timeout: const Duration(seconds: 20),
    ),
    'RSVP turns into "Going ✓"',
  );
  j.check(
    await pumpUntil(
      t,
      () => j.c.read(isEventRsvpedProvider(target.id)),
      timeout: const Duration(seconds: 20),
    ),
    'RSVP saved to the account',
  );
  await j.shot('rsvp-going');
  await tapBack(t);
  await pumpUntilFound(t, find.byType(CalendarScreen));
  await _tab(t, 'My RSVPs');
  j.check(
    await pumpUntil(
      t,
      () => _inCalendar(find.text(target.title)).evaluate().isNotEmpty,
      timeout: const Duration(seconds: 20),
    ),
    'My RSVPs lists "${target.title}"',
  );
  await j.shot('my-rsvps-after');

  // Undo from the same detail.
  await _tab(t, 'Upcoming');
  await _openDetail(j, target);
  await tapVisible(t, going);
  j.check(
    await pumpUntil(
      t,
      () => rsvp.evaluate().isNotEmpty,
      timeout: const Duration(seconds: 20),
    ),
    'tapping "Going ✓" cancels the RSVP',
  );
  j.check(
    await pumpUntil(
      t,
      () => !j.c.read(isEventRsvpedProvider(target.id)),
      timeout: const Duration(seconds: 20),
    ),
    'RSVP removed from the account',
  );
  await tapBack(t);
  await pumpUntilFound(t, find.byType(CalendarScreen));
  await _tab(t, 'My RSVPs');
  j.check(
    await pumpUntil(
      t,
      () => _inCalendar(find.text(target.title)).evaluate().isEmpty,
      timeout: const Duration(seconds: 20),
    ),
    'My RSVPs no longer lists "${target.title}"',
  );
  await j.shot('my-rsvps-undone');
}

Future<void> _openDetail(Journey j, StudioEvent e) async {
  final t = j.tester;
  final card = _cardFor(e.id);
  await pumpUntilFound(t, card, reason: 'card for ${e.title}');
  await tapVisible(
    t,
    find.descendant(of: card.first, matching: find.text(e.title)),
  );
  await pumpUntilFound(t, find.byType(EventDetailScreen));
  await pumpUntilFound(
    t,
    find.descendant(
      of: find.byType(EventDetailScreen),
      matching: find.text('Add to calendar'),
    ),
    reason: 'detail loaded',
  );
  await pumpFor(t, const Duration(seconds: 1));
}
