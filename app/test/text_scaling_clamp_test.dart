import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kharis_app/main.dart';

/// Pumps an app wired exactly like KharisApp's `MaterialApp.router` builder
/// with the device text size set to [systemScale], and returns the scale a
/// route actually sees for 10 logical pixels of text.
Future<double> _effectiveScale(WidgetTester tester, double systemScale) async {
  tester.platformDispatcher.textScaleFactorTestValue = systemScale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

  late TextScaler seen;
  await tester.pumpWidget(
    MaterialApp(
      builder: clampTextScaling,
      home: Builder(
        builder: (context) {
          seen = MediaQuery.textScalerOf(context);
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  return seen.scale(10) / 10;
}

void main() {
  testWidgets('very large system text is capped at the max scale', (
    tester,
  ) async {
    expect(await _effectiveScale(tester, 2.0), closeTo(kMaxTextScale, 1e-9));
  });

  testWidgets('very small system text is raised to the min scale', (
    tester,
  ) async {
    expect(await _effectiveScale(tester, 0.5), closeTo(kMinTextScale, 1e-9));
  });

  testWidgets('system text size inside the range is honoured as-is', (
    tester,
  ) async {
    expect(await _effectiveScale(tester, 1.15), closeTo(1.15, 1e-9));
  });
}
