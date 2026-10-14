import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kharis_app/features/messages/presentation/widgets/sermon_list_item.dart';
import 'package:kharis_app/shared/models/sermon.dart';
import 'package:kharis_app/shared/providers/sermon_provider.dart';

import '../support/actions.dart';
import '../support/harness.dart';
import '../support/live_data.dart';

/// Scrolls the Messages page until a pill of [railPattern]'s rail is on
/// screen, then drags that rail sideways until [label] is, and taps it.
Future<void> _tapRailPill(
  Journey j,
  String label,
  RegExp railPattern,
) async {
  final t = j.tester;
  final anyPill = find.textContaining(railPattern);
  await scrollUntilFound(t, anyPill, scrollable: messagesScroll, step: const Offset(0, -150));
  final rail = railOf(anyPill, 'rail $railPattern');
  final target = find.text(label);
  final end = DateTime.now().add(const Duration(seconds: 40));
  while (target.evaluate().isEmpty && DateTime.now().isBefore(end)) {
    await t.drag(rail, const Offset(-250, 0), warnIfMissed: false);
    await pumpFor(t, const Duration(milliseconds: 300));
  }
  await pumpUntilFound(t, target, timeout: const Duration(seconds: 2), reason: 'pill "$label"');
  await t.ensureVisible(target.first);
  await pumpFor(t, const Duration(milliseconds: 300));
  await t.tap(target.first, warnIfMissed: false);
  await pumpFor(t, const Duration(seconds: 2));
}

List<Sermon> _list(Journey j) => j.c.read(librarySermonsProvider);

