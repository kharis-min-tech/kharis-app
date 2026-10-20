import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kharis_app/features/calendar/data/event_repository.dart';
import 'package:kharis_app/features/home/data/live_repository.dart';
import 'package:kharis_app/features/home/data/news_repository.dart';
import 'package:kharis_app/features/home/presentation/screens/home_screen.dart';
import 'package:kharis_app/features/home/presentation/widgets/continue_listening_card.dart';
import 'package:kharis_app/features/home/presentation/widgets/home_hero.dart';
import 'package:kharis_app/features/onboarding/data/branch_repository.dart';
import 'package:kharis_app/shared/models/sermon.dart';
import 'package:kharis_app/shared/providers/admin_provider.dart';
import 'package:kharis_app/shared/providers/auth_provider.dart';
import 'package:kharis_app/shared/providers/branch_provider.dart';
import 'package:kharis_app/shared/providers/onboarding_provider.dart';
import 'package:kharis_app/shared/providers/sermon_provider.dart';

/// Home with the hero wall on top: drags on it scroll the page or move the
/// wall, the logo and bell float over it, the status bar gets a backing once
/// it has scrolled away, and empty blocks stay hidden. Wall videos are plain
/// boxes (tests have no video plugin).

const _statusBar = 47.0;

Future<void> _pumpHome(
  WidgetTester tester, {
  List<Event> events = const [],
  List<NewsItem> news = const [],
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final prefs = await SharedPreferences.getInstance();
  tester.view.physicalSize = const Size(400, 900);
  tester.view.devicePixelRatio = 1;
  tester.view.padding = const FakeViewPadding(top: _statusBar);
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        currentBranchProvider.overrideWith((ref) => Stream.value('London')),
        currentUserProvider.overrideWith((ref) => Stream.value(null)),
        branchesProvider.overrideWith(
          (ref) => Stream.value(const [
            Branch(
              id: 'london',
              name: 'London',
              subtitle: 'United Kingdom',
              gradientStart: Color(0xFF3B2A6B),
              gradientEnd: Color(0xFF7C3AED),
            ),
          ]),
        ),
        newsProvider.overrideWith((ref, b) async => news),
        upcomingEventsProvider.overrideWith((ref, b) => Stream.value(events)),
        liveStatusProvider.overrideWith(
          (ref) => Stream.value(LiveStatus.notLive),
        ),
        dailyContentProvider.overrideWith((ref) => Stream.value(null)),
        dailyMessageProvider.overrideWith((ref) => Stream.value(null)),
        continueListeningProvider.overrideWith((ref) => null),
        latestSermonsProvider.overrideWith((ref) => const <Sermon>[]),
        heroWallVideoProvider.overrideWithValue(
          (asset, poster, playing) => const ColoredBox(color: Colors.black),
        ),
      ],
      child: const MaterialApp(home: HomeScreen()),
    ),
  );
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

ScrollPosition _homeScroll(WidgetTester tester) => tester
    .state<ScrollableState>(
      find
          .descendant(
            of: find.byType(CustomScrollView),
            matching: find.byType(Scrollable),
          )
          .first,
    )
    .position;

SystemUiOverlayStyle _statusStyle(WidgetTester tester) => tester
    .widget<AnnotatedRegion<SystemUiOverlayStyle>>(
      find
          .descendant(
            of: find.byType(HomeScreen),
            matching: find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
          )
          .first,
    )
    .value;

/// A point on the wall's top row.
Offset _onHero(WidgetTester tester) =>
    tester.getCenter(find.byKey(const Key('home-hero-row-0')));

