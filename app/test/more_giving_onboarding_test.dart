import 'dart:async';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kharis_app/core/services/notification_service.dart';
import 'package:kharis_app/features/giving/presentation/screens/giving_screen.dart';
import 'package:kharis_app/features/onboarding/data/auth_repository.dart';
import 'package:kharis_app/features/onboarding/data/branch_repository.dart';
import 'package:kharis_app/features/onboarding/presentation/screens/branch_selection_screen.dart';
import 'package:kharis_app/features/onboarding/presentation/screens/login_screen.dart';
import 'package:kharis_app/features/onboarding/presentation/screens/role_selection_screen.dart';
import 'package:kharis_app/features/onboarding/presentation/widgets/role_card.dart';
import 'package:kharis_app/features/settings/presentation/screens/edit_profile_screen.dart';
import 'package:kharis_app/shared/models/campus_config.dart';
import 'package:kharis_app/shared/models/user.dart';
import 'package:kharis_app/shared/providers/admin_provider.dart';
import 'package:kharis_app/shared/providers/auth_provider.dart';
import 'package:kharis_app/shared/providers/campus_config_provider.dart';
import 'package:kharis_app/shared/providers/branch_provider.dart';
import 'package:kharis_app/shared/providers/notification_provider.dart';
import 'package:kharis_app/shared/providers/onboarding_provider.dart';
import 'package:kharis_app/ui/components/components.dart';

// ── Fakes ─────────────────────────────────────────────────────────────────────

class _FakeAuth implements AuthRepository {
  final resetEmails = <String>[];
  int guestLogins = 0;
  bool guestFails = false;

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    resetEmails.add(email);
  }

  @override
  Future<void> logout() async {}

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
  Future<User> loginAsGuest() async {
    guestLogins++;
    if (guestFails) throw Exception('network');
    return _guest;
  }

  @override
  bool get usesPasswordSignIn => false;

  @override
  Future<void> reauthenticate(String password) => throw UnimplementedError();

  @override
  Future<void> deleteAccount() => throw UnimplementedError();

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
  Branch(id: 'london', name: 'London', subtitle: 'England · Main campus'),
  Branch(id: 'manchester', name: 'Manchester', subtitle: 'England'),
];

/// URLs handed to url_launcher (method-channel implementation in tests).
final _launched = <String>[];

/// Full argument maps of [_launched] (launch mode flags included).
final _launchArgs = <Map<String, Object?>>[];

/// Text written to the system clipboard.
final _clipboard = <String>[];

