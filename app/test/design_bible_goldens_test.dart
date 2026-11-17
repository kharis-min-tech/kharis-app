// Golden and behaviour tests for the Bible components: KReaderToolbar,
// KVerse, KChapterNav, KChapterGrid, KBookGrid, KHighlightSwatch, the compact
// KHeroCard and KStreakDots with today marked, in light and dark at 100% and
// 200% text size, at the 390 design width. Regenerate after an intended
// visual change:
//
//     flutter test --no-pub --update-goldens test/design_bible_goldens_test.dart
//
// As in design_component_goldens_test.dart, pixels are compared on macOS
// only; elsewhere each entry is still built, which catches overflow.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kharis_app/ui/components/components.dart';

import 'support/design_harness.dart';

const _goldenKey = ValueKey('design-golden');

Widget _padded(List<Widget> children) => Padding(
  padding: const EdgeInsets.all(KSpace.gutter),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [
      for (final (i, child) in children.indexed) ...[
        if (i > 0) const SizedBox(height: KSpace.x3),
        child,
      ],
    ],
  ),
);

Widget _toolbar() => _padded([
  KReaderToolbar(
    passage: 'John 1',
    version: 'KJV',
    previousLabel: 'Luke 24',
    nextLabel: 'John 2',
    onPrevious: () {},
    onNext: () {},
    onPassage: () {},
    onVersion: () {},
    onStudy: () {},
  ),
  KReaderToolbar(
    passage: '1 Thessalonians 5',
    version: 'NASB2020',
    nextLabel: '2 Thessalonians 1',
    onNext: () {},
    onPassage: () {},
    onVersion: () {},
    onStudy: () {},
  ),
  KReaderToolbar(
    passage: null,
    version: 'NIV',
    onPassage: () {},
    onVersion: () {},
    onStudy: () {},
  ),
]);

Widget _bookGrid() => _padded([
  KBookGrid(
    books: [
      for (final name in const [
        'Romans',
        '1 Corinthians',
        '2 Corinthians',
        'Galatians',
        'Ephesians',
        'Philippians',
        'Colossians',
        '1 Thessalonians',
        '2 Thessalonians',
        'Song of Solomon',
      ])
        (id: name, label: name),
    ],
    selected: 'Galatians',
    onSelected: (_) {},
  ),
]);

Widget _verses() => _padded([
  KVerse(
    parts: [
      KVersePart(
        number: 1,
        text:
            'In the beginning was the Word, and the Word was with God, '
            'and the Word was God.',
        related: true,
        onTap: () {},
        footnotes: [KVerseFootnote(letter: 'a', onTap: () {})],
      ),
    ],
  ),
  KVerse(
    parts: [
      KVersePart(
        number: 2,
        text: 'The same was in the beginning with God.',
        highlight: 1,
        onTap: () {},
      ),
    ],
  ),
  KVerse(
    parts: [
      KVersePart(
        number: 3,
        text: 'All things were made by him; ',
        highlight: 2,
        onTap: () {},
      ),
      KVersePart(
        number: 4,
        text: 'in him was life; and the life was the light of men.',
        marked: true,
        onTap: () {},
      ),
    ],
  ),
  KVerse(
    indent: 1,
    dense: true,
    parts: [
      KVersePart(
        text: 'The Lord is my shepherd; I shall not want.',
        onTap: () {},
      ),
    ],
  ),
]);

Widget _chapterNav() => _padded([
  KChapterNav(
    label: 'End of John 1',
    previousLabel: 'Luke 24',
    nextLabel: 'John 2',
    onPrevious: () {},
    onNext: () {},
  ),
  KChapterNav(
    label: 'End of Revelation 22',
    previousLabel: 'Revelation 21',
    onPrevious: () {},
  ),
]);

Widget _chapterGrid() => _padded([
  KChapterGrid(
    book: 'Romans',
    chapters: [for (var c = 1; c <= 16; c++) c],
    selected: 8,
    onSelected: (_) {},
  ),
]);

Widget _swatches() => _padded([
  Row(
    children: [
      KHighlightSwatch(colour: 1, selected: true, onTap: () {}),
      const SizedBox(width: KSpace.xl),
      KHighlightSwatch(colour: 2, onTap: () {}),
    ],
  ),
]);