/// Where the wall's first card sits now.
double _firstCardLeft(WidgetTester tester) =>
    tester.getTopLeft(find.byKey(const Key('home-hero-card-0-0'))).dx;

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('a vertical drag on the wall scrolls Home; a sideways one '
      'moves the wall, not the page', (tester) async {
    await _pumpHome(tester);
    expect(_homeScroll(tester).pixels, 0);
    expect(_homeScroll(tester).maxScrollExtent, greaterThan(150));

    await tester.dragFrom(_onHero(tester), const Offset(0, -120));
    await tester.pump(const Duration(seconds: 1));
    expect(_homeScroll(tester).pixels, greaterThan(80));

    _homeScroll(tester).jumpTo(0);
    await tester.pump();

    final before = _firstCardLeft(tester);
    await tester.dragFrom(_onHero(tester), const Offset(-150, 0));
    await tester.pump();
    expect(_homeScroll(tester).pixels, 0);
    // The row loops: measure the move within one set of cards.
    final set =
        tester.getTopLeft(find.byKey(const Key('home-hero-card-0-7'))).dx -
        tester.getTopLeft(find.byKey(const Key('home-hero-card-0-0'))).dx;
    var moved = (_firstCardLeft(tester) - before) % set;
    if (moved > set / 2) moved -= set;
    expect(moved, lessThan(-100), reason: 'dragged left with the finger');
  });

  testWidgets('logo and bell float over the top of the hero, below the '
      'status bar and above the wall\'s first row; the greeting follows the '
      'hero', (tester) async {
    await _pumpHome(tester);

    final media = tester.getRect(find.byKey(const Key('home-hero')));
    final firstRow = tester.getRect(find.byKey(const Key('home-hero-row-0')));
    for (final key in const [Key('home-hero-logo'), Key('home-bell')]) {
      expect(find.byKey(key).hitTestable(), findsOneWidget, reason: '$key');
      final chip = tester.getRect(find.byKey(key));
      expect(chip.top, greaterThanOrEqualTo(_statusBar));
      expect(media.contains(chip.center), isTrue, reason: '$key on the hero');
      expect(chip.bottom, lessThanOrEqualTo(firstRow.top), reason: '$key');
    }
    expect(
      tester.getCenter(find.byKey(const Key('home-hero-logo'))).dx,
      lessThan(200),
    );
    expect(
      tester.getCenter(find.byKey(const Key('home-bell'))).dx,
      greaterThan(200),
    );
    final greeting = tester.getRect(find.textContaining('Good '));
    expect(greeting.top, greaterThanOrEqualTo(media.bottom - 0.5));
  });

  testWidgets('scrolling fades the video in step with it leaving: half '
      'way it is still half visible, no dead band (tester report)', (
    tester,
  ) async {
    await _pumpHome(tester);
    final media = homeHeroMediaHeight(const Size(400, 900));
    double wash() {
      final boxes = tester
          .widgetList<ColoredBox>(
            find.descendant(
              of: find.byKey(const Key('home-hero')),
              matching: find.byType(ColoredBox),
            ),
          )
          .map((b) => b.color.a)
          .where((a) => a > 0 && a < 1)
          .toList();
      return boxes.isEmpty ? 0 : boxes.first;
    }

    _homeScroll(tester).jumpTo(media / 2);
    await tester.pump();
    expect(wash(), closeTo(0.5, 0.05));
  });

  testWidgets('scrolling never lets the drifting hero cover the content '
      'below it: the media stays inside its own box', (tester) async {
    await _pumpHome(tester);
    final media = homeHeroMediaHeight(const Size(400, 900));
    _homeScroll(tester).jumpTo(media / 2);
    await tester.pump();

    // Just below the hero's box, where the slower-moving media would spill,
    // at the left edge (no text there): the page shows, not the dark media.
    final box = tester.getRect(find.byKey(const Key('home-hero')));
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find
          .ancestor(
            of: find.byKey(const Key('home-hero')),
            matching: find.byType(RepaintBoundary),
          )
          .first,
    );
    final origin = boundary.localToGlobal(Offset.zero);
    final at = Offset(4, box.bottom + 12) - origin;
    final pixel = await tester.runAsync(() async {
      final image = await boundary.toImage();
      final bytes = await image.toByteData();
      final i = (at.dy.round() * image.width + at.dx.round()) * 4;
      return Color.fromARGB(
        bytes!.getUint8(i + 3),
        bytes.getUint8(i),
        bytes.getUint8(i + 1),
        bytes.getUint8(i + 2),
      );
    });
    final page = Theme.of(
      tester.element(find.byType(HomeScreen)),
    ).scaffoldBackgroundColor;
    expect(
      pixel!.computeLuminance(),
      closeTo(page.computeLuminance(), 0.05),
      reason: 'the hero paints below its own box',
    );
  });

  testWidgets('status bar: light icons and no backing over the hero; a '
      'solid backing and theme icons once scrolled past', (tester) async {
    await _pumpHome(tester);
    const backing = Key('home-status-bar-backing');
    expect(find.byKey(backing), findsNothing);
    expect(_statusStyle(tester).statusBarIconBrightness, Brightness.light);

    _homeScroll(tester).jumpTo(homeHeroMediaHeight(const Size(400, 900)));
    await tester.pump();
    expect(find.byKey(backing), findsOneWidget);
    expect(tester.getSize(find.byKey(backing)).height, _statusBar);
    expect(_statusStyle(tester).statusBarIconBrightness, Brightness.dark);
  });

  testWidgets('no announcements: the block is hidden, heading included', (
    tester,
  ) async {
    await _pumpHome(tester);
    expect(find.byKey(const Key('home-announcements-see-all')), findsNothing);
    expect(find.textContaining('No announcements'), findsNothing);
  });
}
