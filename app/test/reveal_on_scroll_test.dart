import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kharis_app/shared/widgets/reveal_on_scroll.dart';

/// Sections below the first screen rise and fade in once as the member
/// scrolls to them; what is already on screen never animates.
void main() {
  late ScrollController scroll;

  double opacityOf(WidgetTester tester, String label) => tester
      .widget<FadeTransition>(
        find
            .ancestor(
              of: find.text(label),
              matching: find.byType(FadeTransition),
            )
            .first,
      )
      .opacity
      .value;

  Future<void> pump(WidgetTester tester, {bool reduceMotion = false}) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    scroll = ScrollController();
    addTearDown(scroll.dispose);
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(
          size: const Size(400, 800),
          disableAnimations: reduceMotion,
        ),
        child: MaterialApp(
          home: RevealScope(
            scroll: scroll,
            child: ListView(
              controller: scroll,
              children: const [
                RevealOnScroll(
                  child: SizedBox(height: 300, child: Text('first')),
                ),
                RevealOnScroll(
                  child: SizedBox(height: 300, child: Text('second')),
                ),
                SizedBox(height: 400),
                RevealOnScroll(
                  child: SizedBox(height: 300, child: Text('later')),
                ),
                SizedBox(height: 1200),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('on the first screen: shown from the start, no entrance', (
    tester,
  ) async {
    await pump(tester);
    expect(opacityOf(tester, 'first'), 1);
    expect(opacityOf(tester, 'second'), 1);
  });

  testWidgets('below the fold: hidden until its top passes 85% of the '
      'screen, then in within 280 ms, and it stays on the way back', (
    tester,
  ) async {
    await pump(tester);
    // 'later' starts at 1000 px; 85% of 800 is 680. Built (in the list's
    // cache) but not yet reached: hidden.
    scroll.jumpTo(300); // top at 700
    await tester.pump();
    await tester.pump();
    expect(opacityOf(tester, 'later'), 0);

    scroll.jumpTo(340); // top at 660: past the line
    await tester.pump(); // laid out; the reveal starts
    await tester.pump(); // its first tick
    await tester.pump(const Duration(milliseconds: 100));
    expect(opacityOf(tester, 'later'), inExclusiveRange(0, 1));
    await tester.pump(kRevealDuration);
    expect(opacityOf(tester, 'later'), 1);

    scroll.jumpTo(0);
    await tester.pump();
    scroll.jumpTo(600);
    await tester.pump();
    expect(opacityOf(tester, 'later'), 1, reason: 'never replays');
  });

  testWidgets('reduced motion: everything is simply there', (tester) async {
    await pump(tester, reduceMotion: true);
    scroll.jumpTo(300);
    await tester.pump();
    await tester.pump();
    expect(opacityOf(tester, 'later'), 1);
  });
}
