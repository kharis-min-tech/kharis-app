// The More tab (SettingsScreen): what a member and a guest see and can do,
// where each tile, card and row leads, and that nothing overflows at the
// 390 design width in light and dark at 100% and 130% text size.
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kharis_app/core/services/notification_service.dart';
import 'package:kharis_app/features/connect/presentation/screens/new_here_screen.dart';
import 'package:kharis_app/features/connect/presentation/screens/testimony_screen.dart';
import 'package:kharis_app/features/feedback/presentation/feedback_sheet.dart';
import 'package:kharis_app/features/onboarding/data/auth_repository.dart';
import 'package:kharis_app/features/onboarding/data/branch_repository.dart';
import 'package:kharis_app/features/settings/presentation/screens/settings_screen.dart';
import 'package:kharis_app/shared/models/campus_config.dart';
import 'package:kharis_app/shared/models/user.dart';
import 'package:kharis_app/shared/providers/admin_provider.dart';
import 'package:kharis_app/shared/providers/audio_provider.dart';
import 'package:kharis_app/shared/providers/auth_provider.dart';
import 'package:kharis_app/shared/providers/branch_provider.dart';
import 'package:kharis_app/shared/providers/location_provider.dart';
import 'package:kharis_app/shared/providers/notes_provider.dart';
import 'package:kharis_app/shared/providers/notification_provider.dart';
import 'package:kharis_app/shared/providers/onboarding_provider.dart';
import 'package:kharis_app/shared/providers/text_size_provider.dart';
import 'package:kharis_app/shared/providers/theme_provider.dart';
import 'package:kharis_app/shared/widgets/branch_picker_sheet.dart';
import 'package:kharis_app/ui/components/components.dart';

import 'support/design_harness.dart';
import 'support/fake_location_service.dart';
import 'support/more_screen_overrides.dart';

// ── Fakes ─────────────────────────────────────────────────────────────────────

class _FakeAuth implements AuthRepository {
  int logouts = 0;

  @override
  Future<void> logout() async => logouts++;

