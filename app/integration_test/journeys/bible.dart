import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kharis_app/features/home/data/bible_reference.dart';
import 'package:kharis_app/features/home/data/bible_repository.dart';
import 'package:kharis_app/features/home/presentation/screens/bible_books_screen.dart';
import 'package:kharis_app/features/home/presentation/screens/reading_screen.dart';
import 'package:kharis_app/shared/providers/bible_provider.dart';
import 'package:kharis_app/shared/providers/sermon_provider.dart';

import '../support/actions.dart';
import '../support/harness.dart';
import '../support/live_data.dart';

Finder _inReader(Finder f) =>
    find.descendant(of: find.byType(ReadingScreen), matching: f);

/// The reference heading ("John 3", "John 3:16") without the chevron.
String _label(WidgetTester t) {
  final ref = _inReader(find.byKey(const Key('bible-reference')));
  if (ref.evaluate().isEmpty) return '';
  return paintedTexts(within: ref)
      .join()
      // No-break space, the chevron's placeholder and its icon-font glyph.
      .replaceAll(RegExp(r'[\u00A0\uFFFC\uE000-\uF8FF]'), '')
      .trim();
}

Future<bool> _passageLoaded(Journey j) async {
  final t = j.tester;
  return pumpUntil(
    t,
    () =>
        _inReader(find.byType(CircularProgressIndicator)).evaluate().isEmpty &&
        _label(t).isNotEmpty &&
        (paintedTexts(
              within: find.byType(ReadingScreen),
            ).where((s) => s.length > 60).isNotEmpty ||
            _inReader(
              find.text('This passage isn\u2019t available'),
            ).evaluate().isNotEmpty),
    timeout: const Duration(seconds: 45),
  );
}

/// Opens the book list from the reference and picks [title] chapter [chapter].
Future<void> _pickChapter(
  Journey j,
  String title,
  int chapters,
  int chapter,
) async {
  final t = j.tester;
  // A verse search scrolls the passage: bring the heading back first.
  await tapVisible(t, _inReader(find.byKey(const Key('bible-reference'))));
  await pumpUntilFound(t, find.byType(BibleBooksScreen));
  final books = verticalScrollableIn(find.byType(BibleBooksScreen));
  final row = find.descendant(
    of: find.byType(BibleBooksScreen),
    matching: find.text(title),
  );
  // The list opens scrolled to the current book: search both directions.
  final end = DateTime.now().add(const Duration(seconds: 40));
  var dir = -400.0;
  var lastFirst = '';
  while (row.evaluate().isEmpty && DateTime.now().isBefore(end)) {
    await t.drag(books.first, Offset(0, dir), warnIfMissed: false);
    await pumpFor(t, const Duration(milliseconds: 250));
    final first = paintedTexts(
      within: find.byType(BibleBooksScreen),
    ).take(3).join('|');
    if (first == lastFirst) dir = -dir; // hit an end: turn round
    lastFirst = first;
  }
  await tapVisible(t, row);
  if (chapters > 1) {
    final cell = find.byKey(Key('bible-chapter-$chapter'));
    await pumpUntilFound(t, find.byType(BibleChaptersScreen));
    await scrollUntilFound(
      t,
      cell,
      scrollable: verticalScrollableIn(find.byType(BibleChaptersScreen)),
    );
    await t.tap(cell, warnIfMissed: false);
  }
  await pumpUntil(
    t,
    () =>
        find.byType(BibleBooksScreen).evaluate().isEmpty &&
        find.byType(BibleChaptersScreen).evaluate().isEmpty,
  );
  await _passageLoaded(j);
}

Future<void> _tapStep(Journey j, String key) async {
  final t = j.tester;
  final step = _inReader(find.byKey(Key(key)));
  await scrollUntilFound(
    t,
    step,
    scrollable: verticalScrollableIn(find.byType(ReadingScreen)),
    step: const Offset(0, -600),
    timeout: const Duration(seconds: 60),
  );
  await t.tap(step, warnIfMissed: false);
  await pumpFor(t, const Duration(milliseconds: 500));
  await _passageLoaded(j);
}

