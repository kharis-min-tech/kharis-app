// Behaviour and accessibility tests for the redesign components.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kharis_app/ui/components/components.dart';
import 'package:kharis_app/ui/gallery/component_gallery_screen.dart';

import 'support/design_harness.dart';

const _navItems = [
  KNavItem(label: 'Home', icon: KIcons.home),
  KNavItem(label: 'Messages', icon: KIcons.messages),
  KNavItem(label: 'Bible', icon: KIcons.bible),
  KNavItem(label: 'More', icon: KIcons.more),
];

void main() {
  setUpAll(loadDesignAssets);

  group('KFloatingNav', () {
    testWidgets('announces the selected tab, and only that one', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpDesign(
        tester,
        KFloatingNav(items: _navItems, currentIndex: 1, onTap: (_) {}),
        dark: false,
      );

      expect(
        tester.getSemantics(find.bySemanticsLabel('Messages')),
        isSemantics(
          label: 'Messages',
          isButton: true,
          hasSelectedState: true,
          isSelected: true,
        ),
      );
      for (final other in ['Home', 'Bible', 'More']) {
        expect(
          tester.getSemantics(find.bySemanticsLabel(other)),
          isSemantics(
            label: other,
            isButton: true,
            hasSelectedState: true,
            isSelected: false,
          ),
        );
      }
      handle.dispose();
    });

    testWidgets('moves the announcement when another tab is chosen', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      var index = 0;
      await pumpDesign(
        tester,
        StatefulBuilder(
          builder: (context, setState) => KFloatingNav(
            items: _navItems,
            currentIndex: index,
            onTap: (i) => setState(() => index = i),
          ),
        ),
        dark: true,
      );

      await tester.tap(find.bySemanticsLabel('Bible'));
      await tester.pump();

      expect(index, 2);
      expect(
        tester.getSemantics(find.bySemanticsLabel('Bible')),
        isSemantics(isSelected: true),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('Home')),
        isSemantics(isSelected: false),
      );
      handle.dispose();
    });
  });

  group('KGraceButton', () {
    Offset orb(WidgetTester tester) => tester.getCenter(
      find.descendant(
        of: find.byType(KGraceButton),
        matching: find.byType(KDoveMark),
      ),
    );

    Widget button() => Center(
      child: KGraceButton(onPressed: () {}, semanticLabel: 'Ask Grace'),
    );

    testWidgets('bobs while motion is allowed', (tester) async {
      await pumpDesign(tester, button(), dark: false, reduceMotion: false);

      expect(tester.binding.transientCallbackCount, greaterThan(0));
      final rest = orb(tester);
      // A quarter of the 2.8 s cycle is halfway up.
      await tester.pump(KMotion.graceBob ~/ 4);
      expect(orb(tester).dy, lessThan(rest.dy));
    });

    testWidgets('stops animating with reduce motion', (tester) async {
      await pumpDesign(tester, button(), dark: false, reduceMotion: true);

      expect(tester.binding.transientCallbackCount, 0);
      expect(tester.binding.hasScheduledFrame, isFalse);
      final rest = orb(tester);
      await tester.pump(KMotion.graceBob ~/ 4);
      expect(orb(tester), rest);
    });

    testWidgets('stops when reduce motion is turned on while it runs', (
      tester,
    ) async {
      await pumpDesign(tester, button(), dark: false, reduceMotion: false);
      expect(tester.binding.transientCallbackCount, greaterThan(0));

      await tester.pumpWidget(
        designHarness(dark: false, reduceMotion: true, child: button()),
      );
      await tester.pump();

      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('is a labelled button with a 56 hit area', (tester) async {
      final handle = tester.ensureSemantics();
      var taps = 0;
      await pumpDesign(
        tester,
        Center(
          child: KGraceButton(
            onPressed: () => taps++,
            semanticLabel: 'Ask Grace',
          ),
        ),
        dark: false,
      );

      expect(
        tester.getSemantics(find.byType(KGraceButton)),
        isSemantics(label: 'Ask Grace', isButton: true, hasTapAction: true),
      );
      expect(
        tester.getSize(find.byType(KGraceButton)),
        const Size.square(KSize.graceSize),
      );
      await tester.tap(find.byType(KGraceButton));
      expect(taps, 1);
      handle.dispose();
    });
  });

  group('KTypingIndicator', () {
    testWidgets('pulses, and is still with reduce motion', (tester) async {
      await pumpDesign(
        tester,
        const KTypingIndicator(),
        dark: false,
        reduceMotion: false,
      );
      expect(tester.binding.transientCallbackCount, greaterThan(0));

      await pumpDesign(
        tester,
        const KTypingIndicator(),
        dark: false,
        reduceMotion: true,
      );
      expect(tester.binding.transientCallbackCount, 0);
    });
  });

  group('hit areas', () {
    testWidgets('icon-only and text controls are at least 44 by 44', (
      tester,
    ) async {
      await pumpDesign(
        tester,
        Wrap(
          children: [
            KIconButton(icon: KIcons.search, label: 'Search', onPressed: () {}),
            KTextLink(label: 'History', onTap: () {}),
            KToggleButton(
              label: 'Follow',
              icon: KIcons.plus,
              selected: false,
              onChanged: (_) {},
            ),
          ],
        ),
        dark: false,
      );

      for (final type in [KIconButton, KTextLink, KToggleButton]) {
        final size = tester.getSize(find.byType(type));
        expect(
          size.width,
          greaterThanOrEqualTo(KSize.touchMin),
          reason: '$type',
        );
        expect(
          size.height,
          greaterThanOrEqualTo(KSize.touchMin),
          reason: '$type',
        );
      }
    });

    testWidgets('a tap on the rim of an icon button still counts, once', (
      tester,
    ) async {
      var taps = 0;
      await pumpDesign(
        tester,
        Center(
          child: KIconButton(
            icon: KIcons.search,
            label: 'Search',
            onPressed: () => taps++,
          ),
        ),
        dark: false,
      );

      final box = tester.getRect(find.byType(KIconButton));
      await tester.tapAt(box.topLeft + const Offset(1, 1));
      expect(taps, 1);
      await tester.tapAt(box.center);
      expect(taps, 2);
    });
  });

  group('state is exposed, never colour alone', () {
    testWidgets('KToggleButton reports on and off and flips', (tester) async {
      final handle = tester.ensureSemantics();
      var on = false;
      await pumpDesign(
        tester,
        StatefulBuilder(
          builder: (context, setState) => KToggleButton(
            label: 'Remind me',
            selectedLabel: 'Reminder on',
            icon: KIcons.bell,
            selected: on,
            onChanged: (value) => setState(() => on = value),
          ),
        ),
        dark: false,
      );

      expect(
        tester.getSemantics(find.byType(KToggleButton)),
        isSemantics(
          label: 'Remind me',
          isButton: true,
          hasToggledState: true,
          isToggled: false,
        ),
      );

      await tester.tap(find.byType(KToggleButton));
      await tester.pump();

      expect(on, isTrue);
      expect(find.text('Reminder on'), findsOneWidget);
      expect(
        tester.getSemantics(find.byType(KToggleButton)),
        isSemantics(label: 'Reminder on', isToggled: true),
      );
      handle.dispose();
    });

    testWidgets('KChip and KTabs report the selected one', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpDesign(
        tester,
        Column(
          children: [
            Row(
              children: [
                KChip(label: 'Book', selected: true, onTap: () {}),
                KChip(label: 'Theme', onTap: () {}),
              ],
            ),
            KTabs(
              tabs: const ['For you', 'Books'],
              currentIndex: 1,
              onChanged: (_) {},
            ),
          ],
        ),
        dark: false,
      );

      expect(
        tester.getSemantics(find.widgetWithText(KChip, 'Book')),
        isSemantics(isSelected: true),
      );
      expect(
        tester.getSemantics(find.widgetWithText(KChip, 'Theme')),
        isSemantics(isSelected: false),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('Books')),
        isSemantics(isButton: true, isSelected: true),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('For you')),
        isSemantics(isSelected: false),
      );
      handle.dispose();
    });

    testWidgets('KOptionCard is a checked radio in a group, with a check', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpDesign(
        tester,
        Column(
          children: [
            KOptionCard(
              title: 'Tithe',
              meta: 'A tenth, given first',
              selected: true,
              onTap: () {},
            ),
            KOptionCard(title: 'Offering', selected: false, onTap: () {}),
          ],
        ),
        dark: false,
      );

      expect(
        tester.getSemantics(
          find.bySemanticsLabel('Tithe, A tenth, given first'),
        ),
        isSemantics(
          isChecked: true,
          hasCheckedState: true,
          isInMutuallyExclusiveGroup: true,
        ),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('Offering')),
        isSemantics(isChecked: false),
      );
      // The selected radio carries a check mark, not just a fill.
      expect(
        find.descendant(
          of: find.widgetWithText(KOptionCard, 'Tithe'),
          matching: find.byType(KIcon),
        ),
        findsOneWidget,
      );
      handle.dispose();
    });
  });

  group('KContinueListening', () {
    testWidgets('shows three items at most', (tester) async {
      await pumpDesign(
        tester,
        KContinueListening(
          onHistory: () {},
          items: [
            for (var i = 1; i <= 5; i++)
              KContinueItem(title: 'Message $i', meta: 'Meta', progress: 0.5),
          ],
        ),
        dark: false,
      );

      expect(find.text('Message 1'), findsOneWidget);
      expect(find.text('Message 3'), findsOneWidget);
      expect(find.text('Message 4'), findsNothing);
      expect(find.text('History'), findsOneWidget);
    });
  });

  group('sheets', () {
    Future<void> open(WidgetTester tester, {required bool reduceMotion}) async {
      await pumpDesign(
        tester,
        Builder(
          builder: (context) => KButton(
            label: 'Open',
            onPressed: () => showKSortSheet<String>(
              context: context,
              title: 'Sort by',
              selected: 'newest',
              options: const [
                KSortOption(value: 'newest', label: 'Newest first'),
                KSortOption(value: 'oldest', label: 'Oldest first'),
              ],
            ),
          ),
        ),
        dark: false,
        reduceMotion: reduceMotion,
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
    }

    testWidgets('the sort sheet opens with a title and one checked row', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await open(tester, reduceMotion: false);

      expect(find.text('Sort by'), findsOneWidget);
      expect(
        tester.getSemantics(find.bySemanticsLabel('Newest first')),
        isSemantics(isChecked: true, isInMutuallyExclusiveGroup: true),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('Oldest first')),
        isSemantics(isChecked: false),
      );

      await tester.tap(find.text('Oldest first'));
      await tester.pumpAndSettle();
      expect(find.text('Sort by'), findsNothing);
      handle.dispose();
    });

    testWidgets('with reduce motion the sheet fades in and still closes on '
        'the scrim', (tester) async {
      await open(tester, reduceMotion: true);

      expect(find.text('Sort by'), findsOneWidget);
      expect(
        find.ancestor(
          of: find.byType(KBottomSheet),
          matching: find.byType(FadeTransition),
        ),
        findsWidgets,
      );
      // No bottom-sheet slide is involved.
      expect(find.byType(BottomSheet), findsNothing);

      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();
      expect(find.text('Sort by'), findsNothing);
    });
  });

  group('gallery', () {
    testWidgets('opens in the new theme and switches to dark', (tester) async {
      tester.view.physicalSize = designSurface;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      // The rest of the app still runs the old theme: the gallery must not
      // depend on what is above it.
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: const ComponentGalleryScreen(),
        ),
      );
      await tester.pump();

      BuildContext inner() => tester.element(find.text('Components'));
      expect(find.text('Components'), findsOneWidget);
      expect(inner().k.bg, KharisColors.light.bg);

      await tester.tap(find.widgetWithText(KChip, 'Dark'));
      await tester.pump();

      expect(inner().isDarkTheme, isTrue);
      expect(inner().k.bg, KharisColors.dark.bg);
    });
  });
}
