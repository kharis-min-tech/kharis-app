import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kharis_app/core/services/notification_service.dart';
import 'package:kharis_app/features/onboarding/data/auth_repository.dart';
import 'package:kharis_app/features/settings/data/account_deletion.dart';
import 'package:kharis_app/features/settings/presentation/screens/settings_screen.dart';
import 'package:kharis_app/features/settings/presentation/widgets/delete_account_flow.dart';
import 'package:kharis_app/shared/models/user.dart';
import 'package:kharis_app/shared/providers/admin_provider.dart';
import 'package:kharis_app/shared/providers/auth_provider.dart';
import 'package:kharis_app/shared/providers/branch_provider.dart';
import 'package:kharis_app/shared/providers/notification_provider.dart';
import 'package:kharis_app/shared/providers/onboarding_provider.dart';

// ── Fakes ─────────────────────────────────────────────────────────────────────

/// Every deletion step, in the order it ran.
final _log = <String>[];

class _FakeAuth implements AuthRepository {
  _FakeAuth({this.recentLoginFailures = 0});

  /// Members sign in with email + password.
  @override
  bool get usesPasswordSignIn => true;

  /// How many [deleteAccount] calls fail with requires-recent-login.
  int recentLoginFailures;

  /// Thrown by [reauthenticate] when set (a wrong password).
  Object? reauthError;

  @override
  Future<void> reauthenticate(String password) async {
    _log.add('reauth:$password');
    if (reauthError != null) throw reauthError!;
  }

  @override
  Future<void> deleteAccount() async {
    if (recentLoginFailures > 0) {
      recentLoginFailures--;
      _log.add('auth-delete:recent-login');
      throw const RecentLoginRequiredException();
    }
    _log.add('auth-delete');
  }

  @override
  Future<void> logout() async => _log.add('logout');

  @override
  Future<void> sendPasswordResetEmail(String email) async {}

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
  bool get isAuthenticated => true;

  @override
  Stream<User?> get authStateChanges => const Stream.empty();
}

class _FakeData implements AccountDataRepository {
  Object? error;

  @override
  Future<void> deleteUserData(String uid) async {
    if (error != null) {
      _log.add('data:$uid:failed');
      throw error!;
    }
    _log.add('data:$uid');
  }
}

class _FakeLocal implements LocalAccountData {
  @override
  Future<void> clear() async => _log.add('local');
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
  createdAt: DateTime(2024),
);

final _guest = User(
  id: 'anon-1',
  email: '',
  displayName: 'Guest',
  role: 'guest',
  createdAt: DateTime(2024),
);

