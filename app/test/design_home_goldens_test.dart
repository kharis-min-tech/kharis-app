// Golden tests for Home's own components: KHomeHero (with KHeroGreeting,
// KHeroRoundButton, KHeroMessage and its skeleton) and KStatsStrip, in light
// and dark at 100% and 200% text size, at the 390 design width. Regenerate
// after an intended visual change:
//
//     flutter test --no-pub --update-goldens test/design_home_goldens_test.dart
//
// As in design_component_goldens_test.dart, pixels are compared on macOS
// only; elsewhere each entry is still built, which catches overflow.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kharis_app/ui/components/components.dart';

import 'support/design_harness.dart';

const _goldenKey = ValueKey('design-golden');
const _artwork = AssetImage('assets/hero/preaching-open-bible.jpg');

Widget _header({bool avatar = true}) => Row(
  children: [
    Expanded(
      child: KHeroGreeting(
        greeting: 'Good evening, Esther',
        branchLabel: 'London',
        branchSemanticLabel: 'Change branch, now London',
        onBranch: () {},
      ),
    ),
    const SizedBox(width: KSpace.lg),
    KHeroRoundButton(
      icon: KIcons.bell,
      label: 'Notifications, new items',
      dot: true,
      onPressed: () {},
    ),
    if (avatar) ...[
      const SizedBox(width: KSpace.md),
      KHeroRoundButton(initial: 'E', label: 'Your profile', onPressed: () {}),
    ],
  ],
);

Widget _hero() => KHomeHero(
  backdrop: _artwork,
  bottomInset: KSpace.section,
  header: _header(),
  message: KHeroMessage(
    badge: 'New from Sunday',
    title: 'The Portraits of Christ',
    lines: const ['Pastor David Antwi', '58 min'],
    artwork: _artwork,
    onListen: () {},
    onWatch: () {},
    onDownload: () {},
  ),
);

Widget _heroStates() => Column(
  mainAxisSize: MainAxisSize.min,
  children: [
    KHomeHero(
      header: _header(avatar: false),
      message: KHeroMessage(
        badge: 'Latest message',
        title: 'In Spirit and Truth: worship that the Father seeks',
        lines: const ['1 hr 5 min'],
        onListen: () {},
        onDownload: () {},
        downloadState: KHeroDownloadState.downloading,
        downloadProgress: 0.4,
        downloadLabel: 'Cancel download',
      ),
    ),
    const SizedBox(height: KSpace.md),
    KHomeHero(
      header: _header(avatar: false),
      message: KHeroMessage(
        badge: 'Latest message',
        title: 'Faith',
        lines: const ['Pastor David Antwi'],
        onWatch: () {},
        onDownload: () {},
        downloadState: KHeroDownloadState.done,
      ),
    ),
    const SizedBox(height: KSpace.md),
    KHomeHero(header: _header(), message: const KHeroMessageSkeleton()),
    const SizedBox(height: KSpace.md),
    KHomeHero(header: _header()),
  ],
);

Widget _stats() => Padding(
  padding: const EdgeInsets.all(KSpace.x3),
  child: Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      KStatsStrip(
        stats: [
          KStat(
            label: 'Today\u2019s reading',
            value: 'Esther 5',
            status: 'Not read',
            onTap: () {},
          ),
          const KStat(
            label: 'Reading',
            value: '27',
            icon: KIcons.flame,
            caption: 'day streak',
          ),
          const KStat(
            label: 'Messages',
            value: '12',
            icon: KIcons.messages,
            caption: 'day streak',
          ),
        ],
      ),
      const SizedBox(height: KSpace.x3),
      const KStatsStrip(
        stats: [
          KStat(
            label: 'Today\u2019s reading',
            value: '2 Chronicles 12 \u00b7 Psalm 119',
            status: 'Read',
            statusDone: true,
          ),
          KStat(
            label: 'Reading',
            value: '0',
            icon: KIcons.flame,
            caption: 'day streak',
          ),
          KStat(
            label: 'Messages',
            value: '0',
            icon: KIcons.messages,
            caption: 'day streak',
          ),
        ],
      ),
      const SizedBox(height: KSpace.x3),
      const KStatsStrip(
        stats: [
          KStat(label: 'Today\u2019s reading', value: '', loading: true),
          KStat(label: 'Read', value: 'Bible'),
          KStat(
            label: 'Messages',
            value: '3',
            icon: KIcons.messages,
            caption: 'day streak',
          ),
        ],
      ),
    ],
  ),
);

void main() {
  setUpAll(loadDesignAssets);

  final entries = <String, Widget Function()>{
    'home_hero': _hero,
    'home_hero_states': _heroStates,
    'stats_strip': _stats,
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
}