  @override
  bool get usesPasswordSignIn => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _QuietNotifications extends NotificationService {
  @override
  Future<void> switchBranchTopic({String? from, String? to}) async {}
}

final _member = User(
  id: 'member-1',
  email: 'esther@kharis.org',
  displayName: 'Esther',
  role: 'member',
  branch: 'London',
  createdAt: DateTime(2021, 3, 14),
);

final _guest = User(
  id: 'anon-1',
  email: '',
  displayName: 'Guest',
  role: 'guest',
  createdAt: DateTime(2024),
);

const _london = Branch(
  id: 'london',
  name: 'London',
  subtitle: 'England · Main campus',
  venues: [
    CampusVenue(
      id: 'lighthouse',
      name: 'The Lighthouse Theatre',
      addressLine1: '262–274 Camberwell Rd',
      city: 'London',
      postcode: 'SE5 0AY',
    ),
  ],
  services: [
    CampusService(
      id: 'sunday',
      name: 'Sunday Service',
      day: 'Sundays',
      startTime: '10:00',
      venueId: 'lighthouse',
    ),
    CampusService(
      id: 'midweek',
      name: 'Midweek Service',
      day: 'Wednesdays',
      startTime: '19:00',
      venueId: 'lighthouse',
    ),
  ],
);

const _manchester = Branch(
  id: 'manchester',
  name: 'Manchester',
  subtitle: 'England',
);

/// Monday 16 November 2026, mid-morning: the midweek service is next.
final _monday = DateTime(2026, 11, 16, 9, 30);

/// URLs handed to url_launcher, with their launch arguments.
final _launched = <Map<String, Object?>>[];

const _routes = [
  '/profile/edit',
  '/login',
  '/register',
  '/notes',
  '/downloads',
  '/playlists',
  '/favorites',
  '/give',
  '/calendar',
  '/branch',
  '/settings/notifications',
];

/// Pumps More at the 390 design width inside a router whose destinations are
/// labelled stubs, so a tap proves which route it opened.
Future<SharedPreferences> _pumpMore(
  WidgetTester tester, {
  User? user,
  AuthRepository? auth,
  String? branch = 'London',
  List<Branch> branches = const [_london, _manchester],
  NotificationPermission permission = NotificationPermission.granted,
  Map<String, bool> notificationPrefs = const {},
  List<Override> data = const [],
  Map<String, Object> stored = const {},
  bool dark = false,
  double textScale = 1,
}) async {
  tester.view.physicalSize = designSurface;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues({
    'onboarding_branch': ?branch,
    ...stored,
  });
  final prefs = await SharedPreferences.getInstance();
  final router = GoRouter(
    initialLocation: '/more',
    routes: [
      GoRoute(path: '/more', builder: (_, _) => const SettingsScreen()),
      for (final path in _routes)
        GoRoute(
          path: path,
          builder: (_, _) => Scaffold(body: Text('route:$path')),
        ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        firestoreProvider.overrideWithValue(FakeFirebaseFirestore()),
        currentUserProvider.overrideWith((ref) => Stream.value(user)),
        // The forms keep the tab nav, whose mini player reads this.
        currentSermonProvider.overrideWith((ref) => null),
        currentBranchProvider.overrideWith((ref) => Stream.value(branch)),
        branchesProvider.overrideWith((ref) => Stream.value(branches)),
        notificationServiceProvider.overrideWithValue(_QuietNotifications()),
        notificationPrefsProvider.overrideWith(
          (ref) => Stream.value(notificationPrefs),
        ),
        notificationPermissionProvider.overrideWith((ref) async => permission),
        locationServiceProvider.overrideWithValue(FakeLocationService()),
        if (auth != null) authRepositoryProvider.overrideWithValue(auth),
        ...data.isEmpty ? moreScreenOverrides(now: _monday) : data,
      ],
      child: Consumer(
        builder: (context, ref, _) => MaterialApp.router(
          debugShowCheckedModeBanner: false,
          theme: KharisTheme.light(),
          darkTheme: KharisTheme.dark(),
          themeMode: dark ? ThemeMode.dark : ref.watch(themeModeProvider),
          builder: (context, app) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: app!,
          ),
          routerConfig: router,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return prefs;
}

Future<void> _tap(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Finder _key(String key) => find.byKey(Key(key));

/// The meta line of the tile titled [title]; null when it shows none.
String? _tileMeta(WidgetTester tester, String title) =>
    tester.widget<KMoreTile>(find.widgetWithText(KMoreTile, title)).meta;

/// What the row at [key] shows at its end; null when it shows nothing.
String? _rowValue(WidgetTester tester, String key) {
  final texts = tester.widgetList<Text>(
    find.descendant(of: _key(key), matching: find.byType(Text)),
  );
  return texts.length < 2 ? null : texts.last.data;
}

void main() {
  setUpAll(loadDesignAssets);

  setUp(() {
    _launched.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/url_launcher'),
          (call) async {
            if (call.method == 'launch') {
              _launched.add(Map<String, Object?>.from(call.arguments as Map));
            }
            return true;
          },
        );
    PackageInfo.setMockInitialValues(
      appName: 'Kharis Church',
      packageName: 'org.kharis.church',
      version: '1.4.2',
      buildNumber: '37',
      buildSignature: '',
    );
  });

  group('header and profile', () {
    testWidgets('the screen is titled More', (tester) async {
      await _pumpMore(tester, user: _member);
      expect(
        find.descendant(
          of: find.byType(KScreenHeader),
          matching: find.text('More'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('a member sees their name, branch and the year they joined', (
      tester,
    ) async {
      await _pumpMore(tester, user: _member);

      final card = tester.widget<KMoreProfileCard>(
        find.byType(KMoreProfileCard),
      );
      expect(card.name, 'Esther');
      expect(card.subtitle, 'London · member since 2021');
      expect(find.text('E'), findsOneWidget, reason: 'avatar initial');
      expect(_key('more-sign-in-card'), findsNothing);
    });

    testWidgets('with no branch chosen the line is the year alone', (
      tester,
    ) async {
      await _pumpMore(tester, user: _member, branch: null);
      expect(find.text('member since 2021'), findsOneWidget);
    });

    testWidgets('streaks above zero show as badges', (tester) async {
      await _pumpMore(
        tester,
        user: _member,
        data: moreScreenOverrides(readingStreak: 27, messagesStreak: 12),
      );

      expect(find.text('27-day reading'), findsOneWidget);
      expect(find.text('12-day messages'), findsOneWidget);
      final reading = tester.widget<KMoreStreakBadge>(
        find.widgetWithText(KMoreStreakBadge, '27-day reading'),
      );
      expect(reading.tone, KMoreStreakTone.highlight);
      expect(reading.icon, KIcons.flame);
      final messages = tester.widget<KMoreStreakBadge>(
        find.widgetWithText(KMoreStreakBadge, '12-day messages'),
      );
      expect(messages.tone, KMoreStreakTone.primary);
    });

    testWidgets('a streak of zero shows no badge', (tester) async {
      await _pumpMore(
        tester,
        user: _member,
        data: moreScreenOverrides(readingStreak: 3),
      );

      expect(find.text('3-day reading'), findsOneWidget);
      expect(find.textContaining('messages'), findsNothing);
      expect(find.byType(KMoreStreakBadge), findsOneWidget);
    });

    testWidgets('the profile card opens Edit profile', (tester) async {
      await _pumpMore(tester, user: _member);
      await _tap(tester, _key('more-profile-card'));
      expect(find.text('route:/profile/edit'), findsOneWidget);
    });

    for (final (who, user) in [('a guest', _guest), ('signed out', null)]) {
      testWidgets('$who sees the sign-in card, not a profile or Sign out', (
        tester,
      ) async {
        await _pumpMore(tester, user: user);

        expect(_key('more-sign-in-card'), findsOneWidget);
        expect(find.byType(KMoreProfileCard), findsNothing);
        expect(find.text('Sign in'), findsOneWidget);
        expect(find.text('Create an account'), findsOneWidget);
        expect(find.text('Sign out'), findsNothing);
        expect(find.text('Delete account'), findsNothing);
      });
    }

    testWidgets('Sign in opens login', (tester) async {
      await _pumpMore(tester, user: _guest);
      await _tap(tester, _key('more-sign-in'));
      expect(find.text('route:/login'), findsOneWidget);
    });

    testWidgets('Create an account opens registration', (tester) async {
      await _pumpMore(tester, user: _guest);
      await _tap(tester, _key('more-create-account'));
      expect(find.text('route:/register'), findsOneWidget);
    });
  });

  group('tiles', () {
    for (final (title, route) in [
      ('My notes', '/notes'),
      ('Downloads', '/downloads'),
      ('Collections', '/playlists'),
      ('Favourites', '/favorites'),
      ('Give', '/give'),
      ('Events', '/calendar'),
    ]) {
      testWidgets('$title opens $route', (tester) async {
        await _pumpMore(tester, user: _member);
        await _tap(tester, find.widgetWithText(KMoreTile, title));
        expect(find.text('route:$route'), findsOneWidget);
      });
    }

    testWidgets('there are six, two to a row, in canvas order', (tester) async {
      await _pumpMore(tester, user: _member);

      expect(
        [
          for (final t in tester.widgetList<KMoreTile>(find.byType(KMoreTile)))
            t.title,
        ],
        [
          'My notes',
          'Downloads',
          'Collections',
          'Favourites',
          'Give',
          'Events',
        ],
      );
      final notes = tester.getRect(find.widgetWithText(KMoreTile, 'My notes'));
      final downloads = tester.getRect(
        find.widgetWithText(KMoreTile, 'Downloads'),
      );
      expect(downloads.top, notes.top);
      expect(downloads.left, greaterThan(notes.right));
    });

    testWidgets('each says what is in it', (tester) async {
      await _pumpMore(
        tester,
        user: _member,
        data: moreScreenOverrides(
          notes: 62,
          downloads: 12,
          collections: 3,
          favourites: 5,
          now: _monday,
        ),
      );

      expect(_tileMeta(tester, 'My notes'), '62 notes');
      expect(_tileMeta(tester, 'Downloads'), '12 saved');
      expect(_tileMeta(tester, 'Collections'), '3 collections');
      expect(_tileMeta(tester, 'Favourites'), '5 messages');
      expect(_tileMeta(tester, 'Give'), 'Tithes and offerings');
      expect(_tileMeta(tester, 'Events'), 'Midweek · Wed 19:00');
    });

    testWidgets('one of a thing reads in the singular', (tester) async {
      await _pumpMore(
        tester,
        user: _member,
        data: moreScreenOverrides(
          notes: 1,
          downloads: 1,
          collections: 1,
          favourites: 1,
        ),
      );

      expect(_tileMeta(tester, 'My notes'), '1 note');
      expect(_tileMeta(tester, 'Downloads'), '1 saved');
      expect(_tileMeta(tester, 'Collections'), '1 collection');
      expect(_tileMeta(tester, 'Favourites'), '1 message');
    });

    testWidgets('with nothing saved each says so plainly', (tester) async {
      await _pumpMore(tester, user: _member);

      expect(_tileMeta(tester, 'My notes'), 'No notes yet');
      expect(_tileMeta(tester, 'Downloads'), 'None saved');
      expect(_tileMeta(tester, 'Collections'), 'None yet');
      expect(_tileMeta(tester, 'Favourites'), 'None yet');
    });

    testWidgets('a count still loading, or that failed, shows no number', (
      tester,
    ) async {
      await _pumpMore(
        tester,
        user: _member,
        data: [
          ...moreScreenOverrides(),
          notebookProvider.overrideWithValue(const AsyncLoading()),
        ],
      );
      expect(_tileMeta(tester, 'My notes'), isNull);
      expect(find.text('My notes'), findsOneWidget);

      await _pumpMore(
        tester,
        user: _member,
        data: [
          ...moreScreenOverrides(),
          notebookProvider.overrideWithValue(
            AsyncError(Exception('offline'), StackTrace.empty),
          ),
        ],
      );
      expect(_tileMeta(tester, 'My notes'), isNull);
      await _tap(tester, find.widgetWithText(KMoreTile, 'My notes'));
      expect(find.text('route:/notes'), findsOneWidget);
    });

    testWidgets('Events falls back to a plain line when the branch lists no '
        'weekly service', (tester) async {
      await _pumpMore(tester, user: _member, branch: 'Manchester');
      expect(_tileMeta(tester, 'Events'), 'Services and events');
    });

    testWidgets('what is left out stays out', (tester) async {
      await _pumpMore(tester, user: _member);
      for (final label in [
        'Friends',
        'Bible plans',
        'Daily reading',
        'Bible',
        'My Giving History',
      ]) {
        expect(find.text(label), findsNothing, reason: label);
      }
    });
  });

  group('your branch', () {
    testWidgets('shows the branch, where it meets and its first service', (
      tester,
    ) async {
      await _pumpMore(tester, user: _member);

      final card = _key('campus-card');
      Finder inCard(Finder f) => find.descendant(of: card, matching: f);
      expect(inCard(find.text('YOUR BRANCH')), findsOneWidget);
      expect(inCard(find.text('London')), findsOneWidget);
      expect(
        inCard(find.text('262–274 Camberwell Rd, London, SE5 0AY')),
        findsOneWidget,
      );
      expect(inCard(find.textContaining('Sunday Service')), findsOneWidget);
      expect(inCard(find.text('Directions')), findsOneWidget);
      expect(inCard(find.text('Change branch')), findsOneWidget);
    });

    testWidgets('the card opens the branch page', (tester) async {
      await _pumpMore(tester, user: _member);
      await _tap(
        tester,
        find.descendant(of: _key('campus-card'), matching: find.text('London')),
      );
      expect(find.text('route:/branch'), findsOneWidget);
    });

    testWidgets('Directions opens a map, outside the app', (tester) async {
      await _pumpMore(tester, user: _member);
      await _tap(tester, _key('campus-directions-button'));

      expect(_launched, hasLength(1));
      expect(_launched.single['url'], contains('Camberwell'));
      expect(find.text('route:/branch'), findsNothing);
    });

    testWidgets('Change branch offers the branches and applies the choice', (
      tester,
    ) async {
      final prefs = await _pumpMore(tester, user: _guest);
      await _tap(tester, _key('campus-change'));
      expect(find.byType(BranchPickerSheet), findsOneWidget);

      await _tap(
        tester,
        find.byKey(const ValueKey('branch-choice-Manchester')),
      );
      expect(find.byType(BranchPickerSheet), findsNothing);
      expect(prefs.getString('onboarding_branch'), 'Manchester');
    });

    testWidgets('with none chosen it asks for one and opens the list', (
      tester,
    ) async {
      await _pumpMore(tester, user: _member, branch: null);

      expect(_key('campus-card'), findsNothing);
      expect(find.text('Choose your branch'), findsOneWidget);
      expect(find.text('All branches'), findsNothing);

      await _tap(tester, _key('more-choose-branch'));
      expect(find.byType(BranchPickerSheet), findsOneWidget);
      expect(find.text('All branches'), findsNothing);
    });

    testWidgets('while the branch list has not loaded it still names the '
        'branch and lets the member change it', (tester) async {
      await _pumpMore(tester, user: _member, branches: const []);

      final card = _key('more-choose-branch-card');
      expect(
        find.descendant(of: card, matching: find.text('London')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: card, matching: find.text('Change branch')),
        findsOneWidget,
      );
    });
  });

  group('rows', () {
    testWidgets('a member sees them in order, Sign out last', (tester) async {
      await _pumpMore(tester, user: _member);

      final titles = [
        for (final row in tester.widgetList<KListRow>(
          find.descendant(
            of: find.byType(KListGroup).first,
            matching: find.byType(KListRow),
          ),
        ))
          row.title,
      ];
      expect(titles, [
        'Notifications',
        'Appearance',
        'Text size',
        "I'm new here",
        'Share a testimony',
        'Help & feedback',
        'Sign out',
      ]);
    });

    testWidgets('Notifications reads On when allowed and opens its settings', (
      tester,
    ) async {
      await _pumpMore(tester, user: _member);
      expect(_rowValue(tester, 'more-row-notifications'), 'On');

      await _tap(tester, _key('more-row-notifications'));
      expect(find.text('route:/settings/notifications'), findsOneWidget);
    });

    for (final permission in [
      NotificationPermission.askable,
      NotificationPermission.blocked,
    ]) {
      testWidgets('Notifications reads Off when ${permission.name}', (
        tester,
      ) async {
        await _pumpMore(tester, user: _member, permission: permission);
        expect(_rowValue(tester, 'more-row-notifications'), 'Off');
      });
    }

    testWidgets('Notifications reads Off when every kind is switched off', (
      tester,
    ) async {
      await _pumpMore(
        tester,
        user: _member,
        notificationPrefs: const {'sermons': false, 'events': false},
      );
      expect(_rowValue(tester, 'more-row-notifications'), 'Off');
    });

    testWidgets('Notifications shows no value when the phone cannot say', (
      tester,
    ) async {
      await _pumpMore(
        tester,
        user: _member,
        permission: NotificationPermission.unavailable,
      );
      expect(_rowValue(tester, 'more-row-notifications'), isNull);
      expect(find.text('Notifications'), findsOneWidget);
    });

    testWidgets('Appearance offers System, Light and Dark and keeps the '
        'choice', (tester) async {
      final prefs = await _pumpMore(tester, user: _member);
      expect(_rowValue(tester, 'more-row-appearance'), 'System');

      await _tap(tester, _key('more-row-appearance'));
      final sheet = find.byType(KSortSheet<ThemeMode>);
      expect(sheet, findsOneWidget);
      for (final label in ['System', 'Light', 'Dark']) {
        expect(
          find.descendant(of: sheet, matching: find.text(label)),
          findsOneWidget,
        );
      }

      await tester.tap(find.descendant(of: sheet, matching: find.text('Dark')));
      await tester.pumpAndSettle();

      expect(sheet, findsNothing);
      expect(_rowValue(tester, 'more-row-appearance'), 'Dark');
      expect(prefs.getString('settings_theme_mode'), 'dark');
      expect(
        Theme.of(tester.element(find.byType(SettingsScreen))).brightness,
        Brightness.dark,
      );
    });

    testWidgets('Appearance shows the stored choice', (tester) async {
      await _pumpMore(
        tester,
        user: _member,
        stored: {'settings_theme_mode': 'light'},
      );
      expect(_rowValue(tester, 'more-row-appearance'), 'Light');
    });

    testWidgets('Text size offers Small, Medium and Large and keeps the '
        'choice', (tester) async {
      final prefs = await _pumpMore(tester, user: _member);
      expect(_rowValue(tester, 'more-row-text-size'), 'Medium');

      await _tap(tester, _key('more-row-text-size'));
      final sheet = find.byType(KSortSheet<TextSizeChoice>);
      expect(sheet, findsOneWidget);
      for (final label in ['Small', 'Medium', 'Large']) {
        expect(
          find.descendant(of: sheet, matching: find.text(label)),
          findsOneWidget,
        );
      }

      await tester.tap(
        find.descendant(of: sheet, matching: find.text('Large')),
      );
      await tester.pumpAndSettle();

      expect(sheet, findsNothing);
      expect(_rowValue(tester, 'more-row-text-size'), 'Large');
      expect(prefs.getString('settings_text_size'), 'large');
    });

    testWidgets('closing a choice sheet without choosing changes nothing', (
      tester,
    ) async {
      final prefs = await _pumpMore(tester, user: _member);
      await _tap(tester, _key('more-row-text-size'));
      Navigator.of(
        tester.element(find.byType(KSortSheet<TextSizeChoice>)),
      ).pop();
      await tester.pumpAndSettle();

      expect(_rowValue(tester, 'more-row-text-size'), 'Medium');
      expect(prefs.containsKey('settings_text_size'), isFalse);
    });

    testWidgets("I'm new here and Share a testimony open their forms", (
      tester,
    ) async {
      await _pumpMore(tester, user: _member);
      await _tap(tester, _key('more-row-new-here'));
      expect(find.byType(NewHereScreen), findsOneWidget);

      Navigator.of(tester.element(find.byType(NewHereScreen))).pop();
      await tester.pumpAndSettle();
      await _tap(tester, _key('more-row-testimony'));
      expect(find.byType(TestimonyScreen), findsOneWidget);
    });

    testWidgets('Help & feedback opens the feedback sheet', (tester) async {
      await _pumpMore(tester, user: _member);
      await _tap(tester, _key('more-row-feedback'));
      expect(find.byType(FeedbackSheet), findsOneWidget);
    });

    testWidgets('Sign out asks first; Cancel keeps the member signed in', (
      tester,
    ) async {
      final auth = _FakeAuth();
      await _pumpMore(tester, user: _member, auth: auth);
      await _tap(tester, _key('more-row-sign-out'));
      expect(find.text('Are you sure you want to sign out?'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(auth.logouts, 0);
      expect(find.text('Are you sure you want to sign out?'), findsNothing);
    });

    testWidgets('Sign out, confirmed, signs out', (tester) async {
      final auth = _FakeAuth();
      await _pumpMore(tester, user: _member, auth: auth);
      await _tap(tester, _key('more-row-sign-out'));
      await tester.tap(_key('sign-out-confirm'));
      await tester.pumpAndSettle();

      expect(auth.logouts, 1);
      expect(find.text('Are you sure you want to sign out?'), findsNothing);
    });

    testWidgets('Contact us opens the live contact page inside the app', (
      tester,
    ) async {
      await _pumpMore(tester, user: _member);
      await _tap(tester, _key('more-row-contact'));
      expect(_launched.single['url'], 'https://kharis.org/contact-us/');
      expect(_launched.single['useSafariVC'], isTrue);
    });

    testWidgets('Privacy policy opens the live privacy page inside the app', (
      tester,
    ) async {
      await _pumpMore(tester, user: _guest);
      await _tap(tester, _key('more-row-privacy'));
      expect(_launched.single['url'], 'https://kharis.org/privacy-policy/');
      expect(_launched.single['useSafariVC'], isTrue);
    });

    testWidgets('a member can reach Delete account, below Sign out', (
      tester,
    ) async {
      await _pumpMore(tester, user: _member, auth: _FakeAuth());
      expect(
        tester.getTopLeft(_key('more-row-delete-account')).dy,
        greaterThan(tester.getTopLeft(_key('more-row-sign-out')).dy),
      );

      await _tap(tester, _key('more-row-delete-account'));
      expect(find.text('Delete account?'), findsOneWidget);
    });
  });

  group('footer', () {
    testWidgets('shows the installed version', (tester) async {
      await _pumpMore(tester, user: _member);
      final version = _key('app-version');
      expect(tester.widget<Text>(version).data, 'Kharis Church 1.4.2 (37)');
    });

    testWidgets('the list clears the floating tab bar', (tester) async {
      await _pumpMore(tester, user: _member);
      final scroll = tester.widget<SingleChildScrollView>(
        find.byType(SingleChildScrollView),
      );
      expect(
        scroll.padding!.resolve(TextDirection.ltr).bottom,
        KSize.contentBottomPad,
      );
    });
  });

  group('nothing overflows at 390 wide', () {
    for (final dark in const [false, true]) {
      for (final scale in const [1.0, 1.3, 2.0]) {
        final mode = dark ? 'dark' : 'light';
        final percent = (scale * 100).round();

        testWidgets('member · $mode · $percent%', (tester) async {
          await _pumpMore(
            tester,
            user: User(
              id: 'member-2',
              email: 'long@kharis.org',
              displayName: 'Oluwaseun Adebayo-Williamson',
              role: 'member',
              branch: 'London',
              createdAt: DateTime(2021),
            ),
            dark: dark,
            textScale: scale,
            data: moreScreenOverrides(
              notes: 62,
              downloads: 12,
              collections: 3,
              favourites: 5,
              readingStreak: 127,
              messagesStreak: 112,
              now: _monday,
            ),
          );

          expect(tester.takeException(), isNull);
          expect(
            tester.getSize(find.byType(SettingsScreen)).width,
            KSize.designWidth,
          );
          expect(_key('more-row-sign-out'), findsOneWidget);
        });

        testWidgets('guest, no branch · $mode · $percent%', (tester) async {
          await _pumpMore(
            tester,
            user: _guest,
            branch: null,
            dark: dark,
            textScale: scale,
          );

          expect(tester.takeException(), isNull);
          expect(_key('more-sign-in-card'), findsOneWidget);
          expect(_key('more-choose-branch-card'), findsOneWidget);
        });
      }
    }
  });

  group('nextServiceLabel', () {
    const services = [
      CampusService(
        id: 'sunday',
        name: 'Sunday Service',
        day: 'Sundays',
        startTime: '10:00',
      ),
      CampusService(
        id: 'midweek',
        name: 'Midweek Service',
        day: 'Wednesday',
        startTime: '19:00:00',
      ),
    ];

    test('is the next service to start, by weekday and time', () {
      expect(
        nextServiceLabel(services, DateTime(2026, 11, 16, 9)),
        'Midweek · Wed 19:00',
      );
      expect(
        nextServiceLabel(services, DateTime(2026, 11, 19, 9)),
        'Sunday · Sun 10:00',
      );
    });

    test('today counts until the service has started', () {
      final wednesday = DateTime(2026, 11, 18);
      expect(
        nextServiceLabel(services, wednesday.add(const Duration(hours: 18))),
        'Midweek · Wed 19:00',
      );
      expect(
        nextServiceLabel(services, wednesday.add(const Duration(hours: 19))),
        'Sunday · Sun 10:00',
      );
    });

    test(
      'with one weekly service, the day it has started it is next week\'s',
      () {
        expect(
          nextServiceLabel(const [
            CampusService(
              id: 'sunday',
              name: 'Sunday Service',
              day: 'Sunday',
              startTime: '10:00',
            ),
          ], DateTime(2026, 11, 15, 12)),
          'Sunday · Sun 10:00',
        );
      },
    );

    test('the earlier of two services on the same day comes first', () {
      expect(
        nextServiceLabel(const [
          CampusService(
            id: 'second',
            name: 'Second Service',
            day: 'Sunday',
            startTime: '11:30',
          ),
          CampusService(
            id: 'first',
            name: 'First Service',
            day: 'Sunday',
            startTime: '9:00',
          ),
        ], DateTime(2026, 11, 14, 20)),
        'First · Sun 09:00',
      );
    });

    test('reads a 12-hour time and one with no time at all', () {
      expect(
        nextServiceLabel(const [
          CampusService(
            id: 'prayer',
            name: 'Prayer',
            day: 'Friday',
            startTime: '7:00 PM',
          ),
        ], DateTime(2026, 11, 16)),
        'Prayer · Fri 19:00',
      );
      expect(
        nextServiceLabel(const [
          CampusService(id: 'prayer', name: 'Prayer', day: 'Friday'),
        ], DateTime(2026, 11, 16)),
        'Prayer · Fri',
      );
    });

    test('is null when no service names a weekday', () {
      expect(nextServiceLabel(const [], DateTime(2026, 11, 16)), isNull);
      expect(
        nextServiceLabel(const [
          CampusService(id: 'x', name: 'Retreat', day: 'Quarterly'),
        ], DateTime(2026, 11, 16)),
        isNull,
      );
    });
  });
}