/// (d) Messages: the archive hydrates to the live API total; a search for a
/// word from a live title hits it, nonsense shows the empty state; topic,
/// series and year filters each narrow the list to what they say; Oldest /
/// Newest order it; pull to refresh refetches.
Future<void> messagesJourney(Journey j) async {
  final t = j.tester;
  final r = seeded(effectiveSeed, 'messages');
  final apiCount = await sermonApiCount();
  final r2 = await r2Messages();
  j.note('live sermon API count $apiCount, R2 catalogue ${r2.length}');

  await j.launch();
  await openMessagesReset(j);

  // ── Hydration ────────────────────────────────────────────────────────────
  final started = DateTime.now();
  final hydrated = await waitArchiveHydrated(j);
  final lib = j.c.read(sermonLibraryProvider);
  j.note(
    'archive ${lib.sermons.length}/${lib.totalCount} after '
    '${DateTime.now().difference(started).inSeconds}s '
    '(offline=${lib.offline} hydrationFailed=${lib.hydrationFailed})',
  );
  j.check(hydrated, 'archive finished hydrating');
  j.check(
    lib.sermons.length == apiCount,
    'archive holds the live API total $apiCount (got ${lib.sermons.length})',
  );
  await j.shot('browse');

  // ── Search ───────────────────────────────────────────────────────────────
  final withTitles = r2
      .where((m) => RegExp(r'[A-Za-z]{6,}').hasMatch('${m['title']}'))
      .toList();
  final probe = pick(r, withTitles);
  final words = RegExp(r'[A-Za-z]{6,}')
      .allMatches('${probe['title']}')
      .map((m) => m.group(0)!)
      .toList()
    ..sort((a, b) => b.length.compareTo(a.length));
  final query = words.first;
  j.note('search probe: "$query" from "${probe['title']}" (${probe['id']})');
  final field = find.byType(TextField).first;
  await t.tap(field, warnIfMissed: false);
  await t.enterText(field, query);
  final resultsRe = RegExp('^([\\d,]+) results? for "${RegExp.escape(query)}"\$');
  int? hits;
  final found = await pumpUntil(t, () {
    for (final s in paintedTexts()) {
      final m = resultsRe.firstMatch(s);
      if (m != null) {
        hits = int.parse(m.group(1)!.replaceAll(',', ''));
        return true;
      }
    }
    return false;
  }, timeout: const Duration(seconds: 30));
  final results = j.c.read(searchResultsProvider);
  j.check(found && (hits ?? 0) > 0, '"$query" reports results ($hits)');
  j.check(
    results.any((s) => s.id == '${probe['id']}'),
    'results include "${probe['title']}"',
  );
  j.check(
    results.every((s) => sermonMatchesQuery(s, query)),
    'every result matches "$query"',
  );
  FocusManager.instance.primaryFocus?.unfocus();
  await j.shot('search-hit');

  const nonsense = 'zxqvj plorbft 7731';
  await clearMessagesSearch(t);
  await t.tap(field, warnIfMissed: false);
  await t.enterText(field, nonsense);
  j.check(
    await pumpUntil(
      t,
      () => find.text('No messages match "$nonsense"').evaluate().isNotEmpty,
      timeout: const Duration(seconds: 60),
    ),
    'nonsense query shows "No messages match"',
  );
  FocusManager.instance.primaryFocus?.unfocus();
  await j.shot('search-empty');
  await clearMessagesSearch(t);
  await openMessagesReset(j);
  final all = _list(j).length;

  // ── Topic ────────────────────────────────────────────────────────────────
  final counts = j.c.read(categoryCountsProvider);
  final topics = j.c
      .read(categoryLabelsProvider)
      .where((l) => l != 'All' && (counts[l] ?? 0) > 0)
      .toList();
  if (topics.isEmpty) {
    j.check(false, 'the library has at least one topic with messages');
  } else {
    final topic = pick(r, topics);
    await _tapRailPill(j, topic, RegExp('^(${topics.map(RegExp.escape).join('|')})\$'));
    final rows = _list(j);
    j.check(
      j.c.read(selectedCategoryProvider) == topic,
      'topic "$topic" selected',
    );
    j.check(
      rows.length == counts[topic] &&
          rows.isNotEmpty &&
          rows.length < all &&
          rows.every((s) => sermonTopic(s) == topic),
      'topic "$topic" narrows $all to ${counts[topic]} of that topic '
      '(got ${rows.length})',
    );
    await j.shot('topic-$topic');
    await openMessagesReset(j);
  }

  // ── Series ───────────────────────────────────────────────────────────────
  final series = j.c.read(seriesListProvider);
  if (series.isEmpty) {
    j.note('DATA: no message in the library carries a series');
    j.check(
      find.text('Series').evaluate().isEmpty,
      'no Series rail when nothing has a series',
    );
  } else {
    final s = pick(r, series.take(12).toList());
    await _tapRailPill(j, '${s.name} (${s.count})', RegExp(r'^.+ \(\d+\)$'));
    final rows = _list(j);
    j.check(
      rows.length == s.count && rows.every((x) => x.series == s.name),
      'series "${s.name}" lists its ${s.count} messages (got ${rows.length})',
    );
    await j.shot('series');
    await openMessagesReset(j);
  }

  // ── Year ─────────────────────────────────────────────────────────────────
  final years = j.c.read(archiveYearsProvider);
  final yearCounts = j.c.read(archiveYearCountsProvider);
  final yearsFromApiData = lib.sermons
      .map((s) => s.publishedAt?.year)
      .whereType<int>()
      .toSet();
  j.check(
    years.toSet().containsAll(yearsFromApiData),
    'year rail offers every year in the archive ($years)',
  );
  if (years.length > 1) {
    final year = pick(r, years);
    await _tapRailPill(
      j,
      '$year (${yearCounts[year]})',
      RegExp(r'^(All years|\d{4} \(\d+\))$'),
    );
    final rows = _list(j);
    final expected = lib.sermons.where((s) => s.publishedAt?.year == year).length;
    j.check(
      rows.length == expected && rows.every((s) => s.publishedAt?.year == year),
      '$year filter lists the $expected messages dated $year (got ${rows.length})',
    );
    j.check(
      find.text('All messages \u00b7 $year').evaluate().isNotEmpty,
      'list header reads "All messages · $year"',
    );
    await j.shot('year-$year');
    await openMessagesReset(j);
  }

  // ── Sort ─────────────────────────────────────────────────────────────────
  bool ordered(List<Sermon> rows, {required bool ascending}) {
    final dates = rows.map((s) => s.publishedAt).whereType<DateTime>().toList();
    for (var i = 1; i < dates.length; i++) {
      final c = dates[i - 1].compareTo(dates[i]);
      if (ascending ? c > 0 : c < 0) return false;
    }
    return dates.length > 1;
  }

  final oldest = find.text('Oldest');
  await scrollUntilFound(t, oldest, scrollable: messagesScroll, step: const Offset(0, -150));
  await t.tap(oldest.first, warnIfMissed: false);
  await pumpFor(t, const Duration(seconds: 2));
  j.check(ordered(_list(j), ascending: true), 'Oldest lists oldest first');
  await scrollUntilFound(t, find.byType(SermonListItem), scrollable: messagesScroll);
  final firstPainted = t.widget<SermonListItem>(find.byType(SermonListItem).first);
  j.check(
    firstPainted.title == _list(j).first.title,
    'first row is the oldest message "${_list(j).first.title}" '
    '(painted "${firstPainted.title}")',
  );
  await j.shot('sort-oldest');
  final newest = find.text('Newest');
  await scrollUntilFound(t, newest, scrollable: messagesScroll, step: const Offset(0, 150));
  await t.tap(newest.first, warnIfMissed: false);
  await pumpFor(t, const Duration(seconds: 2));
  j.check(ordered(_list(j), ascending: false), 'Newest lists newest first');

  // ── Pull to refresh ──────────────────────────────────────────────────────
  await openMessagesReset(j);
  final before = j.c.read(sermonLibraryProvider).fetchedAt;
  await t.fling(messagesScroll, const Offset(0, 500), 1200, warnIfMissed: false);
  final spun = await pumpUntil(
    t,
    () => find.byType(RefreshProgressIndicator).evaluate().isNotEmpty,
    timeout: const Duration(seconds: 3),
    step: const Duration(milliseconds: 50),
  );
  j.check(spun, 'pull down shows the refresh indicator');
  j.check(
    await pumpUntil(
      t,
      () {
        final after = j.c.read(sermonLibraryProvider).fetchedAt;
        return after != null && (before == null || after.isAfter(before));
      },
      timeout: const Duration(seconds: 45),
    ),
    'pull to refresh refetches the library '
    '($before -> ${j.c.read(sermonLibraryProvider).fetchedAt})',
  );
  j.check(
    await waitArchiveHydrated(j) &&
        j.c.read(sermonLibraryProvider).sermons.length == apiCount,
    'archive still holds $apiCount after refresh',
  );
  await j.shot('refreshed');
}