void _mockPlatformChannels() {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/url_launcher'),
    (call) async {
      if (call.method == 'launch') {
        final args = Map<String, Object?>.from(call.arguments as Map);
        _launched.add(args['url']! as String);
        _launchArgs.add(args);
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
  branchesProvider.overrideWith((ref) => Stream.value(branches)),
  notificationServiceProvider.overrideWithValue(_QuietNotifications()),
  notificationPrefsProvider.overrideWith(
    (ref) => Stream.value(const <String, bool>{}),
  ),
  notificationPermissionProvider.overrideWith(
    (ref) async => NotificationPermission.granted,
  ),
  if (auth != null) authRepositoryProvider.overrideWithValue(auth),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    _launched.clear();
    _launchArgs.clear();
    _clipboard.clear();
    _mockPlatformChannels();
  });

  group('Giving', () {
    Future<SharedPreferences> pumpGiving(WidgetTester tester) async {
      final prefs = await _prefs({'onboarding_branch': 'London'});
      await tester.pumpWidget(
        ProviderScope(
          overrides: _baseOverrides(prefs: prefs, db: FakeFirebaseFirestore()),
          child: MaterialApp(
            theme: KharisTheme.light(),
            home: const GivingScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return prefs;
    }

    testWidgets('has no campaign card or invented progress, and none of the '
        'canvas extras', (tester) async {
      await pumpGiving(tester);
      expect(find.text('Build God a House'), findsNothing);
      expect(find.textContaining('raised'), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      for (final extra in ['Tithe', 'Offering', 'Gift Aid', 'Monthly']) {
        expect(find.textContaining(extra), findsNothing);
      }
      expect(find.text('Give'), findsOneWidget);
      expect(find.text('To London. Thank you for giving.'), findsOneWidget);
      // One primary button, 56 tall.
      final primary = find.byWidgetPredicate(
        (w) => w is KButton && w.variant == KButtonVariant.primary,
      );
      expect(primary, findsOneWidget);
      expect(find.widgetWithText(KButton, 'Give to London'), findsOneWidget);
      expect(tester.getSize(primary).height, KSize.cta);
    });

    testWidgets('scripture is 2 Corinthians 9:7 itself (KJV)', (tester) async {
      await pumpGiving(tester);
      expect(
        find.text(
          '\u201cEvery man according as he purposeth in his heart, so let '
          'him give; not grudgingly, or of necessity: for God loveth a '
          'cheerful giver.\u201d',
        ),
        findsOneWidget,
      );
      expect(find.text('2 CORINTHIANS 9:7 \u00b7 KJV'), findsOneWidget);
    });

    testWidgets('says where the gift is made, under the Give button', (
      tester,
    ) async {
      await pumpGiving(tester);
      final note = find.text(
        'You give securely on kharis.org, inside the app.',
      );
      expect(note, findsOneWidget);
      expect(
        tester.getTopLeft(note).dy,
        greaterThan(tester.getBottomLeft(find.text('Give')).dy),
      );
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

    testWidgets('Give to <branch> opens kharis.org inside the app (in-app '
        'browser, never another app); no branch picker', (tester) async {
      await pumpGiving(tester);
      expect(find.text('GIVING TO'), findsNothing);
      expect(find.text('Change'), findsNothing);

      await tester.tap(find.text('Give to London'));
      await tester.pumpAndSettle();
      expect(_launched, ['https://kharis.org/giving/']);
      // Safari View Controller / Custom Tabs: the page stays in the app.
      expect(_launchArgs.single['useSafariVC'], isTrue);
      expect(_launchArgs.single['universalLinksOnly'], isFalse);
    });

    test('the secure giving URL is the live giving page', () {
      expect(kGivingUrl, 'https://kharis.org/giving/');
      expect(kBuiltInGiving.url, kGivingUrl);
    });

    testWidgets('a branch account never replaces the church-wide details', (
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
                giving: GivingDetails(
                  accountName: 'Kharis London',
                  accountNumber: '12345678',
                ),
              ),
            ],
          ),
          child: MaterialApp(
            theme: KharisTheme.light(),
            home: const GivingScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('To Kharis Church'), findsOneWidget);
      expect(find.text('Kharis Ministries'), findsOneWidget);
      expect(find.text('Kharis London'), findsNothing);
      expect(find.text('Give to London'), findsOneWidget);
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
          child: MaterialApp(
            theme: KharisTheme.light(),
            home: const EditProfileScreen(),
          ),
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
      // Every field has a visible label.
      for (final label in [
        'Display name',
        'Home branch',
        'Avatar image URL (optional)',
        'Phone (optional)',
        'Birthday (optional)',
      ]) {
        expect(find.text(label), findsOneWidget);
      }

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
          child: MaterialApp(
            theme: KharisTheme.light(),
            home: const LoginScreen(),
          ),
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
          child: MaterialApp(
            theme: KharisTheme.light(),
            home: const LoginScreen(),
          ),
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

    testWidgets('sign in is the one primary button, 56 high', (tester) async {
      final prefs = await _prefs();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
          child: MaterialApp(
            theme: KharisTheme.light(),
            home: const LoginScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final primary = find.byWidgetPredicate(
        (w) => w is KButton && w.variant == KButtonVariant.primary,
      );
      expect(primary, findsOneWidget);
      expect(tester.widget<KButton>(primary).label, 'Sign in');
      expect(tester.getSize(primary).height, greaterThanOrEqualTo(KSize.cta));
    });

    testWidgets('role selection: privacy link works, no dead links or '
        'language picker', (tester) async {
      final prefs = await _prefs();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
          child: MaterialApp(
            theme: KharisTheme.light(),
            home: const RoleSelectionScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Terms of Service'), findsNothing);
      expect(find.text('English (UK)'), findsNothing);
      expect(find.byIcon(Icons.language_rounded), findsNothing);

      await tester.ensureVisible(find.text('Privacy policy'));
      await tester.tap(find.text('Privacy policy'));
      await tester.pumpAndSettle();
      expect(_launched, ['https://kharis.org/privacy-policy/']);
    });

    testWidgets('role selection offers each way in once: first-timers and '
        'visitors share New here (team review: duplicate option)', (
      tester,
    ) async {
      final prefs = await _prefs();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
          child: MaterialApp(
            theme: KharisTheme.light(),
            home: const RoleSelectionScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final titles = [
        for (final card in tester.widgetList<RoleCard>(find.byType(RoleCard)))
          card.title,
      ];
      expect(titles, ['Member', 'New here', 'Partner']);
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
          child: MaterialApp.router(
            theme: KharisTheme.light(),
            routerConfig: router,
          ),
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

    group('Continue as guest', () {
      Future<void> pumpLogin(WidgetTester tester, _FakeAuth auth) async {
        final prefs = await _prefs();
        final router = GoRouter(
          initialLocation: '/login',
          routes: [
            GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
            GoRoute(
              path: '/branch-selection',
              builder: (_, _) => const Scaffold(body: Text('Pick a branch')),
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
              authRepositoryProvider.overrideWithValue(auth),
            ],
            child: MaterialApp.router(
              theme: KharisTheme.light(),
              routerConfig: router,
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      Finder guestButton() => find.ancestor(
        of: find.text('Continue as guest'),
        matching: find.byType(KButton),
      );

      testWidgets('a tap anywhere on the button signs in and asks for a '
          'branch', (tester) async {
        final auth = _FakeAuth();
        await pumpLogin(tester, auth);
        await tester.ensureVisible(guestButton());
        // Tap the button's edge, not its label: the whole box is the target.
        final box = tester.getRect(guestButton());
        await tester.tapAt(box.centerLeft + const Offset(12, 0));
        await tester.pumpAndSettle();
        expect(auth.guestLogins, 1);
        expect(find.text('Pick a branch'), findsOneWidget);
      });

      testWidgets('a failed guest sign-in says so and re-enables the button', (
        tester,
      ) async {
        final auth = _FakeAuth()..guestFails = true;
        await pumpLogin(tester, auth);
        await tester.ensureVisible(guestButton());
        await tester.tap(guestButton());
        await tester.pumpAndSettle();
        expect(find.textContaining('Could not continue as a guest'), findsOne);
        expect(find.text('Pick a branch'), findsNothing);
        expect(tester.widget<KButton>(guestButton()).onPressed, isNotNull);
      });
    });
  });
}
