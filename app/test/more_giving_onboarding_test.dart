import 'dart:async';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kharis_app/core/services/notification_service.dart';
import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/features/connect/presentation/screens/new_here_screen.dart';
import 'package:kharis_app/features/connect/presentation/screens/testimony_screen.dart';
import 'package:kharis_app/features/giving/presentation/screens/giving_screen.dart';
import 'package:kharis_app/features/giving/presentation/screens/giving_webview_screen.dart';
import 'package:kharis_app/features/onboarding/data/auth_repository.dart';
import 'package:kharis_app/features/onboarding/data/branch_repository.dart';
import 'package:kharis_app/features/onboarding/presentation/screens/branch_selection_screen.dart';
import 'package:kharis_app/features/onboarding/presentation/screens/login_screen.dart';
import 'package:kharis_app/features/onboarding/presentation/screens/role_selection_screen.dart';
import 'package:kharis_app/features/settings/presentation/screens/edit_profile_screen.dart';
import 'package:kharis_app/features/settings/presentation/screens/notifications_settings_screen.dart';
import 'package:kharis_app/features/settings/presentation/screens/settings_screen.dart';
import 'package:kharis_app/shared/models/campus_config.dart';
import 'package:kharis_app/shared/models/user.dart';
import 'package:kharis_app/shared/providers/admin_provider.dart';
import 'package:kharis_app/shared/providers/auth_provider.dart';
import 'package:kharis_app/shared/providers/campus_config_provider.dart';
import 'package:kharis_app/shared/providers/branch_provider.dart';
import 'package:kharis_app/shared/providers/notification_provider.dart';
import 'package:kharis_app/shared/providers/onboarding_provider.dart';

// ── Fakes ─────────────────────────────────────────────────────────────────────

class _FakeAuth implements AuthRepository {
  final resetEmails = <String>[];
  int logouts = 0;

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    resetEmails.add(email);
  }

  @override
  Future<void> logout() async => logouts++;

  @override
  Future<User> login(String email, String password) =>
      throw UnimplementedError();

  @override
  Future<User> register({
    required String email,
    required String password,
    required String displayName,
    required String role,
  }) => throw UnimplementedError();

  @override
  Future<User> loginAsGuest() => throw UnimplementedError();

  @override
  User? get currentUser => null;

  @override
  bool get isAuthenticated => false;

  @override
  Stream<User?> get authStateChanges => const Stream.empty();
}

class _QuietNotifications extends NotificationService {
  @override
  Future<void> switchBranchTopic({String? from, String? to}) async {}
}

const _uid = 'member-1';

final _member = User(
  id: _uid,
  email: 'member@kharis.org',
  displayName: 'Grace Member',
  role: 'member',
  branch: 'London',
  createdAt: DateTime(2024),
);

final _guest = User(
  id: 'anon-1',
  email: '',
  displayName: 'Guest',
  role: 'guest',
  createdAt: DateTime(2024),
);

const _branches = [
  Branch(
    id: 'london',
    name: 'London',
    subtitle: 'England · Main campus',
    gradientStart: Color(0xFF5D3FD3),
    gradientEnd: Color(0xFF451EBB),
  ),
  Branch(
    id: 'manchester',
    name: 'Manchester',
    subtitle: 'England',
    gradientStart: Color(0xFF5D3FD3),
    gradientEnd: Color(0xFF451EBB),
  ),
];

/// URLs handed to url_launcher (method-channel implementation in tests).
final _launched = <String>[];

/// Text written to the system clipboard.
final _clipboard = <String>[];

void _mockPlatformChannels() {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/url_launcher'),
    (call) async {
      if (call.method == 'launch') {
        _launched.add((call.arguments as Map)['url'] as String);
      }
      return true;
    },
  );
  messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
    if (call.method == 'Clipboard.setData') {
      _clipboard.add((call.arguments as Map)['text'] as String);
    }
    return null;
  });
}

Future<SharedPreferences> _prefs([Map<String, Object> values = const {}]) {
  SharedPreferences.setMockInitialValues(values);
  return SharedPreferences.getInstance();
}

