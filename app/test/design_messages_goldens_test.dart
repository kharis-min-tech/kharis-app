// Golden and behaviour tests for the Messages components: KMessageRow in a
// KListGroup, KMessageHero, and KFilterSheet, in light and dark at 100% and
// 200% text size, at the 390 design width. Regenerate after an intended
// visual change:
//
//     flutter test --no-pub --update-goldens test/design_messages_goldens_test.dart
//
// As in design_component_goldens_test.dart, pixels are compared on macOS
// only; elsewhere each entry is still built, which catches overflow.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kharis_app/ui/components/components.dart';

import 'support/design_harness.dart';

const _goldenKey = ValueKey('design-golden');

Widget _padded(Widget child) =>
    Padding(padding: const EdgeInsets.all(KSpace.gutter), child: child);

Widget _rows() => _padded(
  KListGroup(
    children: [
      KMessageRow(
        title: 'Walking in the Spirit',
        meta: 'Pastor David Antwi \u00b7 12 Oct 2026',
        badge: 'Galatians 5:16-26',
        trailingLabel: '48 min',
        onTap: () {},
        onMore: () {},
      ),
      KMessageRow(
        title: 'The good shepherd knows his sheep by name, every one of them',
        meta: 'Grace Mensah \u00b7 2 Mar 2025',
        trailingLabel: '28 min left',
        progress: 0.4,
        progressLabel: '40% listened',
        onTap: () {},
        onMore: () {},
      ),
      KMessageRow(title: 'Faith part one', trailingLabel: 'Finished'),
    ],
  ),
);

Widget _hero() => _padded(
  KMessageHero(
    title: 'Faith that moves mountains',
    badge: 'New \u00b7 Part 2',
    meta: 'Pastor David Antwi \u00b7 48 min',
    onListen: () {},
    onDownload: () {},
    downloadState: KMessageDownloadState.downloading,
    downloadProgress: 0.3,
    onAddToCollection: () {},
  ),
);

Widget _filterSheet() => _padded(
  KFilterSheet<String>(
    options: const [
      KFilterOption(value: 'a', label: 'Faith', meta: '412 messages'),
      KFilterOption(value: 'b', label: 'Prayer', meta: '38 messages'),
      KFilterOption(value: 'c', label: 'Holy Spirit'),
    ],
    selected: const {'b'},
    onApply: (_) {},
  ),
);

void main() {
  setUpAll(loadDesignAssets);

  final entries = <String, Widget Function()>{
    'message_row': _rows,
    'message_hero': _hero,
    'filter_sheet': _filterSheet,
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

  testWidgets('a row plays on tap and offers its more action to screen '
      'readers', (tester) async {
    final handle = tester.ensureSemantics();
    var taps = 0;
    var more = 0;
    await pumpDesign(
      tester,
      _padded(
        KMessageRow(
          title: 'Walking in the Spirit',
          trailingLabel: '48 min',
          onTap: () => taps++,
          onMore: () => more++,
          moreLabel: 'Add to a collection',
        ),
      ),
      dark: false,
    );

    await tester.tap(find.text('Walking in the Spirit'));
    expect(taps, 1);
    final node = tester.getSemantics(find.byType(KMessageRow));
    final action = node.getSemanticsData().customSemanticsActionIds!.single;
    tester.binding.renderViews.first.owner!.semanticsOwner!.performAction(
      node.id,
      SemanticsAction.customAction,
      action,
    );
    expect(more, 1);
    handle.dispose();
  });

  testWidgets('the filter sheet applies only what is ticked', (tester) async {
    Set<String>? applied;
    await pumpDesign(
      tester,
      KFilterSheet<String>(
        options: const [
          KFilterOption(value: 'a', label: 'Under 20 min'),
          KFilterOption(value: 'b', label: 'Over 40 min'),
        ],
        selected: const {'b'},
        onApply: (v) => applied = v,
      ),
      dark: false,
    );

    await tester.tap(find.text('Under 20 min'));
    await tester.pump();
    await tester.tap(find.text('Show results'));
    expect(applied, {'a', 'b'});
  });
}
