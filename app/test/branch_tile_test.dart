import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/features/onboarding/presentation/widgets/branch_tile.dart';

Color _tileColor(WidgetTester tester) {
  final box = tester.widget<Container>(
    find
        .descendant(
          of: find.byType(BranchTile),
          matching: find.byType(Container),
        )
        .first,
  );
  return (box.decoration! as BoxDecoration).color!;
}

Future<void> _pump(WidgetTester tester, Brightness brightness) {
  final kc = brightness == Brightness.dark
      ? KharisColors.dark
      : KharisColors.light;
  return tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(brightness: brightness, extensions: [kc]),
      home: Scaffold(
        body: BranchTile(
          name: 'London',
          region: 'Headquarters',
          gradientColors: const [Colors.purple, Colors.orange],
          onTap: () {},
          isHq: true,
        ),
      ),
    ),
  );
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('HQ tile keeps the dark surface in dark mode so its name reads', (
    tester,
  ) async {
    await _pump(tester, Brightness.dark);
    expect(_tileColor(tester), KharisColors.dark.surface);
    expect(_tileColor(tester), isNot(AppColors.hqTint));
  });

  testWidgets('HQ tile keeps its cream tint in light mode', (tester) async {
    await _pump(tester, Brightness.light);
    expect(_tileColor(tester), AppColors.hqTint);
  });
}
