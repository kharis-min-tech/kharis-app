import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kharis_app/features/calendar/data/event_repository.dart';
import 'package:kharis_app/features/calendar/data/rsvp_repository.dart';
import 'package:kharis_app/features/calendar/presentation/screens/calendar_screen.dart';
import 'package:kharis_app/features/connect/data/connect_repository.dart';
import 'package:kharis_app/features/connect/presentation/screens/new_here_screen.dart';
import 'package:kharis_app/features/connect/presentation/screens/testimony_screen.dart';
import 'package:kharis_app/features/onboarding/data/branch_repository.dart';
import 'package:kharis_app/features/playlists/presentation/widgets/playlist_card.dart';
import 'package:kharis_app/features/playlists/providers/playlist_providers.dart';
import 'package:kharis_app/shared/models/campus_config.dart';
import 'package:kharis_app/shared/models/sermon.dart';
import 'package:kharis_app/shared/providers/admin_provider.dart';
import 'package:kharis_app/shared/providers/auth_provider.dart';
import 'package:kharis_app/shared/providers/branch_provider.dart';
import 'package:kharis_app/shared/providers/campus_config_provider.dart';
import 'package:kharis_app/shared/providers/notification_feed_provider.dart';
import 'package:kharis_app/shared/providers/onboarding_provider.dart';
import 'package:kharis_app/shared/providers/sermon_provider.dart';
import 'package:kharis_app/shared/widgets/artwork_image.dart';

import 'support/supabase_stub.dart';

const _london = Branch(
  id: 'london',
  name: 'London',
  subtitle: '',
  gradientStart: Color(0xFF5D3FD3),
  gradientEnd: Color(0xFF451EBB),
);

const _barking = Branch(
  id: 'kp2-barking',
  name: 'KP2 Barking',
  subtitle: '',
  group: Branch.phaseTwoGroup,
  gradientStart: Color(0xFF5D3FD3),
  gradientEnd: Color(0xFF451EBB),
);