Widget _compactHero() => _padded([
  KHeroCard(
    compact: true,
    overline: 'Continue reading',
    title: 'Romans 8',
    image: const AssetImage('assets/hero/sunday-bible-raised.jpg'),
    primaryAction: KButton(
      label: 'Continue',
      variant: KButtonVariant.inverse,
      onPressed: () {},
    ),
  ),
]);

Widget _streakToday() => _padded([
  const KStreakDots(
    days: [true, true, false, true, false, false, false],
    todayIndex: 4,
    semanticLabel: '3 of 7 days read this week',
  ),
]);

void main() {
  setUpAll(loadDesignAssets);

  final entries = <String, Widget Function()>{
    'reader_toolbar': _toolbar,
    'verse': _verses,
    'chapter_nav': _chapterNav,
    'chapter_grid': _chapterGrid,
    'book_grid': _bookGrid,
    'highlight_swatch': _swatches,
    'hero_card_compact': _compactHero,
    'streak_dots_today': _streakToday,
  };

  for (final MapEntry(key: id, value: build) in entries.entries) {
    for (final dark in const [false, true]) {
      for (final scale in const [1.0, 2.0]) {
        final mode = dark ? 'dark' : 'light';
        final percent = (scale * 100).round();

        testWidgets('$id · $mode · $percent%', (tester) async {
          debugDisableShadows = false;
          try {
            await pumpDesign(
              tester,
              RepaintBoundary(
                key: _goldenKey,
                child: Builder(
                  builder: (context) =>
                      ColoredBox(color: context.k.bg, child: build()),
                ),
              ),
              dark: dark,
              textScale: scale,
            );

            expect(tester.takeException(), isNull);
            if (Platform.isMacOS) {
              await expectLater(
                find.byKey(_goldenKey),
                matchesGoldenFile('goldens/${id}_${mode}_$percent.png'),
              );
            }
          } finally {
            debugDisableShadows = true;
          }
        });
      }
    }
  }

  testWidgets('the toolbar steps chapters and opens the picker, the '
      'translations and the study tools', (tester) async {
    final taps = <String>[];
    await pumpDesign(
      tester,
      _padded([
        KReaderToolbar(
          passage: 'John 1',
          version: 'KJV',
          previousLabel: 'Luke 24',
          nextLabel: 'John 2',
          onPrevious: () => taps.add('previous'),
          onNext: () => taps.add('next'),
          onPassage: () => taps.add('passage'),
          onVersion: () => taps.add('version'),
          onStudy: () => taps.add('study'),
        ),
      ]),
      dark: false,
    );
    for (final key in const [
      'bible-toolbar-prev',
      'bible-toolbar-next',
      'bible-reference',
      'bible-translation',
      'bible-study',
    ]) {
      await tester.tap(find.byKey(Key(key)));
    }
    expect(taps, ['previous', 'next', 'passage', 'version', 'study']);
    for (final key in const [
      'bible-toolbar-prev',
      'bible-toolbar-next',
      'bible-translation',
      'bible-study',
    ]) {
      expect(
        tester.getSize(find.byKey(Key(key))),
        predicate<Size>(
          (s) => s.width >= KSize.touchMin && s.height >= KSize.touchMin,
        ),
        reason: '$key is a 44 touch target',
      );
    }
    expect(find.bySemanticsLabel('Previous chapter, Luke 24'), findsOneWidget);
    expect(find.bySemanticsLabel('Next chapter, John 2'), findsOneWidget);
    expect(find.bySemanticsLabel('Study tools'), findsOneWidget);
  });

  testWidgets('the toolbar dims Previous at the start of the Bible', (
    tester,
  ) async {
    await pumpDesign(
      tester,
      _padded([
        KReaderToolbar(
          passage: 'Genesis 1',
          version: 'KJV',
          nextLabel: 'Genesis 2',
          onNext: () {},
          onPassage: () {},
          onVersion: () {},
          onStudy: () {},
        ),
      ]),
      dark: false,
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('Previous chapter')),
      isSemantics(isButton: true, hasEnabledState: true, isEnabled: false),
    );
  });
}
