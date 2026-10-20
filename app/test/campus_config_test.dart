import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kharis_app/features/home/data/daily_content_repository.dart';
import 'package:kharis_app/features/home/data/live_repository.dart';
import 'package:kharis_app/features/home/data/news_repository.dart';
import 'package:kharis_app/features/home/presentation/screens/home_screen.dart';
import 'package:kharis_app/features/home/presentation/widgets/campus_card.dart';
import 'package:kharis_app/features/home/presentation/widgets/continue_listening_card.dart';
import 'package:kharis_app/features/onboarding/data/branch_repository.dart';
import 'package:kharis_app/shared/models/sermon.dart';
import 'package:kharis_app/shared/models/campus_config.dart';
import 'package:kharis_app/shared/providers/admin_provider.dart';
import 'package:kharis_app/shared/providers/auth_provider.dart';
import 'package:kharis_app/shared/providers/branch_provider.dart';
import 'package:kharis_app/shared/providers/campus_config_provider.dart';
import 'package:kharis_app/shared/providers/onboarding_provider.dart';
import 'package:kharis_app/shared/providers/sermon_provider.dart';

Branch _branch(
  String name, {
  HomeLayout? home,
  GivingDetails? giving,
  CampusContact contact = const CampusContact(),
  List<CampusVenue> venues = const [],
  List<CampusService> services = const [],
  String? address,
  String? meetingDays,
  String? meetingTime,
}) => Branch(
  id: name.toLowerCase(),
  name: name,
  subtitle: '',
  gradientStart: const Color(0xFF5D3FD3),
  gradientEnd: const Color(0xFF451EBB),
  home: home,
  giving: giving,
  contact: contact,
  venues: venues,
  services: services,
  address: address,
  meetingDays: meetingDays,
  meetingTime: meetingTime,
);

const _campusLayout = HomeLayout([
  HomeSection(HomeSectionId.events),
  HomeSection(HomeSectionId.reading),
  HomeSection(HomeSectionId.announcements, enabled: false),
]);

