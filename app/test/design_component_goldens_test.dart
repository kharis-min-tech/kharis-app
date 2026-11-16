// Golden tests for the redesign components: every gallery entry in light and
// dark, at 100% and 200% text size, at the 390 design width.
//
// The same entries make up the /design gallery, so a component added there
// gets its goldens here. Regenerate after an intended visual change:
//
//     flutter test --no-pub --update-goldens test/design_component_goldens_test.dart
//
// The images were made on macOS. Text is drawn slightly differently on other
// systems, so there the pixels are not compared; every entry is still built
// in all four settings, which catches overflow and layout errors (a clipped
// row at 200% fails the test anywhere).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kharis_app/ui/components/components.dart';
import 'package:kharis_app/ui/gallery/component_gallery_screen.dart';

import 'support/design_harness.dart';

const _goldenKey = ValueKey('design-golden');

void main() {
  setUpAll(loadDesignAssets);

  final sections = gallerySections();

  for (final section in sections) {
    for (final dark in const [false, true]) {
      for (final scale in const [1.0, 2.0]) {
        final mode = dark ? 'dark' : 'light';
        final percent = (scale * 100).round();

        testWidgets('${section.id} · $mode · $percent%', (tester) async {
          // Tests draw shadows as solid blocks unless told otherwise; the
          // goldens should show the soft shadows people will see. The flag
          // must be back before the test body ends.
          debugDisableShadows = false;
          try {
            await pumpDesign(
              tester,
              RepaintBoundary(
                key: _goldenKey,
                child: Builder(
                  builder: (context) => ColoredBox(
                    color: context.k.bg,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: KSpace.section),
                      child: GallerySectionView(section: section),
                    ),
                  ),
                ),
              ),
              dark: dark,
              textScale: scale,
            );

            expect(tester.takeException(), isNull);
            if (Platform.isMacOS) {
              await expectLater(
                find.byKey(_goldenKey),
                matchesGoldenFile('goldens/${section.id}_${mode}_$percent.png'),
              );
            }
          } finally {
            debugDisableShadows = true;
          }
        });
      }
    }
  }

  test('there is a gallery entry for every component in the spec', () {
    final ids = sections.map((section) => section.id).toSet();
    expect(ids.length, sections.length, reason: 'entry ids must be unique');
    expect(
      ids,
      containsAll(<String>[
        'button',
        'icon_button',
        'text_link',
        'chip',
        'chip_row',
        'toggle_button',
        'option_card',
        'tabs',
        'streak_dots',
        'card',
        'section_header',
        'badge',
        'media_tile',
        'hero_card',
        'list_row',
        'empty_state',
        'skeleton',
        'error_state',
        'search_field',
        'screen_header',
        'bottom_sheet',
        'sort_sheet',
        'floating_nav',
        'grace_button',
        'mini_player',
        'continue_listening',
        'event_card',
        'chat',
        'composer',
        'icons',
      ]),
    );
  });
}
