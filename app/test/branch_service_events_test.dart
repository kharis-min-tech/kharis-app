import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kharis_app/features/calendar/data/branch_service_events.dart';
import 'package:kharis_app/features/calendar/data/event_repository.dart';
import 'package:kharis_app/features/calendar/data/rsvp_repository.dart';
import 'package:kharis_app/features/calendar/presentation/screens/calendar_screen.dart';
import 'package:kharis_app/features/calendar/presentation/screens/event_detail_screen.dart';
import 'package:kharis_app/features/onboarding/data/branch_repository.dart';
import 'package:kharis_app/shared/models/campus_config.dart';
import 'package:kharis_app/shared/providers/admin_provider.dart';
import 'package:kharis_app/shared/providers/auth_provider.dart';
import 'package:kharis_app/shared/providers/branch_provider.dart';
import 'package:kharis_app/shared/providers/content_api_provider.dart';
import 'package:kharis_app/shared/providers/notification_feed_provider.dart';
import 'package:kharis_app/shared/providers/onboarding_provider.dart';
import 'package:kharis_app/shared/providers/sermon_provider.dart';

import 'support/supabase_stub.dart';

const _hall = CampusVenue(
  id: 'v1',
  name: 'Main Hall',
  addressLine1: '6 Ashley Road',
  city: 'Bristol',
);

const _bristol = Branch(
  id: 'bristol',
  name: 'Bristol',
  subtitle: '',
  gradientStart: Colors.black,
  gradientEnd: Colors.black,
  venues: [_hall],
  services: [
    CampusService(
      id: 'sun',
      name: 'Sunday Service',
      day: 'Sunday',
      startTime: '12:00',
      endTime: '14:00',
      venueId: 'v1',
    ),
    CampusService(
      id: 'wed',
      name: 'Midweek Service',
      day: 'Wednesday',
      startTime: '19:00',
      venueId: 'v1',
    ),
    CampusService(
      id: 'off',
      name: 'Retired Service',
      day: 'Friday',
      startTime: '19:00',
      isActive: false,
    ),
    CampusService(id: 'nodate', name: 'By arrangement', startTime: '10:00'),
    CampusService(id: 'notime', name: 'Open house', day: 'Saturday'),
  ],
);

const _london = Branch(
  id: 'london',
  name: 'London',
  subtitle: '',
  gradientStart: Colors.black,
  gradientEnd: Colors.black,
  services: [
    CampusService(
      id: 'sun',
      name: 'London Sunday Service',
      day: 'Sunday',
      startTime: '10:00',
    ),
  ],
);

