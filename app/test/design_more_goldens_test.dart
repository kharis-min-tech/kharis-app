// Golden and behaviour tests for the More components: KMoreProfileCard (with
// KMoreStreakBadge) and KMoreTile in a KMoreTileGrid, in light and dark at
// 100% and 200% text size, at the 390 design width. Regenerate after an
// intended visual change:
//
//     flutter test --no-pub --update-goldens test/design_more_goldens_test.dart
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

Widget _profileCards() => _padded([
  KMoreProfileCard(
    name: 'Esther',
    subtitle: 'London \u00b7 member since 2021',
    streaks: const [
      KMoreStreakBadge(
        '27-day reading',
        tone: KMoreStreakTone.highlight,
        icon: KIcons.flame,
      ),
      KMoreStreakBadge('12-day messages'),
    ],
    onTap: () {},
  ),
  KMoreProfileCard(
    name: 'Oluwaseun Adebayo-Williamson',
    subtitle: 'member since 2024',
    onTap: () {},
  ),
]);

Widget _tiles() => _padded([
  KMoreTileGrid(
    children: [
      KMoreTile(
        icon: KIcons.pen,
        title: 'My notes',
        meta: '62 notes',
        onTap: () {},
      ),
      KMoreTile(
        icon: KIcons.download,
        title: 'Downloads',
        meta: '12 saved',
        onTap: () {},
      ),
      KMoreTile(
        icon: KIcons.gift,
        title: 'Give',
        meta: 'Tithes and offerings',
        onTap: () {},
      ),
      KMoreTile(
        icon: KIcons.calendar,
        title: 'Events',
        meta: 'Midweek \u00b7 Wed 19:00',
        onTap: () {},
      ),
      KMoreTile(icon: KIcons.heart, title: 'Favourites', onTap: () {}),
    ],
  ),
]);

void main() {
  setUpAll(loadDesignAssets);

  final entries = <String, Widget Function()>{
    'more_profile_card': _profileCards,
    'more_tile': _tiles,
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

  testWidgets('a tile is one button named by its title and its fact', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    var taps = 0;
    await pumpDesign(
      tester,
      _padded([
        KMoreTile(
          icon: KIcons.download,
          title: 'Downloads',
          meta: '12 saved',
          onTap: () => taps++,
        ),
      ]),
      dark: false,
    );

    expect(find.bySemanticsLabel('Downloads, 12 saved'), findsOneWidget);
    expect(
      tester.getSize(find.byType(KMoreTile)).height,
      greaterThanOrEqualTo(KSize.touchMin),
    );
    await tester.tap(find.byType(KMoreTile));
    expect(taps, 1);
    handle.dispose();
  });

  testWidgets('tiles sit two to a row, each pair the same height', (
    tester,
  ) async {
    await pumpDesign(tester, _tiles(), dark: false);

    final notes = tester.getRect(find.widgetWithText(KMoreTile, 'My notes'));
    final downloads = tester.getRect(
      find.widgetWithText(KMoreTile, 'Downloads'),
    );
    final give = tester.getRect(find.widgetWithText(KMoreTile, 'Give'));
    expect(downloads.top, notes.top);
    expect(downloads.height, notes.height);
    expect(downloads.left, greaterThan(notes.right));
    expect(give.top, greaterThan(notes.bottom));
    expect(give.width, notes.width);
  });

  testWidgets('tiles stack one to a row at large text sizes', (tester) async {
    await pumpDesign(tester, _tiles(), dark: false, textScale: 2);

    final notes = tester.getRect(find.widgetWithText(KMoreTile, 'My notes'));
    final downloads = tester.getRect(
      find.widgetWithText(KMoreTile, 'Downloads'),
    );
    expect(downloads.top, greaterThan(notes.bottom));
    expect(downloads.left, notes.left);
  });

  testWidgets('the profile card is one button that says who it is and where '
      'it leads', (tester) async {
    final handle = tester.ensureSemantics();
    var taps = 0;
    await pumpDesign(
      tester,
      _padded([
        KMoreProfileCard(
          name: 'Esther',
          subtitle: 'London \u00b7 member since 2021',
          streaks: const [KMoreStreakBadge('12-day messages')],
          onTap: () => taps++,
        ),
      ]),
      dark: false,
    );

    expect(
      find.bySemanticsLabel(
        'Esther, London \u00b7 member since 2021, 12-day messages streak, '
        'Edit profile',
      ),
      findsOneWidget,
    );
    // The avatar carries the first letter of the name.
    expect(find.text('E'), findsOneWidget);
    await tester.tap(find.byType(KMoreProfileCard));
    expect(taps, 1);
    handle.dispose();
  });
}