List<Override> _baseOverrides({
  required SharedPreferences prefs,
  required FakeFirebaseFirestore db,
  User? user,
  AuthRepository? auth,
  List<Branch> branches = _branches,
}) => [
  sharedPreferencesProvider.overrideWithValue(prefs),
  firestoreProvider.overrideWithValue(db),
  currentUserProvider.overrideWith((ref) => Stream.value(user)),
  isAdminProvider.overrideWith((ref) => false),
  branchesProvider.overrideWith((ref) => Stream.value(branches)),
  notificationServiceProvider.overrideWithValue(_QuietNotifications()),
  notificationPrefsProvider.overrideWith(
    (ref) => Stream.value(const <String, bool>{}),
  ),
  notificationPermissionProvider.overrideWith((ref) async => true),
  if (auth != null) authRepositoryProvider.overrideWithValue(auth),
];

/// Pumps More inside a router whose destinations are labelled stubs, so a tap
/// proves which route a row opened.
Future<GoRouter> _pumpMore(
  WidgetTester tester, {
  User? user,
  AuthRepository? auth,
}) async {
  final prefs = await _prefs({'onboarding_branch': 'London'});
  Widget stub(String label) => Scaffold(body: Text('route:$label'));
  final router = GoRouter(
    initialLocation: '/more',
    routes: [
      GoRoute(path: '/more', builder: (_, _) => const SettingsScreen()),
      for (final path in [
        '/reading',
        '/notes',
        '/favorites',
        '/playlists',
        '/branch-selection',
        '/giving',
        '/login',
        '/register',
        '/profile/edit',
      ])
        GoRoute(path: path, builder: (_, _) => stub(path)),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: _baseOverrides(
        prefs: prefs,
        db: FakeFirebaseFirestore(),
        user: user,
        auth: auth,
      ),
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

Future<void> _tapRow(WidgetTester tester, String label) async {
  final row = find.text(label);
  await tester.ensureVisible(row);
  await tester.pumpAndSettle();
  await tester.tap(row);
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  setUp(() {
    _launched.clear();
    _clipboard.clear();
    _mockPlatformChannels();
    PackageInfo.setMockInitialValues(
      appName: 'Kharis Church',
      packageName: 'org.kharis.church',
      version: '1.4.2',
      buildNumber: '37',
      buildSignature: '',
    );
  });

  group('More', () {
    for (final (label, route) in [
      ('Daily Reading', '/reading'),
      ('My Notes', '/notes'),
      ('Favorites', '/favorites'),
      ('My Playlists', '/playlists'),
      ('Switch Branch', '/branch-selection'),
      ('Give', '/giving'),
    ]) {
      testWidgets('"$label" opens $route', (tester) async {
        await _pumpMore(tester, user: _member);
        await _tapRow(tester, label);
        expect(find.text('route:$route'), findsOneWidget);
      });
    }

    testWidgets('Favorites sits directly above My Playlists', (tester) async {
      await _pumpMore(tester, user: _member);
      final notes = tester.getTopLeft(find.text('My Notes')).dy;
      final favorites = tester.getTopLeft(find.text('Favorites')).dy;
      final playlists = tester.getTopLeft(find.text('My Playlists')).dy;
      expect(favorites, lessThan(playlists));
      // Adjacent rows: the gap to My Playlists is one row, the same step as
      // My Notes to Favorites, so nothing sits between them.
      expect(playlists - favorites, moreOrLessEquals(favorites - notes));
    });

    testWidgets('there is no fake "My Giving History" row', (tester) async {
      await _pumpMore(tester, user: _member);
      expect(find.text('My Giving History'), findsNothing);
    });

    testWidgets('Switch Branch shows the active campus', (tester) async {
      await _pumpMore(tester, user: _member);
      expect(find.text('London'), findsWidgets);
    });

    testWidgets('Notifications opens notification settings', (tester) async {
      await _pumpMore(tester, user: _member);
      await _tapRow(tester, 'Notifications');
      expect(find.byType(NotificationsSettingsScreen), findsOneWidget);
    });

    testWidgets("I'm new here and Share a testimony open their forms", (
      tester,
    ) async {
      await _pumpMore(tester, user: _member);
      await _tapRow(tester, "I'm new here");
      expect(find.byType(NewHereScreen), findsOneWidget);
      await tester.tap(find.byIcon(Icons.arrow_back_ios));
      await tester.pumpAndSettle();
      await _tapRow(tester, 'Share a testimony');
      expect(find.byType(TestimonyScreen), findsOneWidget);
    });

    testWidgets('Help & Support opens the live contact page', (tester) async {
      await _pumpMore(tester, user: _member);
      await _tapRow(tester, 'Help & Support');
      expect(_launched, ['https://kharis.org/contact-us/']);
    });

    testWidgets('Privacy Policy opens the live privacy page', (tester) async {
      await _pumpMore(tester, user: _member);
      await _tapRow(tester, 'Privacy Policy');
      expect(_launched, ['https://kharis.org/privacy-policy/']);
    });

    testWidgets('the profile card Edit opens profile edit', (tester) async {
      await _pumpMore(tester, user: _member);
      await _tapRow(tester, 'Edit');
      expect(find.text('route:/profile/edit'), findsOneWidget);
    });

    testWidgets('a guest gets Sign in, which opens login', (tester) async {
      await _pumpMore(tester, user: _guest);
      expect(find.text('Sign out'), findsNothing);
      await _tapRow(tester, 'Sign in');
      expect(find.text('route:/login'), findsOneWidget);
    });

    testWidgets('Sign out confirms, then signs out', (tester) async {
      final auth = _FakeAuth();
      await _pumpMore(tester, user: _member, auth: auth);
      await _tapRow(tester, 'Sign out');
      expect(find.text('Are you sure you want to sign out?'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Sign out'));
      await tester.pumpAndSettle();
      expect(auth.logouts, 1);
    });

    testWidgets('shows the installed version from PackageInfo', (tester) async {
      await _pumpMore(tester, user: _member);
      final version = find.byKey(const ValueKey('app-version'));
      await tester.ensureVisible(version);
      expect(tester.widget<Text>(version).data, 'Kharis Church 1.4.2 (37)');
      expect(find.textContaining('v2.0.0'), findsNothing);
    });
  });

  group('Giving', () {
    Future<SharedPreferences> pumpGiving(WidgetTester tester) async {
      final prefs = await _prefs({'onboarding_branch': 'London'});
      await tester.pumpWidget(
        ProviderScope(
          overrides: _baseOverrides(prefs: prefs, db: FakeFirebaseFirestore()),
          child: const MaterialApp(home: GivingScreen()),
        ),
      );
      await tester.pumpAndSettle();
      return prefs;
    }

    testWidgets('has no campaign card or invented progress', (tester) async {
      await pumpGiving(tester);
      expect(find.text('Build God a House'), findsNothing);
      expect(find.textContaining('raised'), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.text('Give securely'), findsOneWidget);
    });

    testWidgets('scripture is 2 Corinthians 9:7 itself', (tester) async {
      await pumpGiving(tester);
      expect(find.textContaining('God loves a cheerful giver'), findsOneWidget);
      expect(find.text('2 Corinthians 9:7 (NKJV)'), findsOneWidget);
    });

    testWidgets('Copy bank details copies exactly the displayed rows', (
      tester,
    ) async {
      await pumpGiving(tester);
      final button = find.text('Copy bank details');
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();

      expect(_clipboard, [
        'Account name: Kharis Ministries\n'
            'Account number: 80608335\n'
            'Sort code: 20-71-82\n'
            'SWIFT/BIC: BUKBGB22\n'
            'IBAN: GB88BUKB20718280608335',
      ]);
      // Every copied value is on screen.
      for (final (_, value) in givingBankRows(kBuiltInGiving)) {
        expect(find.text(value), findsOneWidget);
      }
      expect(find.text('Bank details copied'), findsOneWidget);
    });

    testWidgets('Giving to opens the shared campus sheet and persists', (
      tester,
    ) async {
      final prefs = await pumpGiving(tester);
      await tester.tap(find.byKey(const ValueKey('giving-branch-selector')));
      await tester.pumpAndSettle();
      expect(find.text('Choose your branch'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('branch-choice-Manchester')));
      await tester.pumpAndSettle();
      expect(prefs.getString('onboarding_branch'), 'Manchester');
      expect(find.text('Manchester'), findsOneWidget);
    });

    test('the secure giving URL is the live giving page', () {
      expect(kGivingUrl, 'https://kharis.org/giving/');
      expect(kBuiltInGiving.url, kGivingUrl);
    });

    testWidgets('a campus with no account of its own gives church-wide', (
      tester,
    ) async {
      await pumpGiving(tester);
      expect(find.text('London'), findsOneWidget);
      expect(find.text('Kharis Church account'), findsOneWidget);
      expect(find.text('To Kharis Church'), findsOneWidget);
    });

    testWidgets('a campus account names the campus and replaces every row', (
      tester,
    ) async {
      final prefs = await _prefs({'onboarding_branch': 'London'});
      await tester.pumpWidget(
        ProviderScope(
          overrides: _baseOverrides(
            prefs: prefs,
            db: FakeFirebaseFirestore(),
            branches: const [
              Branch(
                id: 'london',
                name: 'London',
                subtitle: 'England · Main campus',
                gradientStart: Color(0xFF5D3FD3),
                gradientEnd: Color(0xFF451EBB),
                giving: GivingDetails(
                  accountName: 'Kharis London',
                  sortCode: '11-22-33',
                  accountNumber: '12345678',
                  reference: 'LONDON TITHE',
                  note: 'Gift Aid forms are at the welcome desk.',
                ),
              ),
            ],
          ),
          child: const MaterialApp(home: GivingScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('London account'), findsOneWidget);
      expect(find.text('To London'), findsOneWidget);
      // No campus giving page: nothing to open securely.
      expect(find.text('Give securely'), findsNothing);
      expect(
        find.text('Gift Aid forms are at the welcome desk.'),
        findsOneWidget,
      );
      expect(find.text('Kharis Ministries'), findsNothing);

      final button = find.text('Copy bank details');
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(
        _clipboard.last,
        [
          'Account name: Kharis London',
          'Account number: 12345678',
          'Sort code: 11-22-33',
          'Reference: LONDON TITHE',
        ].join('\n'),
      );
    });

    testWidgets('config/giving is the church-wide account when set', (
      tester,
    ) async {
      final prefs = await _prefs({'onboarding_branch': 'London'});
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ..._baseOverrides(prefs: prefs, db: FakeFirebaseFirestore()),
            churchGivingProvider.overrideWith(
              (ref) => Stream.value(
                const GivingDetails(
                  url: 'https://give.example.org',
                  accountName: 'Kharis Church UK',
                  accountNumber: '87654321',
                ),
              ),
            ),
          ],
          child: const MaterialApp(home: GivingScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Kharis Church UK'), findsOneWidget);
      expect(find.text('Kharis Ministries'), findsNothing);
      expect(find.text('Kharis Church account'), findsOneWidget);
      expect(find.text('Give securely'), findsOneWidget);
      expect(
        find.text('Opens the secure Kharis Church giving page'),
        findsOneWidget,
      );
    });

    testWidgets('the giving page error state retries', (tester) async {
      var retries = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GivingLoadError(
              onRetry: () => retries++,
              onOpenInBrowser: () {},
            ),
          ),
        ),
      );
      expect(find.text('We could not open the giving page'), findsOneWidget);
      await tester.tap(find.text('Retry'));
      expect(retries, 1);
    });
  });

  group('Edit profile', () {
    Future<(SharedPreferences, FakeFirebaseFirestore)> pumpEdit(
      WidgetTester tester,
      User? user,
    ) async {
      final prefs = await _prefs({'onboarding_branch': 'London'});
      final db = FakeFirebaseFirestore();
      await db.collection('users').doc(_uid).set({'branch': 'London'});
      await tester.pumpWidget(
        ProviderScope(
          overrides: _baseOverrides(prefs: prefs, db: db, user: user),
          child: const MaterialApp(home: EditProfileScreen()),
        ),
      );
      await tester.pumpAndSettle();
      return (prefs, db);
    }

    testWidgets('a guest sees a sign-in prompt, not a form', (tester) async {
      await pumpEdit(tester, _guest);
      expect(find.text('Sign in to edit your profile'), findsOneWidget);
      expect(find.text('Save changes'), findsNothing);
    });

    testWidgets('signed out sees the same sign-in prompt', (tester) async {
      await pumpEdit(tester, null);
      expect(find.text('Sign in to edit your profile'), findsOneWidget);
    });

    testWidgets('campus change goes through setActiveBranch', (tester) async {
      final (prefs, db) = await pumpEdit(tester, _member);
      expect(find.text('Save changes'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('profile-campus-row')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('branch-choice-Manchester')));
      await tester.pumpAndSettle();

      expect(prefs.getString('onboarding_branch'), 'Manchester');
      final doc = await db.collection('users').doc(_uid).get();
      expect(doc.data()?['branch'], 'Manchester');
    });
  });

  group('Onboarding', () {
    testWidgets('Forgot password sends a reset email via the repository', (
      tester,
    ) async {
      final prefs = await _prefs();
      final auth = _FakeAuth();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            authRepositoryProvider.overrideWithValue(auth),
          ],
          child: const MaterialApp(home: LoginScreen()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextFormField).first,
        'grace@kharis.org',
      );
      await tester.tap(find.text('Forgot password?'));
      await tester.pumpAndSettle();
      expect(find.text('Reset your password'), findsOneWidget);

      await tester.tap(find.text('Send reset link'));
      await tester.pumpAndSettle();

      expect(auth.resetEmails, ['grace@kharis.org']);
      expect(find.text('Reset your password'), findsNothing);
      expect(find.textContaining('reset link is on its way'), findsOneWidget);
    });

    testWidgets('Forgot password rejects a malformed email', (tester) async {
      final prefs = await _prefs();
      final auth = _FakeAuth();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            authRepositoryProvider.overrideWithValue(auth),
          ],
          child: const MaterialApp(home: LoginScreen()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Forgot password?'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('reset-email')),
        'not-an-email',
      );
      await tester.tap(find.text('Send reset link'));
      await tester.pumpAndSettle();
      expect(auth.resetEmails, isEmpty);
      expect(find.text('Enter a valid email address'), findsOneWidget);
    });

    testWidgets('the sign-in button text is gold ink, not white', (
      tester,
    ) async {
      final prefs = await _prefs();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
          child: const MaterialApp(home: LoginScreen()),
        ),
      );
      await tester.pumpAndSettle();
      final label = tester.widget<Text>(
        find.descendant(
          of: find.byType(ElevatedButton),
          matching: find.text('Sign in'),
        ),
      );
      expect(label.style?.color, KharisColors.light.onAccent);
    });

    testWidgets('role selection: privacy link works, no dead links or '
        'language picker', (tester) async {
      final prefs = await _prefs();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
          child: const MaterialApp(home: RoleSelectionScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Terms of Service'), findsNothing);
      expect(find.text('English (UK)'), findsNothing);
      expect(find.byIcon(Icons.language_rounded), findsNothing);

      await tester.ensureVisible(find.text('Privacy Policy'));
      await tester.tap(find.text('Privacy Policy'));
      await tester.pumpAndSettle();
      expect(_launched, ['https://kharis.org/privacy-policy/']);
    });

    testWidgets('Switch Branch from More keeps the onboarded role', (
      tester,
    ) async {
      // Onboarded, no stored role (e.g. signed in on a fresh install): the old
      // flow re-ran completeOnboarding and stamped role "member".
      final prefs = await _prefs({
        'onboarding_completed': true,
        'onboarding_branch': 'London',
      });
      final router = GoRouter(
        initialLocation: '/more',
        routes: [
          GoRoute(
            path: '/more',
            builder: (_, _) => const Scaffold(body: Text('More')),
          ),
          GoRoute(
            path: '/branch-selection',
            builder: (_, _) => const BranchSelectionScreen(),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: _baseOverrides(prefs: prefs, db: FakeFirebaseFirestore()),
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      unawaited(router.push('/branch-selection'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Manchester'));
      await tester.pumpAndSettle();

      expect(prefs.getString('onboarding_branch'), 'Manchester');
      expect(prefs.containsKey('onboarding_role'), isFalse);
      expect(find.text('More'), findsOneWidget, reason: 'pops back to More');
    });
  });
}
