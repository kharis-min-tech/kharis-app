// Golden and behaviour tests for KSwitch, KAnnouncementCard and
// KDestructiveButton, in light and dark at 100% and 200% text size, at the
// 390 design width. Regenerate after an intended visual change:
//
//     flutter test --no-pub --update-goldens test/secondary_component_goldens_test.dart
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

Widget _switches() => _padded([
  KListGroup(
    children: [
      KListRow(
        title: 'Announcements',
        meta: 'News and notices from your branch',
        trailing: KSwitch(value: true, onChanged: (_) {}),
      ),
      KListRow(
        title: 'Events',
        meta: 'Updates on upcoming events',
        trailing: KSwitch(value: false, onChanged: (_) {}),
      ),
      const KListRow(
        title: 'Daily reading',
        meta: 'Not available on this device',
        trailing: KSwitch(value: true, onChanged: null),
      ),
    ],
  ),
]);

Widget _announcements() => _padded([
  KAnnouncementCard(
    month: 'Nov',
    day: '22',
    title: 'Baptism Sunday',
    snippet:
        'Ready to be baptised? Speak to the pastoral team by Sunday 15 '
        'November.',
    actionLabel: 'Read more',
    onTap: () {},
  ),
  KAnnouncementCard(
    month: 'Dec',
    day: '13',
    title: 'Carols at The Lighthouse',
    actionLabel: 'View event',
    onTap: () {},
  ),
]);

Widget _destructive() => _padded([
  KDestructiveButton(label: 'Delete account', expand: true, onPressed: () {}),
  const KDestructiveButton(
    label: 'Delete account',
    expand: true,
    onPressed: null,
  ),
]);

void main() {
  setUpAll(loadDesignAssets);

  final entries = <String, Widget Function()>{
    'switch': _switches,
    'announcement_card': _announcements,
    'destructive_button': _destructive,
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

  testWidgets('a switch is a 44-tall toggle that reports its state and '
      'flips on tap', (tester) async {
    final handle = tester.ensureSemantics();
    var value = false;
    await pumpDesign(
      tester,
      StatefulBuilder(
        builder: (context, setState) => _padded([
          Align(
            alignment: Alignment.centerLeft,
            child: KSwitch(
              value: value,
              semanticLabel: 'Events',
              onChanged: (v) => setState(() => value = v),
            ),
          ),
        ]),
      ),
      dark: false,
    );

    final toggle = find.bySemanticsLabel('Events');
    expect(
      tester.getSize(find.byType(KSwitch)).height,
      greaterThanOrEqualTo(KSize.touchMin),
    );
    expect(
      tester.getSemantics(toggle),
      matchesSemantics(
        label: 'Events',
        hasToggledState: true,
        isToggled: false,
        hasEnabledState: true,
        isEnabled: true,
        hasTapAction: true,
      ),
    );

    await tester.tap(find.byType(KSwitch));
    await tester.pump();
    expect(value, isTrue);
    expect(
      tester.getSemantics(toggle),
      matchesSemantics(
        label: 'Events',
        hasToggledState: true,
        isToggled: true,
        hasEnabledState: true,
        isEnabled: true,
        hasTapAction: true,
      ),
    );
    handle.dispose();
  });

  testWidgets('a disabled switch does not change', (tester) async {
    await pumpDesign(
      tester,
      _padded([const KSwitch(value: true, onChanged: null)]),
      dark: false,
    );
    await tester.tap(find.byType(KSwitch), warnIfMissed: false);
    await tester.pump();
    expect(tester.widget<KSwitch>(find.byType(KSwitch)).value, isTrue);
  });

  testWidgets('an announcement card is one tap target', (tester) async {
    var taps = 0;
    await pumpDesign(
      tester,
      _padded([
        KAnnouncementCard(
          month: 'Nov',
          day: '22',
          title: 'Baptism Sunday',
          snippet: 'Ready to be baptised?',
          actionLabel: 'Read more',
          onTap: () => taps++,
        ),
      ]),
      dark: true,
    );
    await tester.tap(find.text('Read more'));
    await tester.tap(find.text('Baptism Sunday'));
    expect(taps, 2);
  });

  testWidgets('the destructive button draws in the error role', (tester) async {
    await pumpDesign(
      tester,
      _padded([KDestructiveButton(label: 'Delete account', onPressed: () {})]),
      dark: false,
    );
    final context = tester.element(find.byType(KDestructiveButton));
    final button = tester.widget<TextButton>(find.byType(TextButton));
    expect(button.style!.backgroundColor!.resolve({}), context.k.error);
    expect(button.style!.foregroundColor!.resolve({}), context.k.onError);
    expect(
      tester.getSize(find.byType(TextButton)).height,
      greaterThanOrEqualTo(KSize.touchMin),
    );
  });
}