// 25 October 2026 is a Sunday.
DateTime _sun(int hour, [int minute = 0]) =>
    DateTime(2026, 10, 25, hour, minute);

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('branchServiceEvents', () {
    test('today before a service starts lists today', () {
      final events = branchServiceEvents(_bristol, now: _sun(11));
      expect(events.map((e) => e.id), [
        'service:bristol:sun',
        'service:bristol:wed',
      ]);
      final sun = events.first;
      expect(sun.title, 'Sunday Service');
      expect(sun.startTime, _sun(12));
      expect(sun.endTime, _sun(14));
      expect(sun.recurrenceDays, [0]);
      expect(sun.isWeekly, isTrue);
      expect(sun.branch, 'Bristol');
      expect(sun.location, 'Main Hall');
      expect(sun.address, '6 Ashley Road, Bristol');
      expect(sun.imageUrl, isNull);
      expect(events.last.startTime, DateTime(2026, 10, 28, 19));
      expect(events.last.endTime, isNull);
    });

    test('a running service stays on today until it ends', () {
      final sun = branchServiceEvents(
        _bristol,
        now: _sun(13, 30),
      ).firstWhere((e) => e.id == 'service:bristol:sun');
      expect(sun.startTime, _sun(12));
    });

    test('after a service has ended it moves to next week', () {
      final sun = branchServiceEvents(
        _bristol,
        now: _sun(15),
      ).firstWhere((e) => e.id == 'service:bristol:sun');
      expect(sun.startTime, DateTime(2026, 11, 1, 12));
    });

    test('wraps the week and the month', () {
      final events = branchServiceEvents(
        _bristol,
        now: DateTime(2026, 10, 31, 23),
      );
      expect(events.first.id, 'service:bristol:sun');
      expect(events.first.startTime, DateTime(2026, 11, 1, 12));
      expect(events.last.startTime, DateTime(2026, 11, 4, 19));
    });

    test('a service running past midnight is still listed', () {
      const late = Branch(
        id: 'late',
        name: 'Late',
        subtitle: '',
        gradientStart: Colors.black,
        gradientEnd: Colors.black,
        address: '1 Night St',
        services: [
          CampusService(
            id: 'vigil',
            name: 'Vigil',
            day: 'Saturday',
            startTime: '22:00',
            endTime: '01:00',
          ),
        ],
      );
      final vigil = branchServiceEvents(late, now: _sun(0, 30)).single;
      expect(vigil.startTime, DateTime(2026, 10, 24, 22));
      expect(vigil.endTime, _sun(1));
      // No venue: the branch address, no venue name.
      expect(vigil.location, isNull);
      expect(vigil.address, '1 Night St');
    });

    test('skips inactive, undated and untimed services', () {
      final ids = branchServiceEvents(_bristol, now: _sun(11)).map((e) => e.id);
      expect(ids, isNot(contains('service:bristol:off')));
      expect(ids, isNot(contains('service:bristol:nodate')));
      expect(ids, isNot(contains('service:bristol:notime')));
    });

    test('resolves a generated id from the branches list', () {
      final e = branchServiceEventById(
        const [_london, _bristol],
        'service:bristol:wed',
        now: _sun(11),
      );
      expect(e?.title, 'Midweek Service');
      expect(
        branchServiceEventById(
          const [_bristol],
          'service:bristol:gone',
          now: _sun(11),
        ),
        isNull,
      );
    });
  });

  group('withBranchServiceEvents', () {
    Event studioWeekly({
      required String id,
      required String title,
      required DateTime start,
      String? branch = 'Bristol',
    }) => Event(
      id: id,
      title: title,
      startTime: start,
      branch: branch,
      imageUrl: 'https://cdn.test/$id.jpg',
      recurrenceDays: [start.weekday % 7],
    );

    test('a Studio weekly event on the same weekday replaces the service; '
        'other services remain, soonest first', () {
      final oneOff = Event(
        id: 'picnic',
        title: 'Picnic',
        startTime: DateTime(2026, 10, 27, 13),
        branch: 'Bristol',
      );
      final celebration = studioWeekly(
        id: 'celebration',
        title: 'Sunday Celebration',
        start: _sun(12),
      );
      final merged = withBranchServiceEvents(
        [oneOff, celebration],
        _bristol,
        now: _sun(11),
      );
      expect(merged.map((e) => e.id), [
        'celebration',
        'picnic',
        'service:bristol:wed',
      ]);
    });

    test('with several services that day, title then closest start '
        'decides which one the Studio event replaces', () {
      const twoSundays = Branch(
        id: 'bristol',
        name: 'Bristol',
        subtitle: '',
        gradientStart: Colors.black,
        gradientEnd: Colors.black,
        services: [
          CampusService(
            id: 'early',
            name: 'First Service',
            day: 'Sunday',
            startTime: '09:00',
          ),
          CampusService(
            id: 'late',
            name: 'Second Service',
            day: 'Sunday',
            startTime: '12:00',
          ),
        ],
      );
      final byTime = withBranchServiceEvents(
        [studioWeekly(id: 's', title: 'Worship', start: _sun(11, 30))],
        twoSundays,
        now: _sun(8),
      );
      expect(byTime.map((e) => e.id), ['service:bristol:early', 's']);

      final byTitle = withBranchServiceEvents(
        [studioWeekly(id: 's', title: 'first service', start: _sun(11, 30))],
        twoSundays,
        now: _sun(8),
      );
      expect(byTitle.map((e) => e.id), ['s', 'service:bristol:late']);
    });

    test('an all-branches weekly event does not replace a service', () {
      final merged = withBranchServiceEvents(
        [studioWeekly(id: 'g', title: 'Global', start: _sun(12), branch: null)],
        _bristol,
        now: _sun(11),
      );
      expect(merged.map((e) => e.id), contains('service:bristol:sun'));
    });
  });

  group('Events tab', () {
    late SupabaseStub stub;

    List<Override> overrides({
      List<Event> studio = const [],
      bool allBranches = false,
      List<Rsvp> rsvps = const [],
    }) {
      stub = SupabaseStub({'events': []});
      return [
        contentApiProvider.overrideWithValue(stub.api()),
        currentBranchProvider.overrideWith((ref) => Stream.value('Bristol')),
        currentUserProvider.overrideWith((ref) => Stream.value(null)),
        branchesProvider.overrideWith(
          (ref) => Stream.value(const [_london, _bristol]),
        ),
        upcomingEventsProvider.overrideWith(
          (ref, branch) => Stream.value([
            for (final e in studio)
              if (e.isVisibleTo(branch)) e,
          ]),
        ),
        myRsvpsProvider.overrideWith((ref) => Stream.value(rsvps)),
        eventsShowAllBranchesProvider.overrideWith((ref) => allBranches),
      ];
    }

    Future<List<Event>> upcoming(ProviderContainer c) async {
      final sub = c.listen(eventsUpcomingProvider, (_, _) {});
      addTearDown(sub.close);
      for (var i = 0; i < 20 && !sub.read().hasValue; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      return sub.read().requireValue;
    }

    testWidgets('a branch with services and no Studio events lists the '
        'services; tapping one opens its detail', (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();
      tester.view.physicalSize = const Size(1200, 4000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final router = GoRouter(
        initialLocation: '/calendar',
        routes: [
          GoRoute(path: '/calendar', builder: (_, _) => const CalendarScreen()),
          GoRoute(
            path: '/events/:id',
            builder: (_, state) => EventDetailScreen(
              eventId: state.pathParameters['id']!,
              initial: state.extra is Event ? state.extra as Event : null,
            ),
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            ...overrides(),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No upcoming events'), findsNothing);
      expect(find.text('Sunday Service'), findsOneWidget);
      expect(find.text('Midweek Service'), findsOneWidget);
      expect(find.text('London Sunday Service'), findsNothing);

      await tester.tap(find.text('Midweek Service'));
      await tester.pumpAndSettle();

      expect(find.byType(EventDetailScreen), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('event-detail-venue')),
          matching: find.text('Main Hall'),
        ),
        findsOneWidget,
      );
      expect(find.text('6 Ashley Road, Bristol'), findsOneWidget);
      expect(find.text('Get directions'), findsOneWidget);
      expect(find.text('Add to calendar'), findsOneWidget);
      expect(find.text('RSVP'), findsOneWidget);
      expect(find.text('Every Wednesday \u00b7 7:00 PM'), findsOneWidget);
      expect(stub.requests, isEmpty);
    });

    test(
      'the detail lookup resolves a service id without the Studio',
      () async {
        final c = ProviderContainer(overrides: overrides());
        addTearDown(c.dispose);
        final sub = c.listen(
          eventByIdProvider('service:bristol:sun').future,
          (_, _) {},
        );
        addTearDown(sub.close);
        final event = await sub.read();
        expect(event?.title, 'Sunday Service');
        expect(event?.location, 'Main Hall');
        expect(event?.branch, 'Bristol');
        expect(stub.requests, isEmpty);
      },
    );

    test('a Studio weekly event for the branch replaces its service', () async {
      final next = branchServiceEvents(
        _bristol,
        now: DateTime.now(),
      ).firstWhere((e) => e.id == 'service:bristol:sun');
      final c = ProviderContainer(
        overrides: overrides(
          studio: [
            Event(
              id: 'celebration',
              title: 'Sunday Celebration',
              startTime: next.startTime,
              branch: 'Bristol',
              recurrenceDays: const [0],
            ),
          ],
        ),
      );
      addTearDown(c.dispose);
      final ids = (await upcoming(c)).map((e) => e.id);
      expect(ids, containsAll(['celebration', 'service:bristol:wed']));
      expect(ids, isNot(contains('service:bristol:sun')));
    });

    test('All branches adds only the home branch\'s services', () async {
      final londonEvent = Event(
        id: 'london-picnic',
        title: 'Picnic',
        startTime: DateTime.now().add(const Duration(days: 2)),
        branch: 'London',
      );
      final c = ProviderContainer(
        overrides: overrides(studio: [londonEvent], allBranches: true),
      );
      addTearDown(c.dispose);
      final ids = (await upcoming(c)).map((e) => e.id).toSet();
      expect(ids, {
        'london-picnic',
        'service:bristol:sun',
        'service:bristol:wed',
      });
    });

    test('a service RSVP appears in My RSVPs', () async {
      final c = ProviderContainer(
        overrides: overrides(
          rsvps: [
            Rsvp(
              id: 'u1_service:bristol:wed',
              userId: 'u1',
              eventId: 'service:bristol:wed',
              eventStartTime: DateTime.now(),
            ),
          ],
        ),
      );
      addTearDown(c.dispose);
      final sub = c.listen(myRsvpEventsProvider.future, (_, _) {});
      addTearDown(sub.close);
      final grouped = await sub.read();
      expect(grouped.upcoming.map((e) => e.id), ['service:bristol:wed']);
      expect(grouped.past, isEmpty);
    });
  });
}
