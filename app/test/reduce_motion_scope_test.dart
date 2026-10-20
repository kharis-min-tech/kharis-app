import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kharis_app/shared/widgets/reduce_motion_scope.dart';

/// iOS Reduce Motion, which Flutter does not put in MediaQuery, still stops
/// motion everywhere the app checks `disableAnimations`.
void main() {
  bool? seen;

  Widget app() => MaterialApp(
    builder: (context, child) => ReduceMotionScope(child: child!),
    home: Builder(
      builder: (context) {
        seen = MediaQuery.disableAnimationsOf(context);
        return const SizedBox();
      },
    ),
  );

  testWidgets('iOS Reduce Motion on: animations are off below the scope; '
      'turning it off while the app runs turns them back on', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(reduceMotion: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpWidget(app());
    expect(seen, isTrue);

    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures();
    await tester.pump();
    expect(seen, isFalse);
  });

  testWidgets('neither setting on: animations stay on', (tester) async {
    await tester.pumpWidget(app());
    expect(seen, isFalse);
  });
}
