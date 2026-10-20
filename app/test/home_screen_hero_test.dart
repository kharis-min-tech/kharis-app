import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kharis_app/features/calendar/data/event_repository.dart';
import 'package:kharis_app/features/home/data/featured_video_repository.dart';
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

/// Home with the hero on top: drags on it scroll the page, the logo and bell
/// float over it, the status bar gets a backing once it has scrolled away,
/// and empty blocks stay hidden. The YouTube surface is a plain box.

const _statusBar = 47.0;

const _clip = FeaturedVideo(
  workspace: 'app',
  url: 'https://youtu.be/REhGafc8hdg',
  videoId: 'REhGafc8hdg',
  title: 'Year of Faith highlight',
  thumbnailUrl: 'https://i.ytimg.com/vi/REhGafc8hdg/hqdefault.jpg',
);

final _flyerEvent = Event(
  id: 'e-flyer',
  title: 'Harvest Sunday',
  startTime: DateTime.now().add(const Duration(days: 4)),
  imageUrl: 'https://cdn.example.org/flyer.jpg',
);

Future<void> _pumpHome(
  WidgetTester tester, {
  FeaturedVideo? video = _clip,
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
        featuredVideoProvider.overrideWith((ref) async => video),
        latestSermonsProvider.overrideWith((ref) => const <Sermon>[]),
        heroVideoSurfaceProvider.overrideWithValue(
          (videoId, muted, onPlaying) => const ColoredBox(color: Colors.black),
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

/// A point on the hero's media, in its upper half.
Offset _onHero(WidgetTester tester) {
  final media = tester.getRect(find.byKey(const Key('home-hero-pager')));
  return Offset(media.center.dx, media.top + media.height * 0.3);
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('a vertical drag on any hero slide scrolls Home; a horizontal '
      'one changes slide', (tester) async {
    final semantics = tester.ensureSemantics();
    await _pumpHome(
      tester,
      events: [_flyerEvent],
      news: [
        NewsItem(
          id: 'n1',
          title: 'Welcome',
          type: 'Announcement',
          publishedAt: DateTime(2026),
        ),
      ],
    );
    expect(find.byKey(const Key('home-hero-video-surface')), findsOneWidget);
    expect(_homeScroll(tester).pixels, 0);
    expect(_homeScroll(tester).maxScrollExtent, greaterThan(150));

    // On the video slide (a 120 px drag, less the touch slop).
    await tester.dragFrom(_onHero(tester), const Offset(0, -120));
    await tester.pump(const Duration(seconds: 1));
    expect(_homeScroll(tester).pixels, greaterThan(80));

    _homeScroll(tester).jumpTo(0);
    await tester.pump();

    // Sideways to the flyer.
    await tester.dragFrom(_onHero(tester), const Offset(-300, 0));
    await tester.pump(const Duration(seconds: 1));
    expect(find.bySemanticsLabel('Harvest Sunday'), findsOneWidget);
    expect(_homeScroll(tester).pixels, 0);

    // On the flyer slide.
    await tester.dragFrom(_onHero(tester), const Offset(0, -120));
    await tester.pump(const Duration(seconds: 1));
    expect(_homeScroll(tester).pixels, greaterThan(80));
    semantics.dispose();
  });

  testWidgets('logo and bell float over the top of the hero, below the '
      'status bar; the mute chip stays clear of the title card; the '
      'greeting follows the hero', (tester) async {
    await _pumpHome(tester);

    final media = tester.getRect(find.byKey(const Key('home-hero-pager')));
    final card = tester.getRect(find.byKey(const Key('home-hero-card')));
    // The card rises over the media's bottom edge; the mute chip sits in
    // the media's right corner above it, never under it.
    expect(card.top, lessThan(media.bottom));
    expect(card.bottom, greaterThan(media.bottom));
    final mute = tester.getRect(find.byKey(const Key('home-hero-mute')));
    expect(find.byKey(const Key('home-hero-mute')).hitTestable(), findsOne);
    expect(media.contains(mute.center), isTrue);
    expect(mute.center.dx, greaterThan(media.width - 60));
    expect(mute.bottom, lessThanOrEqualTo(card.top));
    for (final key in const [Key('home-hero-logo'), Key('home-bell')]) {
      expect(find.byKey(key).hitTestable(), findsOneWidget, reason: '$key');
      final chip = tester.getRect(find.byKey(key));
      expect(chip.top, greaterThanOrEqualTo(_statusBar));
      expect(media.contains(chip.center), isTrue, reason: '$key on the hero');
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
    expect(greeting.top, greaterThan(card.bottom));
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

  testWidgets('no hero: the greeting header leads; no announcements: the '
      'block is hidden, heading included', (tester) async {
    await _pumpHome(tester, video: null);

    expect(find.byKey(const Key('home-hero')), findsNothing);
    expect(find.textContaining('Good '), findsOneWidget);
    expect(find.byKey(const Key('home-branch-change')), findsOneWidget);
    expect(find.byKey(const Key('home-announcements-see-all')), findsNothing);
    expect(find.textContaining('No announcements'), findsNothing);
    // Nothing shows through under the clock without a hero either.
    expect(find.byKey(const Key('home-status-bar-backing')), findsOneWidget);
  });
}