/// Resolves the branch settings for a member at [campus] (null = All
/// branches) against [branches].
Future<ProviderContainer> _resolve({
  required String? campus,
  List<Branch> branches = const [],
}) async {
  final container = ProviderContainer(
    overrides: [
      currentBranchProvider.overrideWith((ref) => Stream.value(campus)),
      branchesProvider.overrideWith((ref) => Stream.value(branches)),
    ],
  );
  addTearDown(container.dispose);
  container.listen(effectiveHomeLayoutProvider, (_, _) {});
  await container.read(currentBranchProvider.future);
  await container.read(branchesProvider.future);
  return container;
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('Home layout resolution', () {
    test('the campus layout wins over the built-in one', () async {
      final c = await _resolve(
        campus: 'London',
        branches: [_branch('London', home: _campusLayout)],
      );
      expect(c.read(effectiveHomeLayoutProvider), _campusLayout);
      // Order kept; the disabled block is hidden.
      expect(c.read(effectiveHomeLayoutProvider).visible, [
        HomeSectionId.events,
        HomeSectionId.reading,
      ]);
    });

    test('a campus without a layout uses the built-in one', () async {
      final c = await _resolve(
        campus: 'London',
        branches: [
          _branch('London'),
          _branch('Leeds', home: _campusLayout),
        ],
      );
      expect(c.read(effectiveHomeLayoutProvider), HomeLayout.fallback);
    });

    test('All branches uses the built-in layout', () async {
      final c = await _resolve(
        campus: null,
        branches: [_branch('London', home: _campusLayout)],
      );
      expect(c.read(effectiveHomeLayoutProvider), HomeLayout.fallback);
    });

    test('the built-in layout ships giving disabled', () async {
      final c = await _resolve(campus: 'London', branches: [_branch('London')]);
      expect(c.read(effectiveHomeLayoutProvider), HomeLayout.fallback);
      expect(
        c.read(effectiveHomeLayoutProvider).visible,
        isNot(contains(HomeSectionId.giving)),
        reason: 'giving ships disabled',
      );
    });
  });

  group('CampusCard', () {
    Future<void> pump(WidgetTester tester, Branch branch) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentBranchProvider.overrideWith(
              (ref) => Stream.value(branch.name),
            ),
            branchesProvider.overrideWith((ref) => Stream.value([branch])),
          ],
          child: const MaterialApp(
            home: Scaffold(body: SingleChildScrollView(child: CampusCard())),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
    }

    testWidgets('renders active services with their venue and contacts', (
      tester,
    ) async {
      await pump(
        tester,
        _branch(
          'London',
          contact: const CampusContact(
            phone: '020 7000 0000',
            email: 'london@kharis.org',
            instagram: '@kharislondon',
          ),
          venues: const [
            CampusVenue(
              id: 'hall',
              name: 'Kensington Town Hall',
              addressLine1: 'Hornton St',
              city: 'London',
              postcode: 'W8 7NX',
            ),
          ],
          services: const [
            CampusService(
              id: 'am',
              name: 'Sunday Service',
              day: 'Sundays',
              startTime: '10:00',
              endTime: '12:00',
              venueId: 'hall',
              order: 1,
            ),
            CampusService(
              id: 'pm',
              name: 'Evening Prayer',
              day: 'Wednesdays',
              startTime: '19:00',
              venueId: 'hall',
              order: 2,
            ),
          ],
          // Legacy mirrors are ignored once services exist.
          meetingDays: 'Saturdays',
          meetingTime: '9:00 AM',
        ),
      );

      expect(find.text('London'), findsOneWidget);
      expect(find.text('Sunday Service'), findsOneWidget);
      expect(
        find.text('Sundays \u00b7 10:00 AM \u2013 12:00 PM'),
        findsOneWidget,
      );
      expect(find.text('Wednesdays \u00b7 7:00 PM'), findsOneWidget);
      expect(find.textContaining('Saturdays'), findsNothing);
      expect(
        tester.getTopLeft(find.text('Sunday Service')).dy,
        lessThan(tester.getTopLeft(find.text('Evening Prayer')).dy),
      );
      // One venue block with directions for both services.
      expect(find.text('Kensington Town Hall'), findsOneWidget);
      expect(find.text('Hornton St, London, W8 7NX'), findsOneWidget);
      expect(find.byKey(const Key('campus-directions-hall')), findsOneWidget);
      expect(find.byKey(const Key('campus-call')), findsOneWidget);
      expect(find.byKey(const Key('campus-email')), findsOneWidget);
      expect(find.byKey(const Key('campus-instagram')), findsOneWidget);
    });

    testWidgets('two venues: each named once with its own services under it; '
        'notes both share said once; a repeated address part shown once', (
      tester,
    ) async {
      const parking = 'Free parking is available at the venue.';
      const station = 'The venue is approximately five minutes away.';
      await pump(
        tester,
        _branch(
          'Bristol',
          venues: const [
            CampusVenue(
              id: 'sun',
              name: 'Sunday Service',
              addressLine1: 'Abbeywood Community School',
              addressLine2: 'Engineering Centre,  Stoke Gifford',
              city: 'Bristol',
              postcode: 'BS34 8SF',
              parkingInfo: parking,
              publicTransportInfo: station,
              directionsText: '',
            ),
            CampusVenue(
              id: 'mid',
              name: 'Midweek Service',
              addressLine1: '6 Ashley Road',
              addressLine2: '6 Ashley Road,  St. Paul\u2019s',
              city: 'Bristol',
              postcode: 'BS6 5NL',
              parkingInfo: parking,
              publicTransportInfo: station,
            ),
          ],
          services: const [
            CampusService(
              id: 's1',
              name: 'Sunday 1st Service',
              day: 'Sunday',
              startTime: '11:00',
              venueId: 'sun',
              order: 1,
            ),
            CampusService(
              id: 'w',
              name: 'Wednesday Service',
              day: 'Wednesday',
              startTime: '18:30',
              venueId: 'mid',
              order: 2,
            ),
            CampusService(
              id: 's2',
              name: 'Sunday 2nd Service',
              day: 'Sunday',
              startTime: '13:00',
              venueId: 'sun',
              order: 3,
            ),
          ],
        ),
      );

      double top(String text) => tester.getTopLeft(find.text(text)).dy;
      // Venue names appear once each, as headings, not under every service.
      expect(find.text('Sunday Service'), findsOneWidget);
      expect(find.text('Midweek Service'), findsOneWidget);
      // Each venue's services sit under it, before the next venue.
      expect(top('Sunday Service'), lessThan(top('Sunday 1st Service')));
      expect(top('Sunday 1st Service'), lessThan(top('Sunday 2nd Service')));
      expect(top('Sunday 2nd Service'), lessThan(top('Midweek Service')));
      expect(top('Midweek Service'), lessThan(top('Wednesday Service')));
      // Notes both venues carry: said once, after the venues.
      expect(find.text(parking), findsOneWidget);
      expect(find.text(station), findsOneWidget);
      expect(top(parking), greaterThan(top('Wednesday Service')));
      expect(
        find.text('6 Ashley Road, St. Paul\u2019s, Bristol, BS6 5NL'),
        findsOneWidget,
      );
      expect(
        find.text(
          'Abbeywood Community School, Engineering Centre, Stoke Gifford, '
          'Bristol, BS34 8SF',
        ),
        findsOneWidget,
      );
    });

    testWidgets('falls back to the legacy meeting fields', (tester) async {
      await pump(
        tester,
        _branch(
          'Romford',
          address: 'Marshalls Park Academy, Romford',
          meetingDays: 'Sundays',
          meetingTime: '13:00',
        ),
      );
      expect(find.text('Sundays \u00b7 1:00 PM'), findsOneWidget);
      expect(find.text('Marshalls Park Academy, Romford'), findsOneWidget);
      expect(find.byKey(const Key('campus-directions')), findsOneWidget);
      expect(find.byKey(const Key('campus-call')), findsNothing);
    });

    testWidgets('collapses when the campus has nothing to show', (
      tester,
    ) async {
      await pump(tester, _branch('Leeds'));
      expect(find.byKey(const Key('campus-card')), findsNothing);
    });

    test('Instagram handles and URLs both become links', () {
      expect(
        instagramUri('@kharislondon').toString(),
        'https://www.instagram.com/kharislondon/',
      );
      expect(
        instagramUri('https://instagram.com/kharis').toString(),
        'https://instagram.com/kharis',
      );
      expect(instagramUri('@'), isNull);
    });
  });

  group('Home', () {
    Future<void> pumpHome(WidgetTester tester, HomeLayout? campusHome) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();
      tester.view.physicalSize = const Size(1200, 4000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            currentBranchProvider.overrideWith((ref) => Stream.value('London')),
            currentUserProvider.overrideWith((ref) => Stream.value(null)),
            branchesProvider.overrideWith(
              (ref) => Stream.value([_branch('London', home: campusHome)]),
            ),
            // One live notice, so the Announcements block has something to
            // show (it hides, heading included, when empty).
            newsProvider.overrideWith(
              (ref, b) async => [
                NewsItem(
                  id: 'n1',
                  title: 'Welcome',
                  type: 'Announcement',
                  publishedAt: DateTime(2026),
                ),
              ],
            ),
            upcomingEventsProvider.overrideWith(
              (ref, b) => Stream.value(const []),
            ),
            liveStatusProvider.overrideWith(
              (ref) => Stream.value(LiveStatus.notLive),
            ),
            dailyContentProvider.overrideWith(
              (ref) => Stream.value(
                const DailyContent(
                  reading: DailyEntry(
                    title: 'John 3:16',
                    reference: 'John 3:16',
                  ),
                  prayer: DailyEntry(
                    title: 'Lord, teach us to pray.',
                    reference: 'Luke 11:1',
                  ),
                ),
              ),
            ),
            dailyMessageProvider.overrideWith((ref) => Stream.value(null)),
            continueListeningProvider.overrideWith((ref) => null),
            featuredVideoProvider.overrideWith((ref) async => null),
            latestSermonsProvider.overrideWith((ref) => const <Sermon>[]),
          ],
          child: const MaterialApp(home: HomeScreen()),
        ),
      );
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 150));
      }
    }

    /// The block inside a Home section's sliver (a box, so it has a position).
    Finder section(HomeSectionId id) => find
        .descendant(
          of: find.byKey(ValueKey('home-section-${id.name}')),
          matching: find.byWidgetPredicate((_) => true),
        )
        .first;

    testWidgets('renders a branch layout in order, hiding disabled blocks', (
      tester,
    ) async {
      await pumpHome(
        tester,
        const HomeLayout([
          HomeSection(HomeSectionId.giving),
          HomeSection(HomeSectionId.events),
          HomeSection(HomeSectionId.reading),
          HomeSection(HomeSectionId.announcements, enabled: false),
        ]),
      );

      expect(
        find.byKey(const ValueKey('home-section-announcements')),
        findsNothing,
      );
      expect(find.byKey(const Key('home-announcements-see-all')), findsNothing);
      expect(find.text('Give'), findsOneWidget);
      expect(find.text('Read now'), findsOneWidget);
      final ys = [
        for (final id in [
          HomeSectionId.giving,
          HomeSectionId.events,
          HomeSectionId.reading,
        ])
          tester.getTopLeft(section(id)).dy,
      ];
      expect(ys, orderedEquals([...ys]..sort()));
    });

    testWidgets('the built-in layout has no hero message and no giving', (
      tester,
    ) async {
      await pumpHome(tester, null);
      expect(find.text('Read now'), findsOneWidget);
      expect(
        find.byKey(const Key('home-announcements-see-all')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('home-events-see-all')), findsOneWidget);
      expect(find.byKey(const Key('home-giving')), findsNothing);
      expect(find.byKey(const Key('home-live-now')), findsNothing);
    });
  });
}