/// (g) Bible: opens on today's reading; "John 3:16" search highlights the
/// verse; a random book + chapter from the picker; previous / next across a
/// book boundary; another translation, then NIV again.
Future<void> bibleJourney(Journey j) async {
  final t = j.tester;
  final r = seeded(effectiveSeed, 'bible');
  final books = (await youVersionBooks(
    111,
  )).where((b) => b.chapters > 0).toList();
  j.check(
    books.length >= 66,
    'YouVersion NIV lists the books (${books.length})',
  );

  await j.launch();
  await openMoreRow(t, 'Bible');
  await pumpUntilFound(t, find.byType(ReadingScreen));

  // ── Today's reading ──────────────────────────────────────────────────────
  await pumpUntil(
    t,
    () =>
        j.c.read(dailyContentProvider).hasValue ||
        j.c.read(dailyContentProvider).hasError,
  );
  final daily = j.c.read(dailyContentProvider);
  final content = daily.valueOrNull;
  if (content == null) {
    final title = daily.hasError
        ? 'Couldn\u2019t load today\u2019s reading'
        : 'No reading today';
    j.check(
      _inReader(find.text(title)).evaluate().isNotEmpty,
      'no daily content: the reader says so and offers to browse',
    );
  } else {
    final index = BibleIndex.bundled();
    final reference = content.reading?.reference ?? '';
    final want = reference.isEmpty
        ? null
        : switch (parseBibleReference(reference, index)) {
            ReferenceFound(:final location) => location,
            ReferenceError() => null,
          };
    if (want == null) {
      j.check(
        _inReader(
          find.byKey(const Key('reading-today-text')),
        ).evaluate().isNotEmpty,
        'a reading without a passage shows the Studio\u2019s text',
      );
    } else {
      j.check(await _passageLoaded(j), 'today\u2019s passage loads');
      final label = _label(t);
      final shown = parseBibleReference(label, index);
      j.check(
        shown is ReferenceFound && shown.location == want,
        'opens on today\u2019s reading $reference (shows "$label")',
      );
      j.check(
        _inReader(find.text('TODAY\u2019S READING')).evaluate().isNotEmpty,
        'marked as today\u2019s reading',
      );
    }
  }
  await j.shot('today');

  // ── Search John 3:16 ─────────────────────────────────────────────────────
  await t.tap(
    _inReader(find.byKey(const Key('bible-search'))),
    warnIfMissed: false,
  );
  await pumpUntilFound(t, find.byKey(const Key('bible-search-field')));
  await t.enterText(find.byKey(const Key('bible-search-field')), 'John 3:16');
  // The sheet rides above the keyboard; close it so Go is where it is drawn.
  FocusManager.instance.primaryFocus?.unfocus();
  await pumpFor(t, const Duration(milliseconds: 800));
  await tapVisible(t, find.byKey(const Key('bible-search-go')));
  await pumpUntil(
    t,
    () => _label(t) == 'John 3:16',
    timeout: const Duration(seconds: 20),
  );
  j.check(
    _label(t) == 'John 3:16',
    'search lands on "John 3:16" (shows "${_label(t)}")',
  );
  await _passageLoaded(j);
  await pumpFor(t, const Duration(seconds: 1));
  final lit = <String>[];
  for (final e in _inReader(find.byType(RichText)).evaluate()) {
    (e.widget as RichText).text.visitChildren((span) {
      if (span is TextSpan &&
          span.style?.backgroundColor != null &&
          span.text != null) {
        lit.add(span.text!);
      }
      return true;
    });
  }
  final litText = lit.join();
  j.check(
    litText.contains('16') &&
        litText.replaceAll(RegExp(r'\d'), '').trim().length > 30,
    'verse 16 is highlighted ("${litText.length > 60 ? litText.substring(0, 60) : litText}…")',
  );
  await j.shot('john-3-16');

  // ── Random book + chapter ────────────────────────────────────────────────
  final book = pick(r, books);
  final chapter = 1 + r.nextInt(book.chapters);
  j.note('random browse: ${book.title} $chapter');
  await _pickChapter(j, book.title, book.chapters, chapter);
  j.check(
    _label(t) == '${book.title} $chapter',
    'picker opens ${book.title} $chapter (shows "${_label(t)}")',
  );
  await j.shot('random-chapter');

  // ── Across a book boundary ───────────────────────────────────────────────
  final i = r.nextInt(books.length - 1);
  final a = books[i];
  final b = books[i + 1];
  j.note('boundary: ${a.title} ${a.chapters} -> ${b.title} 1');
  await _pickChapter(j, a.title, a.chapters, a.chapters);
  j.check(
    _label(t) == '${a.title} ${a.chapters}',
    'at ${a.title} ${a.chapters}',
  );
  await _tapStep(j, 'bible-next');
  j.check(
    _label(t) == '${b.title} 1',
    'Next from the last chapter of ${a.title} opens ${b.title} 1 (shows "${_label(t)}")',
  );
  await j.shot('boundary-next');
  await _tapStep(j, 'bible-prev');
  j.check(
    _label(t) == '${a.title} ${a.chapters}',
    'Previous from ${b.title} 1 returns to ${a.title} ${a.chapters} (shows "${_label(t)}")',
  );

  // ── Translation ──────────────────────────────────────────────────────────
  final offered = (await youVersionBibles()).where((v) => v.id != 111).toList();
  final before = j.c.read(selectedBibleProvider);
  j.check(
    before.id == 111,
    'NIV is the default version (got ${before.abbreviation})',
  );
  Future<void> chooseVersion(int id) async {
    final current = j.c.read(selectedBibleProvider).abbreviation;
    // The pill heads the passage; the chapter steps left it scrolled away.
    await tapVisible(t, _inReader(find.text(current)));
    await pumpUntilFound(
      t,
      find.text('BIBLE VERSION'),
      reason: 'version sheet',
    );
    final tile = find.byKey(Key('bible-version-$id'));
    await scrollUntilFound(
      t,
      tile,
      scrollable: find
          .ancestor(
            of: find.text('BIBLE VERSION'),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await t.tap(tile, warnIfMissed: false);
    await pumpUntil(t, () => find.text('BIBLE VERSION').evaluate().isEmpty);
    await _passageLoaded(j);
  }

  if (offered.isEmpty) {
    j.note('DATA: YouVersion offers no other English version to this key');
  } else {
    final other = offered[Random(effectiveSeed).nextInt(offered.length)];
    j.note('translation this run: ${other.abbreviation} (${other.id})');
    await chooseVersion(other.id);
    final now = j.c.read(selectedBibleProvider);
    j.check(
      now.id == other.id,
      'version switched to ${other.abbreviation} (now ${now.abbreviation})',
    );
    j.check(
      _inReader(find.text(now.abbreviation)).evaluate().isNotEmpty,
      'version pill reads "${now.abbreviation}"',
    );
    j.check(
      prefs.getInt('bible_version_id') == other.id,
      'choice saved on the device',
    );
    if (_inReader(
      find.text('This passage isn\u2019t available'),
    ).evaluate().isNotEmpty) {
      j.note(
        '${other.abbreviation} has no ${a.title} ${a.chapters}; the reader says so',
      );
    }
    await j.shot('other-version');
    await chooseVersion(111);
  }
  final restored = j.c.read(selectedBibleProvider);
  j.check(restored.id == 111, 'NIV restored (now ${restored.abbreviation})');
  j.check(
    prefs.getInt('bible_version_id') == 111 ||
        prefs.getInt('bible_version_id') == null,
    'NIV saved on the device',
  );
  await j.shot('niv-restored');
}
