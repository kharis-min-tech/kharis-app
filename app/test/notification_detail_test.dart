import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kharis_app/features/calendar/data/event_repository.dart';
import 'package:kharis_app/features/calendar/data/rsvp_repository.dart';
import 'package:kharis_app/features/calendar/presentation/screens/event_detail_screen.dart';
import 'package:kharis_app/features/home/data/news_repository.dart';
import 'package:kharis_app/features/home/presentation/screens/notifications_screen.dart';
import 'package:kharis_app/shared/providers/branch_provider.dart';
import 'package:kharis_app/shared/providers/onboarding_provider.dart';
import 'package:kharis_app/shared/providers/sermon_provider.dart';

/// Tester feedback regression: "I clicked on the event calendar notification
/// but was unable to open it to view further details."
///
/// A tap on an event row must open the event's detail page carrying the full
/// story — date, time, venue — plus an add-to-calendar action.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  final event = Event(
    id: 'e1',
    title: 'Prayer Night',
    description: 'An evening of corporate prayer. All welcome.',
    location: 'Main Hall, London',
    branch: 'London',
    startTime: DateTime(2026, 9, 4, 19, 0),
    endTime: DateTime(2026, 9, 4, 21, 0),
  );

  testWidgets('event notification tap opens the event detail page', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();

    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const NotificationsScreen(),
        ),
        GoRoute(
          path: '/events/:id',
          builder: (context, state) => EventDetailScreen(
            eventId: state.pathParameters['id']!,
            initial: state.extra as Event?,
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          currentBranchProvider.overrideWith((ref) => Stream.value('London')),
          newsProvider.overrideWith((ref, branch) async => const <NewsItem>[]),
          upcomingEventsProvider.overrideWith(
            (ref, branch) => Stream.value([event]),
          ),
          myRsvpsProvider.overrideWith((ref) => Stream.value(const <Rsvp>[])),
          eventByIdProvider.overrideWith((ref, id) async => event),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    // The feed row is there and tappable.
    expect(find.text('Prayer Night'), findsOneWidget);
    await tester.tap(find.text('Prayer Night'));
    await tester.pumpAndSettle();

    // Detail: full date, time range, venue, untruncated body, calendar action.
    expect(find.byType(EventDetailScreen), findsOneWidget);
    expect(find.text('Friday 4 September 2026'), findsOneWidget);
    expect(find.text('7:00 PM \u2013 9:00 PM'), findsOneWidget);
    expect(find.text('Main Hall, London'), findsOneWidget);
    expect(
      find.text('An evening of corporate prayer. All welcome.'),
      findsOneWidget,
    );
    expect(find.text('Add to calendar'), findsOneWidget);
  });
}
