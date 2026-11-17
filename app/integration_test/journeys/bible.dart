import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kharis_app/features/bible/presentation/screens/bible_screen.dart';
import 'package:kharis_app/features/bible/presentation/screens/reading_screen.dart';
import 'package:kharis_app/features/bible/presentation/widgets/passage_picker.dart';
import 'package:kharis_app/features/home/data/bible_reference.dart';
import 'package:kharis_app/features/home/data/bible_repository.dart';
import 'package:kharis_app/shared/providers/bible_provider.dart';
import 'package:kharis_app/shared/providers/sermon_provider.dart';
import 'package:kharis_app/ui/components/components.dart';

import '../support/harness.dart';
import '../support/live_data.dart';

Finder _inReader(Finder f) =>
    find.descendant(of: find.byType(ReadingScreen), matching: f);

Finder get _picker => find.byType(PassagePicker);

/// The chapter heading over the verses ("John 3").
String _label(WidgetTester t) {
  final title = _inReader(find.byKey(const Key('bible-chapter-title')));
  if (title.evaluate().isEmpty) return '';
  return t.widget<Text>(title.first).data ?? '';
}

/// The verse numbers marked in the open chapter (a searched or linked verse).
Set<int> _markedVerses(WidgetTester t) => {
  for (final e in _inReader(find.byType(KVerse)).evaluate())
    for (final p in (e.widget as KVerse).parts)
      if (p.marked && p.number != null) p.number!,
};

Future<bool> _passageLoaded(Journey j) async {
  final t = j.tester;
  return pumpUntil(
    t,
    () =>
        _inReader(find.byKey(const Key('bible-loading'))).evaluate().isEmpty &&
        _label(t).isNotEmpty &&
        (_inReader(find.byKey(const Key('bible-text'))).evaluate().isNotEmpty ||
            _inReader(
              find.text('This passage isn\u2019t available'),
            ).evaluate().isNotEmpty),
    timeout: const Duration(seconds: 45),
  );
}

/// In the open passage picker, picks [usfm] ([title]) chapter [chapter].
Future<void> _chooseInPicker(
  Journey j,
  String usfm,
  int chapters,
  int chapter, {
  required bool newTestament,
}) async {
  final t = j.tester;
  await pumpUntilFound(t, _picker);
  final sheet = verticalScrollableIn(_picker);
  final testament = find.byKey(
    Key('bible-testament-${newTestament ? 'newTestament' : 'old'}'),
  );
  if (testament.evaluate().isNotEmpty) {
    await tapVisible(t, testament);
    await pumpFor(t, const Duration(milliseconds: 400));
  }
  final book = find.byKey(Key('bible-book-$usfm'));
  await scrollUntilFound(t, book, scrollable: sheet);
  // On a loaded device the tap can land while the list is still settling
  // and be swallowed; the chapter grid would then still be the previous
  // book's. Wait for the chip to show the book chosen, tapping again once.
  bool chosen() => t.widget<KChip>(book).selected;
  await tapVisible(t, book);
  if (!await pumpUntil(t, chosen, timeout: const Duration(seconds: 5))) {
    await tapVisible(t, book);
    await pumpUntil(t, chosen, timeout: const Duration(seconds: 5));
  }
  if (chapters > 1) {
    final cell = find.byKey(Key('bible-chapter-$chapter'));
    await scrollUntilFound(t, cell, scrollable: sheet);
    await tapVisible(t, cell);
  }
  await pumpUntil(t, () => _picker.evaluate().isEmpty);
  await _passageLoaded(j);
}