Sermon _sermon(String id, {String? art}) => Sermon(
  id: id,
  title: 'Message $id',
  speaker: 'Speaker',
  audioUrl: 'https://x.test/$id.mp3',
  artworkUrl: art,
);

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  // ── Events ──────────────────────────────────────────────────────────────────

  group('Events: Studio events as-is', () {
    Future<void> pump(
      WidgetTester tester, {
      List<Event> events = const [],
      Branch? campus,
    }) async {
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
            eventsUpcomingProvider.overrideWithValue(AsyncValue.data(events)),
            myRsvpsProvider.overrideWith((ref) => Stream.value(const <Rsvp>[])),
            currentCampusProvider.overrideWithValue(campus),
          ],
          child: const MaterialApp(home: CalendarScreen()),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('a weekly event is one card with its recurrence label', (
      tester,
    ) async {
      final next = DateTime.now().add(const Duration(days: 3));
      await pump(
        tester,
        events: [
          Event(
            id: 'sun',
            title: 'Sunday Service',
            startTime: DateTime(next.year, next.month, next.day, 9),
            recurrenceDays: const [0, 3],
          ),
          Event(
            id: 'e1',
            title: 'Prayer Night',
            location: 'Main Hall',
            startTime: next.add(const Duration(days: 1)),
          ),
        ],
      );
      expect(find.text('Sunday Service'), findsOneWidget);
      expect(
        find.text('Every Sunday and Wednesday \u00b7 9:00 AM'),
        findsOneWidget,
      );
      expect(find.text('Prayer Night'), findsOneWidget);
      expect(find.text('WEEKLY SERVICES'), findsNothing);
      expect(find.text('No upcoming events'), findsNothing);
    });

    testWidgets('no Studio events shows the empty state', (tester) async {
      await pump(tester);
      expect(find.text('No upcoming events'), findsOneWidget);
      expect(find.text('WEEKLY SERVICES'), findsNothing);
      expect(find.byKey(const Key('campus-card')), findsNothing);
    });

    testWidgets('no events still shows when the branch meets', (tester) async {
      await pump(
        tester,
        campus: const Branch(
          id: 'london',
          name: 'London',
          subtitle: '',
          gradientStart: Colors.black,
          gradientEnd: Colors.black,
          services: [
            CampusService(
              id: 'sun',
              name: 'Sunday Service',
              day: 'Sunday',
              startTime: '10:00',
            ),
          ],
        ),
      );
      expect(find.text('No upcoming events'), findsOneWidget);
      expect(find.byKey(const Key('campus-card')), findsOneWidget);
      expect(find.byKey(const Key('campus-service-sun')), findsOneWidget);
    });
  });

  // ── Playlist artwork ───────────────────────────────────────────────────────

  group('Playlist mosaic', () {
    test('picks the first four distinct usable artwork URLs', () {
      final urls = playlistArtworkUrls([
        _sermon('1', art: 'https://cdn.test/a.jpg'),
        _sermon('2'),
        _sermon('3', art: 'https://cdn.test/a.jpg'),
        _sermon('4', art: 'assets/design/acts-series.png'),
        _sermon('5', art: 'http://localhost:3002/b.jpg'),
        _sermon('6', art: 'https://cdn.test/b.jpg'),
        _sermon('7', art: 'https://cdn.test/c.jpg'),
        _sermon('8', art: 'https://cdn.test/d.jpg'),
        _sermon('9', art: 'https://cdn.test/e.jpg'),
      ]);
      expect(urls, [
        'https://cdn.test/a.jpg',
        'https://cdn.test/b.jpg',
        'https://cdn.test/c.jpg',
        'https://cdn.test/d.jpg',
      ]);
      expect(playlistArtworkUrls([_sermon('1')]), isEmpty);
    });

    Future<List<String?>> tiles(WidgetTester tester, List<String> urls) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox.square(
              dimension: 120,
              child: PlaylistMosaic(urls: urls, fallbackIndex: 3),
            ),
          ),
        ),
      );
      return [
        for (final w in tester.widgetList<ArtworkImage>(
          find.byType(ArtworkImage),
        ))
          w.url,
      ];
    }

    testWidgets('lays out 1, 2, 3 and 4 images; none falls back', (
      tester,
    ) async {
      const a = 'https://cdn.test/a.jpg';
      const b = 'https://cdn.test/b.jpg';
      const c = 'https://cdn.test/c.jpg';
      const d = 'https://cdn.test/d.jpg';
      expect(await tiles(tester, [a]), [a]);
      expect(
        tester.getSize(find.byType(ArtworkImage)),
        const Size(120, 120),
        reason: 'one image fills the square',
      );
      expect(await tiles(tester, [a, b]), [a, b]);
      expect(
        tester.getSize(find.byType(ArtworkImage).first),
        const Size(60, 120),
      );
      expect(await tiles(tester, [a, b, c]), [a, b, c]);
      expect(
        tester.getSize(find.byType(ArtworkImage).first),
        const Size(60, 120),
      );
      expect(
        tester.getSize(find.byType(ArtworkImage).last),
        const Size(60, 60),
      );
      expect(await tiles(tester, [a, b, c, d]), [a, b, c, d]);
      for (final e in find.byType(ArtworkImage).evaluate()) {
        expect(e.size, const Size(60, 60));
      }
      expect(await tiles(tester, const []), [null]);
      expect(find.byIcon(Icons.queue_music_rounded), findsOneWidget);
    });
  });

  // ── Connect forms ──────────────────────────────────────────────────────────

  group('Supabase payloads', () {
    test('a visitor maps onto the visitors columns', () {
      final row = VisitorSubmission(
        name: 'Ada Lovelace',
        email: 'ada@example.com',
        phone: '',
        branchName: 'London',
        firstVisitDate: DateTime(2026, 10, 11),
      ).toRow();
      expect(row, {
        'name': 'Ada Lovelace',
        'email': 'ada@example.com',
        'phone': null,
        'branch_name': 'London',
        'message': 'First visit: 11 Oct 2026',
      });
    });

    test('a testimony maps onto the testimonies columns', () {
      TestimonySubmission t(Branch branch) => TestimonySubmission(
        name: 'Ada',
        email: '',
        phone: '0700',
        branch: branch,
        category: 'Health/Healing',
        summary: 'Healed',
        testimony: 'God healed me.',
        anonymous: true,
      );
      expect(t(_london).toRow(), {
        'name': 'Ada',
        'email': null,
        'phone': '0700',
        'branch_name': 'London',
        'category': 'Health/Healing',
        'short_description': 'Healed',
        'description': 'God healed me.',
        'is_anonymous': true,
        'is_published': false,
        'workspace': 'general',
      });
      expect(t(_barking).toRow()['workspace'], 'kp2');
    });
  });

  group('Connect forms', () {
    Future<SupabaseStub> pumpForm(
      WidgetTester tester,
      Widget screen, {
      bool offline = false,
      bool rlsDenied = false,
    }) async {
      tester.view.physicalSize = const Size(1200, 3200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final stub = SupabaseStub({'testimonies': [], 'visitors': []})
        ..offline = offline
        ..rlsDenied = rlsDenied;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            branchesProvider.overrideWith(
              (ref) => Stream.value(const [_london, _barking]),
            ),
            connectRepositoryProvider.overrideWithValue(
              ConnectRepository(dio: Dio()..httpClientAdapter = stub),
            ),
          ],
          child: MaterialApp(home: screen),
        ),
      );
      await tester.pumpAndSettle();
      return stub;
    }

    Future<void> choose(WidgetTester tester, String hint, String item) async {
      await tester.tap(find.text(hint), warnIfMissed: false);
      await tester.pumpAndSettle();
      await tester.tap(find.text(item).last);
      await tester.pumpAndSettle();
    }

    /// The text field under [label]: inside the label's own column.
    Finder field(String label) => find.descendant(
      of: find
          .ancestor(of: find.text(label), matching: find.byType(Column))
          .first,
      matching: find.byType(TextFormField),
    );

    const consent = 'I am happy for Kharis to share my testimony';

    testWidgets('testimony: the website categories, required fields, then '
        'the website payload', (tester) async {
      final stub = await pumpForm(tester, const TestimonyScreen());
      await tester.tap(find.text('Share testimony'));
      await tester.pumpAndSettle();
      expect(find.text('Name is required'), findsOneWidget);
      expect(find.text('Branch is required'), findsOneWidget);
      expect(find.text('Add a short title'), findsOneWidget);
      expect(find.text('Please share your testimony'), findsOneWidget);
      expect(
        find.text('Please confirm we may share your testimony'),
        findsOneWidget,
      );
      expect(stub.requests, isEmpty);

      // Every kharis.org testimony category is offered.
      await tester.tap(find.text('Choose a category'), warnIfMissed: false);
      await tester.pumpAndSettle();
      for (final c in kTestimonyCategories) {
        expect(find.text(c), findsWidgets, reason: c);
      }
      await tester.tap(find.text('Unusual Favour').last);
      await tester.pumpAndSettle();

      await tester.enterText(field('Full name *').first, 'Ada');
      await tester.enterText(field('Email address').first, 'ada@example.com');
      await tester.enterText(field('Short title / summary *').first, 'Healed');
      await tester.enterText(field('Your testimony *').first, 'God healed me.');
      await choose(tester, 'Choose your branch', 'KP2 Barking');
      await choose(tester, 'Unusual Favour', 'Health/Healing');
      await tester.tap(find.text('Share anonymously'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(consent));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Share testimony'));
      await tester.tap(find.text('Share testimony'));
      await tester.pumpAndSettle();

      final request = stub.requests.single;
      expect(request.method, 'POST');
      expect(request.uri.path, '/rest/v1/testimonies');
      expect(request.headers['Prefer'], 'return=minimal');
      final body = Map<String, Object?>.from(request.data as Map);
      expect(body.remove('id'), isA<String>());
      expect(body, {
        'name': 'Ada',
        'email': 'ada@example.com',
        'phone': null,
        'branch_name': 'KP2 Barking',
        'category': 'Health/Healing',
        'short_description': 'Healed',
        'description': 'God healed me.',
        'is_anonymous': true,
        'is_published': false,
        'workspace': 'kp2',
      });
      expect(find.text('Thank you for sharing'), findsOneWidget);
    });

    Future<void> fillTestimony(WidgetTester tester) async {
      await tester.enterText(field('Full name *').first, 'Ada');
      await tester.enterText(field('Short title / summary *').first, 'Healed');
      await tester.enterText(field('Your testimony *').first, 'God healed me.');
      await choose(tester, 'Choose your branch', 'London');
      await tester.tap(find.text(consent));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Share testimony'));
      await tester.tap(find.text('Share testimony'));
      await tester.pumpAndSettle();
    }

    testWidgets('a failed testimony never claims success', (tester) async {
      await pumpForm(tester, const TestimonyScreen(), offline: true);
      await fillTestimony(tester);
      expect(find.text('Thank you for sharing'), findsNothing);
      expect(find.textContaining('was not sent'), findsOneWidget);
    });

    testWidgets('a Studio refusal (RLS 401) shows the failure and keeps the '
        'text', (tester) async {
      final stub = await pumpForm(
        tester,
        const TestimonyScreen(),
        rlsDenied: true,
      );
      await fillTestimony(tester);
      expect(stub.requests.single.uri.path, '/rest/v1/testimonies');
      expect(find.text('Thank you for sharing'), findsNothing);
      expect(find.textContaining('was not sent'), findsOneWidget);
      expect(find.text('God healed me.'), findsOneWidget);
    });

    testWidgets('new here: every field is labelled the same way and the '
        'visit is sent to visitors', (tester) async {
      final stub = await pumpForm(tester, const NewHereScreen());
      // Every label sits above its input: no floating label anywhere.
      for (final tf in tester.widgetList<TextField>(find.byType(TextField))) {
        expect(tf.decoration?.labelText, isNull);
      }
      final labels = [
        'Full name *',
        'Phone number',
        'Email address *',
        'Branch',
        'First visit date',
      ];
      final xs = {for (final l in labels) tester.getTopLeft(find.text(l)).dx};
      expect(xs, hasLength(1), reason: 'labels share one left edge');

      await tester.enterText(field('Full name *').first, 'Ada');
      await tester.enterText(field('Email address *').first, 'ada@example.com');
      await choose(tester, 'Choose your branch', 'London');
      await tester.ensureVisible(find.text('Connect with us'));
      await tester.tap(find.text('Connect with us'));
      await tester.pumpAndSettle();

      final request = stub.requests.single;
      expect(request.uri.path, '/rest/v1/visitors');
      final body = Map<String, Object?>.from(request.data as Map);
      expect(body.keys.toSet(), {
        'id',
        'name',
        'email',
        'phone',
        'branch_name',
        'message',
      });
      expect(body['name'], 'Ada');
      expect(body['branch_name'], 'London');
      expect(body['message'], startsWith('First visit: '));
      expect(find.text('Welcome to Kharis'), findsOneWidget);
    });
  });
}
