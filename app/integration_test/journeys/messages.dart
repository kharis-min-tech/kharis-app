import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kharis_app/features/messages/presentation/message_list.dart';
import 'package:kharis_app/features/messages/presentation/screens/message_search_screen.dart';
import 'package:kharis_app/shared/models/sermon.dart';
import 'package:kharis_app/shared/providers/sermon_provider.dart';
import 'package:kharis_app/ui/components/components.dart';

import '../support/actions.dart';
import '../support/harness.dart';
import '../support/live_data.dart';

Finder get _search => find.byType(MessageSearchScreen);

Finder _inSearch(Finder f) => find.descendant(of: _search, matching: f);

Finder get _filterSheet => find.byWidgetPredicate((w) => w is KFilterSheet);

/// Opens Search from the Messages header with an empty field and no filter.
Future<void> _openSearch(Journey j) async {
  final t = j.tester;
  if (_search.evaluate().isNotEmpty) await _closeSearch(j);
  await openMessagesReset(j);
  await tapVisible(t, find.byKey(const Key('messages-search')));
  await pumpUntilFound(t, _search, reason: 'Search');
  await pumpFor(t, const Duration(milliseconds: 600));
}

Future<void> _closeSearch(Journey j) async {
  final t = j.tester;
  FocusManager.instance.primaryFocus?.unfocus();
  await pumpFor(t, const Duration(milliseconds: 400));
  await goBack(j.tester);
  await pumpUntil(t, () => _search.evaluate().isEmpty);
}

Future<void> _type(Journey j, String query) async {
  final t = j.tester;
  final field = _inSearch(
    find.descendant(
      of: find.byKey(const Key('search-field')),
      matching: find.byType(EditableText),
    ),
  );
  // Focus first: after the keyboard was closed, entering text straight away
  // can reach the previously attached input connection.
  await t.tap(field, warnIfMissed: false);
  await pumpFor(t, const Duration(milliseconds: 500));
  await t.enterText(field, query);
  await pumpFor(t, const Duration(milliseconds: 400));
}

/// The result count Search shows ("12 messages · Sorted by …"); null while
/// it shows none.
int? _shownCount(WidgetTester t) {
  final count = _inSearch(find.byKey(const Key('search-count')));
  if (count.evaluate().isEmpty) return null;
  final m = RegExp(
    r'^([\d,]+) messages?',
  ).firstMatch(t.widget<Text>(count).data ?? '');
  return m == null ? null : int.parse(m.group(1)!.replaceAll(',', ''));
}

/// The messages Search lists, in order.
List<Sermon> _rows(WidgetTester t) => [
  for (final e in _inSearch(
    find.byType(MessageRow, skipOffstage: false),
  ).evaluate())
    (e.widget as MessageRow).sermon,
];

/// Taps the [chip] filter, picks [label] in its sheet and applies it.
Future<void> _filter(Journey j, String chip, String label) async {
  final t = j.tester;
  FocusManager.instance.primaryFocus?.unfocus();
  await pumpFor(t, const Duration(milliseconds: 400));
  // The chip row scrolls sideways and builds lazily: start from its left
  // end and scroll on until the chip is built.
  final chips = find.descendant(
    of: find.byKey(const Key('search-filters')),
    matching: find.byType(Scrollable),
  );
  final chipFinder = _inSearch(find.byKey(ValueKey('search-filter-$chip')));
  if (chips.evaluate().isNotEmpty) {
    t.state<ScrollableState>(chips.first).position.jumpTo(0);
    await pumpFor(t, const Duration(milliseconds: 300));
    await scrollUntilFound(
      t,
      chipFinder,
      scrollable: chips.first,
      step: const Offset(-150, 0),
    );
  }
  await tapVisible(t, chipFinder);
  await pumpUntilFound(t, _filterSheet, reason: '$chip sheet');
  final option = find.descendant(of: _filterSheet, matching: find.text(label));
  await scrollUntilFound(
    t,
    option,
    scrollable: verticalScrollableIn(_filterSheet),
    step: const Offset(0, -150),
  );
  await tapVisible(t, option);
  await tapVisible(
    t,
    find.descendant(of: _filterSheet, matching: find.text('Show results')),
  );
  await pumpUntil(t, () => _filterSheet.evaluate().isEmpty);
  await pumpFor(t, const Duration(seconds: 1));
}