/// Opens the picker from the reader's reference and picks a chapter.
Future<void> _pickChapter(
  Journey j,
  ({String usfm, String title, int chapters}) book,
  int chapter, {
  required bool newTestament,
}) async {
  await tapVisible(
    j.tester,
    _inReader(find.byKey(const Key('bible-reference'))),
  );
  await _chooseInPicker(
    j,
    book.usfm,
    book.chapters,
    chapter,
    newTestament: newTestament,
  );
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

/// (g) Bible: the Bible tab's Daily reading opens on today's reading;
/// "John 3:16" search marks the verse; a random book + chapter from the
/// picker; previous / next across a book boundary; another translation, then
/// NIV again; a chapter chosen away from today offers the way back to
/// today's reading. The landing screen's picker opens a chapter, Done on it
/// stays on the landing screen, the swipe back returns there and Continue
/// reading offers that chapter; its search field opens a verse.
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
  final ntStart = books.indexWhere((b) => b.usfm == 'MAT');
  bool isNt(({String usfm, String title, int chapters}) b) =>
      ntStart >= 0 && books.indexOf(b) >= ntStart;

  await j.launch();
  await tapNav(t, 'Bible');
  await pumpUntilFound(t, find.byType(BibleScreen));

  // ── Today's reading ──────────────────────────────────────────────────────
  await pumpUntil(
    t,
    () =>
        j.c.read(dailyContentProvider).hasValue ||
        j.c.read(dailyContentProvider).hasError,
  );
  final daily = j.c.read(dailyContentProvider);
  final content = daily.valueOrNull;
  final card = find.byKey(const Key('bible-daily-reading'));
  if (content?.reading == null) {
    await pumpFor(t, const Duration(seconds: 1));
    j.check(
      card.evaluate().isEmpty,
      'no daily reading: the Bible tab leaves the Daily reading card out',
    );
    j.note('DATA: no daily reading today; the reader opens on John 3');
    unawaited(appRouter(t).push('/bible/reading'));
  } else {
    await tapVisible(t, card);
  }
  await pumpUntilFound(t, find.byType(ReadingScreen));
  if (content?.reading != null) {
    final index = BibleIndex.bundled();
    final reference = content!.reading!.reference;
    // A reading can name several passages ("Romans 8:1-11; Psalm 23"); the
    // reader opens on the first, as the app does.
    final passages = reference.isEmpty
        ? const <BibleLocation>[]
        : parseReadingReferences(reference, index);
    final want = passages.isEmpty ? null : passages.first;
    if (passages.length > 1) {
      j.note('today names ${passages.length} passages: $reference');
      j.check(
        _inReader(find.byKey(const Key('reading-parts'))).evaluate().isNotEmpty,
        'a reading with several passages offers each one',
      );
    }
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
      j.check(
        label == index.label(want.wholeChapter),
        'opens on today\u2019s reading $reference (shows "$label")',
      );
      if (want.verseStart != null) {
        final marked = _markedVerses(t);
        j.check(
          marked.contains(want.verseStart),
          'today\u2019s verses are marked ($marked)',
        );
      }
      j.check(
        _inReader(find.text('TODAY\u2019S READING')).evaluate().isNotEmpty,
        'marked as today\u2019s reading',
      );
    }
  }
  await j.shot('today');

  // ── Search John 3:16 ─────────────────────────────────────────────────────
  await tapVisible(t, _inReader(find.byKey(const Key('bible-search'))));
  await pumpUntilFound(t, find.byKey(const Key('bible-search-field')));
  await t.enterText(find.byKey(const Key('bible-search-field')), 'John 3:16');
  // The sheet rides above the keyboard; close it so Go is where it is drawn.
  FocusManager.instance.primaryFocus?.unfocus();
  await pumpFor(t, const Duration(milliseconds: 800));
  await tapVisible(t, find.byKey(const Key('bible-search-go')));
  await pumpUntil(
    t,
    () => _label(t) == 'John 3',
    timeout: const Duration(seconds: 20),
  );
  await _passageLoaded(j);
  j.check(
    _label(t) == 'John 3',
    'search lands on John 3 (shows "${_label(t)}")',
  );
  await pumpFor(t, const Duration(seconds: 1));
  final marked = _markedVerses(t);
  j.check(
    marked.length == 1 && marked.contains(16),
    'verse 16 is marked (marked: $marked)',
  );
  j.check(
    _inReader(find.byKey(const Key('bible-today'))).evaluate().isNotEmpty,
    'away from today\u2019s reading, the reader offers the way back',
  );
  await j.shot('john-3-16');

  // ── Random book + chapter ────────────────────────────────────────────────
  final book = pick(r, books);
  final chapter = 1 + r.nextInt(book.chapters);
  j.note('random browse: ${book.title} $chapter');
  await _pickChapter(j, book, chapter, newTestament: isNt(book));
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
  await _pickChapter(j, a, a.chapters, newTestament: isNt(a));
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
  // The picker offers only church-approved translations the key is licensed
  // for; everything else YouVersion lists must stay out of the picker.
  final licensed = await youVersionBibles();
  final offered = licensed
      .where((v) => v.id != 111)
      .where((v) => BibleRepository.approvedBibleIds.contains(v.id))
      .toList();
  final notApproved = licensed
      .where((v) => !BibleRepository.approvedBibleIds.contains(v.id))
      .toList();
  final before = j.c.read(selectedBibleProvider);
  j.check(
    before.id == 111,
    'NIV is the default version (got ${before.abbreviation})',
  );
  Future<void> chooseVersion(int id) async {
    await tapVisible(t, _inReader(find.byKey(const Key('bible-reference'))));
    await pumpUntilFound(t, _picker, reason: 'passage picker');
    final sheet = verticalScrollableIn(_picker);
    final tile = find.byKey(Key('bible-version-$id'));
    await scrollUntilFound(t, tile, scrollable: sheet);
    final listed = j.c.read(biblesProvider).valueOrNull ?? const [];
    j.check(
      listed.every((v) => BibleRepository.approvedBibleIds.contains(v.id)) &&
          notApproved.every(
            (v) => find.byKey(Key('bible-version-${v.id}')).evaluate().isEmpty,
          ),
      'picker lists only approved versions '
      '(${listed.map((v) => v.abbreviation).join(', ')})',
    );
    await tapVisible(t, tile);
    await pumpUntil(t, () => j.c.read(selectedBibleProvider).id == id);
    // Choosing a version leaves the sheet open; Done closes it.
    await tapVisible(t, find.byKey(const Key('passage-picker-done')));
    await pumpUntil(t, () => _picker.evaluate().isEmpty);
    await _passageLoaded(j);
  }

  String toolbarVersion() => paintedTexts(
    within: _inReader(find.byKey(const Key('bible-toolbar'))),
  ).join(' ');

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
      toolbarVersion().contains(now.abbreviation),
      'the toolbar reads "${now.abbreviation}" ("${toolbarVersion()}")',
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

  // ── KJV, bundled in the app (public domain) ──────────────────────────────
  if (licensed.any((v) => v.id == 1)) {
    j.note('DATA: YouVersion licenses KJV to this key; it serves KJV');
  } else {
    await chooseVersion(1);
    j.check(
      j.c.read(selectedBibleProvider).id == 1,
      'KJV can be chosen (bundled, not on the YouVersion key)',
    );
    final john = books.firstWhere((b) => b.usfm == 'JHN');
    await _pickChapter(j, john, 3, newTestament: true);
    final text = paintedTexts(
      within: _inReader(find.byKey(const Key('bible-text'))),
    ).join(' ');
    j.check(
      _label(t) == 'John 3' && text.contains('only begotten Son'),
      'KJV John 3 reads "his only begotten Son" (shows "${_label(t)}")',
    );
    j.check(
      toolbarVersion().contains('KJV'),
      'the toolbar reads "KJV" ("${toolbarVersion()}")',
    );
    await j.shot('kjv');
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

  // ── Back to today's reading ──────────────────────────────────────────────
  if (content?.reading != null) {
    await tapVisible(t, _inReader(find.byKey(const Key('bible-today'))));
    await pumpFor(t, const Duration(milliseconds: 600));
    j.check(
      await pumpUntil(
        t,
        () =>
            _inReader(find.text('TODAY\u2019S READING')).evaluate().isNotEmpty,
      ),
      'Today\u2019s reading returns to today\u2019s passage',
    );
  }

  // ── The Bible tab: picker, Continue reading, search ──────────────────────
  await goBack(t);
  j.check(
    await pumpUntil(
      t,
      () =>
          find.byType(ReadingScreen).evaluate().isEmpty &&
          find.byType(BibleScreen).evaluate().isNotEmpty,
    ),
    'the swipe back from the reader returns to the Bible tab',
  );
  await tapVisible(t, find.byKey(const Key('bible-open-picker')));
  j.check(
    await pumpUntil(t, () => _picker.evaluate().isNotEmpty),
    'Choose a passage opens the picker',
  );
  await j.shot('bible-picker');
  await tapVisible(t, find.byKey(const Key('passage-picker-done')));
  j.check(
    await pumpUntil(
      t,
      () =>
          _picker.evaluate().isEmpty &&
          find.byType(ReadingScreen).evaluate().isEmpty &&
          find.byType(BibleScreen).evaluate().isNotEmpty,
    ),
    'Done on the picker stays on the Bible tab',
  );

  await tapVisible(t, find.byKey(const Key('bible-open-picker')));
  await _chooseInPicker(
    j,
    book.usfm,
    book.chapters,
    chapter,
    newTestament: isNt(book),
  );
  j.check(
    _label(t) == '${book.title} $chapter',
    'the Bible tab\u2019s picker opens ${book.title} $chapter (shows "${_label(t)}")',
  );
  await j.shot('bible-chosen');
  await goBack(t);
  await pumpUntil(t, () => find.byType(ReadingScreen).evaluate().isEmpty);
  final cont = find.byKey(const Key('bible-continue'));
  j.check(
    await pumpUntil(
      t,
      () => find
          .descendant(of: cont, matching: find.text('${book.title} $chapter'))
          .evaluate()
          .isNotEmpty,
    ),
    'Continue reading offers ${book.title} $chapter',
  );
  await tapVisible(t, find.byKey(const Key('bible-continue-button')));
  await pumpUntilFound(t, find.byType(ReadingScreen));
  await _passageLoaded(j);
  j.check(
    _label(t) == '${book.title} $chapter',
    'Continue reopens ${book.title} $chapter (shows "${_label(t)}")',
  );
  await goBack(t);
  await pumpUntil(t, () => find.byType(ReadingScreen).evaluate().isEmpty);

  final field = find.descendant(
    of: find.byKey(const Key('bible-landing-search')),
    matching: find.byType(EditableText),
  );
  await t.tap(field, warnIfMissed: false);
  await t.enterText(field, 'Romans 8:28');
  await t.testTextInput.receiveAction(TextInputAction.search);
  await pumpUntilFound(t, find.byType(ReadingScreen));
  await _passageLoaded(j);
  await pumpFor(t, const Duration(seconds: 1));
  j.check(
    _label(t) == 'Romans 8' && _markedVerses(t).contains(28),
    'the Bible tab\u2019s search opens Romans 8 with verse 28 marked '
    '(shows "${_label(t)}", marked ${_markedVerses(t)})',
  );
  await j.shot('landing-search');
}
