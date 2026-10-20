import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kharis_app/shared/widgets/press_effect.dart';

double _scale(WidgetTester tester) => tester
    .widget<AnimatedScale>(find.byKey(const Key('press-effect-scale')))
    .scale;

Future<void> _pump(WidgetTester tester, {bool reduceMotion = false}) =>
    tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(disableAnimations: reduceMotion),
        child: MaterialApp(
          home: ListView(
            children: [
              PressEffect(
                onTap: () {},
                child: const SizedBox(height: 120, child: Text('card')),
              ),
              const SizedBox(height: 2000),
            ],
          ),
        ),
      ),
    );

void main() {
  testWidgets('a press shrinks the card; lifting the finger restores it', (
    tester,
  ) async {
    await _pump(tester);
    final g = await tester.startGesture(tester.getCenter(find.text('card')));
    await tester.pump();
    expect(_scale(tester), 0.97);
    await g.up();
    await tester.pump();
    expect(_scale(tester), 1.0);
  });

  testWidgets('a scroll that starts on the card lets go of the press at once', (
    tester,
  ) async {
    await _pump(tester);
    final g = await tester.startGesture(tester.getCenter(find.text('card')));
    await tester.pump();
    await g.moveBy(const Offset(0, -40));
    await tester.pump();
    expect(_scale(tester), 1.0, reason: 'still scrolling, finger down');
    await g.up();
  });

  testWidgets('reduced motion: a press dims without scaling', (tester) async {
    await _pump(tester, reduceMotion: true);
    final g = await tester.startGesture(tester.getCenter(find.text('card')));
    await tester.pump();
    expect(_scale(tester), 1.0);
    await g.up();
  });
}