/// (d) Messages: the archive hydrates to the live API total; Search finds a
/// word from a live title and shows the empty state for nonsense; its Theme,
/// Series and Date filters each narrow the archive to what they say, and
/// Themes / Series browse the same groups; Sort orders by Oldest / Newest;
/// pull to refresh refetches.
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
  final words =
      RegExp(
          r'[A-Za-z]{6,}',
        ).allMatches('${probe['title']}').map((m) => m.group(0)!).toList()
        ..sort((a, b) => b.length.compareTo(a.length));
  final query = words.first;
  j.note('search probe: "$query" from "${probe['title']}" (${probe['id']})');
  await _openSearch(j);
  await _type(j, query);
  final found = await pumpUntil(
    t,
    () => (_shownCount(t) ?? 0) > 0 && !j.c.read(searchLoadingProvider),
    timeout: const Duration(seconds: 30),
  );
  final results = j.c.read(searchResultsProvider);
  j.check(found, '"$query" reports results (${_shownCount(t)})');
  j.check(
    results.any((s) => s.id == '${probe['id']}'),
    'results include "${probe['title']}"',
  );
  j.check(
    results.every(
      (s) =>
          sermonMatchesQuery(s, query) ||
          j.c.read(remoteSearchProvider).results.any((r) => r.id == s.id),
    ),
    'every result matches "$query" in the library or is a server hit',
  );
  final libraryHits = lib.sermons.where((s) => sermonMatchesQuery(s, query));
  j.check(
    libraryHits.every((s) => results.any((r) => r.id == s.id)),
    'every library message matching "$query" is listed',
  );
  FocusManager.instance.primaryFocus?.unfocus();
  await j.shot('search-hit');

  const nonsense = 'zxqvj plorbft 7731';
  await _type(j, nonsense);
  j.check(
    await pumpUntil(
      t,
      () =>
          _inSearch(find.byKey(const Key('search-empty'))).evaluate().isNotEmpty,
      timeout: const Duration(seconds: 60),
    ),
    'nonsense query shows "No messages found"',
  );
  FocusManager.instance.primaryFocus?.unfocus();
  await j.shot('search-empty');
  await _type(j, '');
  await _closeSearch(j);
  final all = lib.sermons.length;

  // ── Theme ────────────────────────────────────────────────────────────────
  final counts = j.c.read(categoryCountsProvider);
  final topics = j.c
      .read(categoryLabelsProvider)
      .where((l) => l != 'All' && (counts[l] ?? 0) > 0)
      .toList();
  if (topics.isEmpty) {
    j.check(false, 'the library has at least one theme with messages');
  } else {
    final topic = pick(r, topics);
    await _openSearch(j);
    await _filter(j, 'theme', topic);
    final rows = _rows(t);
    j.check(
      _shownCount(t) == counts[topic] &&
          rows.isNotEmpty &&
          counts[topic]! < all &&
          rows.every((s) => sermonTopic(s) == topic),
      'theme "$topic" narrows $all to ${counts[topic]} of that theme '
      '(shows ${_shownCount(t)})',
    );
    j.check(
      _inSearch(
        find.descendant(
          of: find.byKey(const ValueKey('search-filter-theme')),
          matching: find.text(topic),
        ),
      ).evaluate().isNotEmpty,
      'the Theme chip reads "$topic"',
    );
    await j.shot('theme-$topic');
    await _closeSearch(j);

    // The Themes tab lists the same theme with the same messages.
    await _openGroup(j, 'Themes', topic, counts[topic]!);
  }

  // ── Series ───────────────────────────────────────────────────────────────
  final series = j.c.read(seriesListProvider);
  if (series.isEmpty) {
    j.note('DATA: no message in the library carries a series');
  } else {
    final s = pick(r, series.take(12).toList());
    await _openSearch(j);
    await _filter(j, 'series', s.name);
    final rows = _rows(t);
    j.check(
      _shownCount(t) == s.count && rows.every((x) => x.series == s.name),
      'series "${s.name}" lists its ${s.count} messages '
      '(shows ${_shownCount(t)})',
    );
    await j.shot('series');
    await _closeSearch(j);
    await _openGroup(j, 'Series', s.name, s.count);
  }

  // ── Date ─────────────────────────────────────────────────────────────────
  final years = j.c.read(archiveYearsProvider);
  final yearsFromApiData = lib.sermons
      .map((s) => s.publishedAt?.year)
      .whereType<int>()
      .toSet();
  j.check(
    years.toSet().containsAll(yearsFromApiData),
    'Date offers every year in the archive ($years)',
  );
  if (years.length > 1) {
    final year = pick(r, years);
    await _openSearch(j);
    await _filter(j, 'date', '$year');
    final expected = lib.sermons
        .where((s) => s.publishedAt?.year == year)
        .length;
    j.check(
      _shownCount(t) == expected &&
          _rows(t).every((s) => s.publishedAt?.year == year),
      '$year lists the $expected messages dated $year '
      '(shows ${_shownCount(t)})',
    );
    await j.shot('year-$year');

    // ── Sort ───────────────────────────────────────────────────────────────
    bool ordered(List<Sermon> rows, {required bool ascending}) {
      final dates = rows
          .map((s) => s.publishedAt)
          .whereType<DateTime>()
          .toList();
      for (var i = 1; i < dates.length; i++) {
        final c = dates[i - 1].compareTo(dates[i]);
        if (ascending ? c > 0 : c < 0) return false;
      }
      return dates.length > 1;
    }

    final inYear = lib.sermons.where((s) => s.publishedAt?.year == year);
    final oldest = inYear.reduce(
      (a, b) => a.publishedAt!.isAfter(b.publishedAt!) ? b : a,
    );
    await _filter(j, 'sort', SearchSort.oldest.label);
    j.check(
      ordered(_rows(t), ascending: true),
      'Oldest first lists oldest first',
    );
    j.check(
      _inSearch(find.text(SearchSort.oldest.label)).evaluate().isNotEmpty,
      'the Sort chip reads "Oldest first"',
    );
    final first = _rows(t).firstOrNull;
    j.check(
      first?.publishedAt == oldest.publishedAt,
      'first row is the oldest message of $year "${oldest.title}" '
      '(painted "${first?.title}")',
    );
    await j.shot('sort-oldest');
    await _filter(j, 'sort', SearchSort.newest.label);
    j.check(
      ordered(_rows(t), ascending: false),
      'Newest first lists newest first',
    );
    await _closeSearch(j);
  }

  // ── Pull to refresh ──────────────────────────────────────────────────────
  await openMessagesReset(j);
  final before = j.c.read(sermonLibraryProvider).fetchedAt;
  await t.fling(
    messagesScroll,
    const Offset(0, 500),
    1200,
    warnIfMissed: false,
  );
  final spun = await pumpUntil(
    t,
    () => find.byType(RefreshProgressIndicator).evaluate().isNotEmpty,
    timeout: const Duration(seconds: 3),
    step: const Duration(milliseconds: 50),
  );
  j.check(spun, 'pull down shows the refresh indicator');
  j.check(
    await pumpUntil(t, () {
      final after = j.c.read(sermonLibraryProvider).fetchedAt;
      return after != null && (before == null || after.isAfter(before));
    }, timeout: const Duration(seconds: 45)),
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

/// Messages' [tab] (Themes / Series) lists [name] with its [count] messages
/// and opens the list of them.
Future<void> _openGroup(Journey j, String tab, String name, int count) async {
  final t = j.tester;
  await openMessagesReset(j);
  await tapVisible(
    t,
    find.descendant(of: messagesTabs, matching: find.text(tab)),
  );
  final row = find.byKey(ValueKey('group-$name'));
  await scrollUntilFound(t, row, scrollable: messagesScroll);
  final n = count == 1 ? '1 message' : '$count messages';
  j.check(
    find.descendant(of: row, matching: find.text(n)).evaluate().isNotEmpty,
    '$tab lists "$name" with $n',
  );
  await tapVisible(t, row);
  final list = find.byType(MessageListScreen);
  await pumpUntilFound(t, list);
  final shown = t.widget<MessageListScreen>(list).sermons.length;
  j.check(shown == count, '"$name" opens its $count messages (got $shown)');
  await j.shot('${tab.toLowerCase()}-list');
  await goBack(t);
  await pumpUntil(t, () => list.evaluate().isEmpty);
}
