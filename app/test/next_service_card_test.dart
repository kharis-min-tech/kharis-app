import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:kharis_app/features/calendar/data/event_repository.dart';
import 'package:kharis_app/features/home/presentation/screens/branch_screen.dart';
import 'package:kharis_app/features/home/presentation/widgets/next_service_card.dart';
import 'package:kharis_app/features/home/presentation/widgets/upcoming_events_strip.dart';
import 'package:kharis_app/features/onboarding/data/branch_repository.dart';
import 'package:kharis_app/shared/models/campus_config.dart';
import 'package:kharis_app/shared/providers/admin_provider.dart';
import 'package:kharis_app/shared/providers/branch_provider.dart';
import 'package:kharis_app/shared/providers/campus_config_provider.dart';
import 'package:kharis_app/shared/providers/location_provider.dart';
import 'package:kharis_app/shared/providers/notification_feed_provider.dart';
import 'package:kharis_app/shared/widgets/branch_picker_sheet.dart';

import 'support/fake_location_service.dart';

// 18 Oct 2026 is a Sunday.
DateTime _sunday(int hour, [int minute = 0]) =>
    DateTime(2026, 10, 18, hour, minute);

const _hall = CampusVenue(
  id: 'hall',
  name: 'Kensington Town Hall',
  addressLine1: 'Hornton St',
  city: 'London',
  postcode: 'W8 7NX',
);

const _annex = CampusVenue(id: 'annex', name: 'Church Annex', city: 'London');

// Listed out of time order: the card sorts by start time.
const _late = CampusService(
  id: 'pm',
  name: 'Second Service',
  day: 'Sunday',
  startTime: '13:00',
  venueId: 'hall',
);
const _early = CampusService(
  id: 'am',
  name: 'First Service',
  day: 'Sunday',
  startTime: '11:00',
  venueId: 'hall',
);
const _midweek = CampusService(
  id: 'wed',
  name: 'Midweek Service',
  day: 'Wednesday',
  startTime: '19:00',
  venueId: 'hall',
);

Branch _branch({
  List<CampusService> services = const [_late, _early, _midweek],
  List<CampusVenue> venues = const [_hall, _annex],
  CampusContact contact = const CampusContact(
    email: 'london@kharis.org',
    phone: '020 7000 0000',
  ),
}) => Branch(
  id: 'london',
  name: 'London',
  subtitle: '',
  gradientStart: const Color(0xFF5D3FD3),
  gradientEnd: const Color(0xFF451EBB),
  contact: contact,
  venues: venues,
  services: services,
);

Event _weekly(
  String id,
  String title,
  List<int> days, {
  String? branch = 'London',
  String? imageUrl,
}) => Event(
  id: id,
  title: title,
  branch: branch,
  imageUrl: imageUrl,
  startTime: DateTime(2026, 10, 25, 11),
  recurrenceDays: days,
);

final _serviceEvent = _weekly('sun', 'Sunday Service', const [
  0,
], imageUrl: 'https://cdn.example.org/sunday.jpg');