Future<void> _pumpMore(
  WidgetTester tester, {
  required User? user,
  _FakeAuth? auth,
  _FakeData? data,
}) async {
  SharedPreferences.setMockInitialValues({'onboarding_branch': 'London'});
  final prefs = await SharedPreferences.getInstance();
  final router = GoRouter(
    initialLocation: '/more',
    routes: [
      GoRoute(path: '/more', builder: (_, _) => const SettingsScreen()),
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(body: Text('route:/')),
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
        isAdminProvider.overrideWith((ref) => false),
        branchesProvider.overrideWith((ref) => Stream.value(const [])),
        notificationServiceProvider.overrideWithValue(_QuietNotifications()),
        authRepositoryProvider.overrideWithValue(auth ?? _FakeAuth()),
        accountDataRepositoryProvider.overrideWithValue(data ?? _FakeData()),
        localAccountDataProvider.overrideWithValue(_FakeLocal()),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

final _row = find.text('Delete account').first;
final _confirm = find.widgetWithText(TextButton, 'Delete account');

Future<void> _openDialog(WidgetTester tester) async {
  await tester.ensureVisible(_row);
  await tester.pumpAndSettle();
  await tester.tap(_row);
  await tester.pumpAndSettle();
  expect(find.text('Delete account?'), findsOneWidget);
}

TextButton _button(WidgetTester tester) => tester.widget<TextButton>(_confirm);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  setUp(() {
    _log.clear();
    PackageInfo.setMockInitialValues(
      appName: 'Kharis Church',
      packageName: 'org.kharis.church',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
  });

  group('Delete account visibility', () {
    testWidgets('a signed-in member sees it below Sign out', (tester) async {
      await _pumpMore(tester, user: _member);
      expect(find.text('Delete account'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Delete account')).dy,
        greaterThan(tester.getTopLeft(find.text('Sign out')).dy),
      );
    });

    testWidgets('an anonymous guest does not see it', (tester) async {
      await _pumpMore(tester, user: _guest);
      expect(find.text('Delete account'), findsNothing);
    });

    testWidgets('a signed-out session does not see it', (tester) async {
      await _pumpMore(tester, user: null);
      expect(find.text('Delete account'), findsNothing);
    });
  });

  group('Delete account flow', () {
    testWidgets('states what is deleted; cancel deletes nothing', (
      tester,
    ) async {
      await _pumpMore(tester, user: _member);
      await _openDialog(tester);

      for (final line in [
        'Your profile and sign-in',
        'Your notes',
        'Your playlists and favourites',
        'Your event RSVPs',
      ]) {
        expect(find.textContaining(line), findsOneWidget);
      }
      expect(find.text('This cannot be undone.'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Delete account?'), findsNothing);
      expect(_log, isEmpty);
      expect(find.text('route:/'), findsNothing);
    });

    testWidgets('confirm needs the password, then deletes in order', (
      tester,
    ) async {
      await _pumpMore(tester, user: _member);
      await _openDialog(tester);

      expect(_button(tester).onPressed, isNull);
      await tester.enterText(
        find.byKey(const ValueKey('delete-account-password')),
        'secret',
      );
      await tester.pump();
      expect(_button(tester).onPressed, isNotNull);

      await tester.tap(_confirm);
      await tester.pumpAndSettle();

      expect(_log, ['reauth:secret', 'data:$_uid', 'auth-delete', 'local']);
      expect(find.text('route:/'), findsOneWidget);
      expect(find.text(kAccountDeletedMessage), findsOneWidget);
    });

    testWidgets('requires-recent-login asks for the password and retries', (
      tester,
    ) async {
      await _pumpMore(
        tester,
        user: _member,
        auth: _FakeAuth(recentLoginFailures: 1),
      );
      await _openDialog(tester);
      await tester.enterText(
        find.byKey(const ValueKey('delete-account-password')),
        'old',
      );
      await tester.pump();
      await tester.tap(_confirm);
      await tester.pumpAndSettle();

      expect(find.text('Confirm your password'), findsOneWidget);
      expect(find.text('route:/'), findsNothing);

      await tester.enterText(
        find.byKey(const ValueKey('confirm-password')),
        'fresh',
      );
      await tester.pump();
      await tester.tap(_confirm);
      await tester.pumpAndSettle();

      expect(_log, [
        'reauth:old',
        'data:$_uid',
        'auth-delete:recent-login',
        'reauth:fresh',
        'data:$_uid',
        'auth-delete',
        'local',
      ]);
      expect(find.text('route:/'), findsOneWidget);
      expect(find.text(kAccountDeletedMessage), findsOneWidget);
    });

    testWidgets('a failed deletion shows a message and stays put', (
      tester,
    ) async {
      final data = _FakeData()
        ..error = FirebaseException(
          plugin: 'cloud_firestore',
          code: 'unavailable',
        );
      await _pumpMore(tester, user: _member, data: data);
      await _openDialog(tester);
      await tester.enterText(
        find.byKey(const ValueKey('delete-account-password')),
        'secret',
      );
      await tester.pump();
      await tester.tap(_confirm);
      await tester.pumpAndSettle();

      expect(_log, ['reauth:secret', 'data:$_uid:failed']);
      expect(
        find.textContaining('We could not delete your account'),
        findsOneWidget,
      );
      expect(find.text('route:/'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('a wrong password says so and deletes nothing', (tester) async {
      final auth = _FakeAuth()
        ..reauthError = const InvalidCredentialsException(
          'That password is not correct',
        );
      await _pumpMore(tester, user: _member, auth: auth);
      await _openDialog(tester);
      await tester.enterText(
        find.byKey(const ValueKey('delete-account-password')),
        'wrong',
      );
      await tester.pump();
      await tester.tap(_confirm);
      await tester.pumpAndSettle();

      expect(_log, ['reauth:wrong']);
      expect(find.text('That password is not correct'), findsOneWidget);
      expect(find.text('route:/'), findsNothing);
    });
  });
}
