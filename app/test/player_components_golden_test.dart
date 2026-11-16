// Goldens for the player components (lib/ui/components/k_player_controls.dart):
// the segmented control, the play button, the text transport button and the
// error banner, in light and dark, at 100% and 130% text size, at the 390
// design width. Regenerate after an intended visual change:
//
//     flutter test --no-pub --update-goldens test/player_components_golden_test.dart
//
// The images were made on macOS; elsewhere the pixels are not compared, but
// every setting is still built, which catches overflow.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kharis_app/ui/components/components.dart';

import 'support/design_harness.dart';

const _goldenKey = ValueKey('player-components-golden');

Widget _sample() => Padding(
  padding: const EdgeInsets.all(KSpace.gutter),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [
      KSegmentedControl(
        segments: [
          const KSegment(
            label: 'Audio',
            semanticLabel: 'Audio, selected',
            selected: true,
          ),
          KSegment(
            label: 'Video',
            semanticLabel: 'Switch to Video',
            onTap: () {},
          ),
        ],
      ),
      const SizedBox(height: KSpace.x3),
      const KSegmentedControl(
        segments: [
          KSegment(
            label: 'Audio',
            semanticLabel: 'Audio, selected',
            selected: true,
          ),
          KSegment(
            label: 'Video',
            semanticLabel: 'Video, No video recording for this message',
            enabled: false,
          ),
        ],
      ),
      const SizedBox(height: KSpace.x3),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          KTransportTextButton(
            text: '\u221215',
            label: 'Back 15 seconds',
            onPressed: () {},
          ),
          KPlayButton(playing: false, onPressed: () {}),
          KPlayButton(playing: true, onPressed: () {}),
          const KPlayButton(playing: false, onPressed: null),
          const KTransportTextButton(
            text: '+30',
            label: 'Forward 30 seconds',
            onPressed: null,
          ),
        ],
      ),
      const SizedBox(height: KSpace.x3),
      KErrorBanner(
        message: 'Couldn\u2019t play this message. Check your connection.',
        actions: [KBannerAction(label: 'Retry', onPressed: () {})],
      ),
      const SizedBox(height: KSpace.x3),
      const KErrorBanner(message: 'This video is no longer on YouTube.'),
    ],
  ),
);

void main() {
  setUpAll(loadDesignAssets);

  for (final dark in const [false, true]) {
    for (final scale in const [1.0, KRatio.largeTextScale]) {
      final mode = dark ? 'dark' : 'light';
      final percent = (scale * 100).round();

      testWidgets('player components · $mode · $percent%', (tester) async {
        await pumpDesign(
          tester,
          RepaintBoundary(
            key: _goldenKey,
            child: Builder(
              builder: (context) =>
                  ColoredBox(color: context.k.bg, child: _sample()),
            ),
          ),
          dark: dark,
          textScale: scale,
        );

        expect(tester.takeException(), isNull);
        if (Platform.isMacOS) {
          await expectLater(
            find.byKey(_goldenKey),
            matchesGoldenFile('goldens/player_components_${mode}_$percent.png'),
          );
        }
      });
    }
  }

  testWidgets('segmented control: the selected and the unavailable option '
      'do nothing; the other one switches', (tester) async {
    final semantics = tester.ensureSemantics();
    final taps = <String>[];
    await pumpDesign(
      tester,
      KSegmentedControl(
        segments: [
          const KSegment(
            label: 'Audio',
            semanticLabel: 'Audio, selected',
            selected: true,
          ),
          KSegment(
            label: 'Video',
            semanticLabel: 'Switch to Video',
            onTap: () => taps.add('video'),
          ),
          const KSegment(
            label: 'Live',
            semanticLabel: 'Live, not available',
            enabled: false,
          ),
        ],
      ),
      dark: false,
    );

    await tester.tap(find.text('Audio'));
    await tester.tap(find.text('Live'));
    expect(taps, isEmpty);
    await tester.tap(find.text('Video'));
    expect(taps, ['video']);

    expect(
      tester.getSemantics(find.bySemanticsLabel('Audio, selected')),
      matchesSemantics(
        label: 'Audio, selected',
        isButton: true,
        hasEnabledState: true,
        isEnabled: true,
        hasSelectedState: true,
        isSelected: true,
      ),
    );
    expect(
      tester.getSize(find.byType(KSegmentedControl)).height,
      greaterThanOrEqualTo(KSize.touchMin),
    );
    semantics.dispose();
  });

  testWidgets('play button is 56 across; text transport buttons at least 44', (
    tester,
  ) async {
    await pumpDesign(tester, _sample(), dark: false);

    expect(tester.getSize(find.byType(KPlayButton).first), const Size(56, 56));
    for (final element in find.byType(KTransportTextButton).evaluate()) {
      final size = element.size!;
      expect(size.width, greaterThanOrEqualTo(44));
      expect(size.height, greaterThanOrEqualTo(44));
    }
  });
}