final _prayerNight = Event(
  id: 'prayer',
  title: 'Prayer Night',
  branch: 'London',
  startTime: DateTime(2026, 10, 23, 19),
);

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('next service day', () {
    test('today, while its first service has yet to start', () {
      final next = nextServiceDay(_branch().services, _sunday(9))!;
      expect(next.daysAway, 0);
      expect(next.date, DateTime(2026, 10, 18));
      expect(next.services.map((s) => s.id), ['am', 'pm']);
    });

    test('today, while a later service has yet to start', () {
      final next = nextServiceDay(_branch().services, _sunday(12, 30))!;
      expect(next.daysAway, 0);
      expect(next.services.map((s) => s.id), ['am', 'pm']);
    });

    test('once the last service today has started, the next day', () {
      final next = nextServiceDay(_branch().services, _sunday(13))!;
      expect(next.daysAway, 3);
      expect(next.date, DateTime(2026, 10, 21));
      expect(next.services.map((s) => s.id), ['wed']);
    });

    test('wraps past Saturday into the next week', () {
      final next = nextServiceDay(const [_early], DateTime(2026, 10, 24, 20))!;
      expect(next.daysAway, 1);
      expect(next.date, DateTime(2026, 10, 25));
    });

    test(
      'a branch meeting once a week, after it met today, is a week away',
      () {
        final next = nextServiceDay(const [
          _midweek,
        ], DateTime(2026, 10, 21, 20))!;
        expect(next.daysAway, 7);
        expect(next.date, DateTime(2026, 10, 28));
      },
    );

    test('services with no weekday give no next day', () {
      expect(
        nextServiceDay(const [
          CampusService(id: 'x', name: 'Prayer', startTime: '10:00'),
        ], _sunday(9)),
        isNull,
      );
    });

    test('labels', () {
      expect(serviceTimesLabel(const [_early, _late]), '11:00 AM & 1:00 PM');
      expect(relativeDayLabel(0), 'Today');
      expect(relativeDayLabel(1), 'Tomorrow');
      expect(relativeDayLabel(3), 'In 3 days');
    });
  });

  group('isBranchServiceEvent', () {
    final branch = _branch();

    test('a weekly event on a service weekday is a branch service', () {
      expect(isBranchServiceEvent(_serviceEvent, branch), isTrue);
      expect(
        isBranchServiceEvent(_weekly('w', 'Midweek', const [3]), branch),
        isTrue,
      );
    });

    test('a weekly event on a day the branch does not meet is not', () {
      expect(
        isBranchServiceEvent(_weekly('m', 'Choir', const [1]), branch),
        isFalse,
      );
    });

    test('another branch\u2019s weekly event is not', () {
      expect(
        isBranchServiceEvent(
          _weekly('man', 'Sunday Service', const [0], branch: 'Manchester'),
          branch,
        ),
        isFalse,
      );
    });

    test('a one-off event is not', () {
      expect(
        isBranchServiceEvent(
          Event(
            id: 'o',
            title: 'Harvest',
            branch: 'London',
            startTime: DateTime(2026, 10, 25, 11),
          ),
          branch,
        ),
        isFalse,
      );
    });
  });

  group('NextServiceCard', () {
    Future<void> pump(
      WidgetTester tester, {
      Branch? branch,
      List<Event> events = const [],
      DateTime? now,
    }) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final router = GoRouter(
        initialLocation: '/home',
        routes: [
          GoRoute(
            path: '/home',
            builder: (_, _) => const Scaffold(
              body: SingleChildScrollView(child: NextServiceCard()),
            ),
          ),
          GoRoute(path: '/branch', builder: (_, _) => const BranchScreen()),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentBranchProvider.overrideWith(
              (ref) => Stream.value(branch?.name),
            ),
            branchesProvider.overrideWith((ref) => Stream.value([?branch])),
            locationServiceProvider.overrideWithValue(FakeLocationService()),
            campusUpcomingEventsProvider.overrideWithValue(
              AsyncValue.data(events),
            ),
            nextServiceClockProvider.overrideWithValue(() => now ?? _sunday(9)),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pump();
      await tester.pump();
    }

    testWidgets('shows the day\u2019s flyer, times and venue once', (
      tester,
    ) async {
      await pump(tester, branch: _branch(), events: [_serviceEvent]);

      expect(find.byKey(const Key('home-next-service')), findsOneWidget);
      final image = tester.widget<CachedNetworkImage>(
        find.byType(CachedNetworkImage),
      );
      expect(image.imageUrl, 'https://cdn.example.org/sunday.jpg');
      expect(find.text('Sunday'), findsOneWidget);
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('11:00 AM & 1:00 PM'), findsOneWidget);
      expect(find.text('Kensington Town Hall'), findsOneWidget);
      expect(find.text('Hornton St, London, W8 7NX'), findsOneWidget);
      expect(find.text('Midweek Service'), findsNothing);
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Call'), findsOneWidget);
      expect(find.text('Instagram'), findsNothing);
    });

    testWidgets('no flyer when the day has no service event with one', (
      tester,
    ) async {
      await pump(
        tester,
        branch: _branch(),
        events: [
          _weekly('sun', 'Sunday Service', const [0]),
        ],
      );
      expect(find.byType(CachedNetworkImage), findsNothing);
      expect(find.text('11:00 AM & 1:00 PM'), findsOneWidget);
    });

    testWidgets('after today\u2019s services, the next day shows', (
      tester,
    ) async {
      await pump(
        tester,
        branch: _branch(),
        events: [_serviceEvent],
        now: _sunday(14),
      );
      expect(find.text('Wednesday'), findsOneWidget);
      expect(find.text('In 3 days'), findsOneWidget);
      expect(find.text('7:00 PM'), findsOneWidget);
      // The Sunday flyer belongs to Sunday, not Wednesday.
      expect(find.byType(CachedNetworkImage), findsNothing);
    });

    testWidgets('services at several venues list each venue with its times', (
      tester,
    ) async {
      await pump(
        tester,
        branch: _branch(
          services: const [
            _early,
            CampusService(
              id: 'annex-am',
              name: 'Youth Service',
              day: 'Sunday',
              startTime: '11:30',
              venueId: 'annex',
            ),
            _late,
          ],
        ),
      );
      expect(find.text('Kensington Town Hall'), findsOneWidget);
      expect(find.text('11:00 AM & 1:00 PM'), findsOneWidget);
      expect(find.text('Church Annex'), findsOneWidget);
      expect(find.text('11:30 AM'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Kensington Town Hall')).dy,
        lessThan(tester.getTopLeft(find.text('Church Annex')).dy),
      );
    });

    testWidgets('Full timetable opens the branch page; Back returns', (
      tester,
    ) async {
      await pump(tester, branch: _branch());

      await tester.tap(find.text('Full timetable'));
      await tester.pumpAndSettle();
      expect(find.byType(BranchScreen), findsOneWidget);
      expect(find.widgetWithText(AppBar, 'London'), findsOneWidget);
      // The whole timetable, midweek included.
      expect(find.text('Midweek Service'), findsOneWidget);

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.byType(BranchScreen), findsNothing);
      expect(find.byKey(const Key('home-next-service')), findsOneWidget);
    });

    testWidgets('the Branch page names the branch once and offers Change', (
      tester,
    ) async {
      await pump(tester, branch: _branch());
      await tester.tap(find.text('Full timetable'));
      await tester.pumpAndSettle();

      expect(find.text('London'), findsOneWidget);
      expect(find.widgetWithText(AppBar, 'London'), findsOneWidget);
      expect(find.text('YOUR BRANCH'), findsNothing);
      expect(find.bySemanticsLabel('Change branch'), findsOneWidget);

      await tester.tap(find.byKey(const Key('home-branch-change')));
      await tester.pumpAndSettle();
      expect(find.byType(BranchPickerSheet), findsOneWidget);
      expect(
        find.byKey(const ValueKey('branch-choice-London')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('branch-use-location')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('branch-choice-all')),
        findsNothing,
        reason: '"All branches" is not a member\u2019s branch',
      );
    });

    testWidgets('tapping the card opens the branch page', (tester) async {
      await pump(tester, branch: _branch());

      await tester.tap(find.text('Sunday'));
      await tester.pumpAndSettle();
      expect(find.byType(BranchScreen), findsOneWidget);
    });

    testWidgets(
      'renders nothing while Home\u2019s branch is unknown or has no services',
      (tester) async {
        await pump(tester);
        expect(find.byKey(const Key('home-next-service')), findsNothing);

        await pump(tester, branch: _branch(services: const []));
        expect(find.byKey(const Key('home-next-service')), findsNothing);
      },
    );
  });

  group('UpcomingEventsStrip', () {
    Future<void> pump(WidgetTester tester, {Branch? branch}) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentBranchProvider.overrideWith(
              (ref) => Stream.value(branch?.name),
            ),
            homeCampusProvider.overrideWithValue(branch),
            campusUpcomingEventsProvider.overrideWithValue(
              AsyncValue.data([_serviceEvent, _prayerNight]),
            ),
          ],
          child: const MaterialApp(home: Scaffold(body: UpcomingEventsStrip())),
        ),
      );
      await tester.pump();
    }

    testWidgets('with a branch, its weekly service is left to Next service', (
      tester,
    ) async {
      await pump(tester, branch: _branch());
      expect(find.text('Sunday Service'), findsNothing);
      expect(find.text('Prayer Night'), findsOneWidget);
    });

    testWidgets(
      'while Home\u2019s branch is unknown, the weekly service stays',
      (tester) async {
        await pump(tester);
        expect(find.text('Sunday Service'), findsOneWidget);
        expect(find.text('Prayer Night'), findsOneWidget);
      },
    );
  });
}
