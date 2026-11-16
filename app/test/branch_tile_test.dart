import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kharis_app/features/onboarding/presentation/widgets/branch_tile.dart';
import 'package:kharis_app/ui/components/components.dart';

import 'support/design_harness.dart';

Future<void> _pump(
  WidgetTester tester, {
  required bool dark,
  bool isHq = false,
  bool selected = false,
  VoidCallback? onTap,
}) => pumpDesign(
  tester,
  BranchTile(
    name: 'London',
    region: 'England',
    onTap: onTap ?? () {},
    isHq: isHq,
    selected: selected,
  ),
  dark: dark,
);

void main() {
  setUpAll(loadDesignAssets);

  for (final dark in const [false, true]) {
    final mode = dark ? 'dark' : 'light';

    testWidgets('the headquarters is marked with an HQ badge ($mode)', (
      tester,
    ) async {
      await _pump(tester, dark: dark, isHq: true);
      expect(find.text('London'), findsOneWidget);
      expect(find.text('England'), findsOneWidget);
      expect(find.byType(KBadge), findsOneWidget);
      expect(find.text('HQ'), findsOneWidget);
    });
  }

  testWidgets('other branches carry no badge and no check', (tester) async {
    await _pump(tester, dark: false);
    expect(find.byType(KBadge), findsNothing);
    expect(find.byType(KIcon), findsNothing);
  });

  testWidgets('the current branch shows a check and reads as selected', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, dark: false, selected: true);

    final check = tester.widget<KIcon>(find.byType(KIcon));
    expect(check.asset, KIcons.check);
    expect(
      tester.getSemantics(find.byType(BranchTile)),
      isSemantics(isSelected: true, hasSelectedState: true),
    );
    handle.dispose();
  });

  testWidgets('a tap anywhere on the row chooses the branch', (tester) async {
    var taps = 0;
    await _pump(tester, dark: false, onTap: () => taps++);

    final row = tester.getRect(find.byType(BranchTile));
    await tester.tapAt(row.centerRight - const Offset(KSpace.x3, 0));
    expect(taps, 1);
    expect(row.height, greaterThanOrEqualTo(KSize.touchMin));
  });
}
