import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kharis_app/features/admin/presentation/screens/admin_hub_screen.dart';
import 'package:kharis_app/features/admin/presentation/screens/admin_users_screen.dart';
import 'package:kharis_app/features/onboarding/data/branch_repository.dart';
import 'package:kharis_app/shared/models/campus_config.dart';
import 'package:kharis_app/shared/providers/admin_provider.dart';
import 'package:kharis_app/shared/providers/auth_provider.dart';
import 'package:kharis_app/shared/providers/branch_provider.dart';

const _london = Branch(
  id: 'london',
  name: 'London',
  subtitle: 'Kensington',
  gradientStart: Color(0xFF000000),
  gradientEnd: Color(0xFF111111),
  order: 1,
);
const _leeds = Branch(
  id: 'leeds',
  name: 'Leeds',
  subtitle: 'Headingley',
  gradientStart: Color(0xFF000000),
  gradientEnd: Color(0xFF111111),
  order: 2,
);
const _accra = Branch(
  id: 'accra',
  name: 'Accra',
  subtitle: 'East Legon',
  gradientStart: Color(0xFF000000),
  gradientEnd: Color(0xFF111111),
  order: 3,
);

const _campusAdmin = AdminScope.campus(
  branchIds: {'london', 'leeds'},
  branchNames: {'London', 'Leeds'},
);

List<Override> _overrides(AdminScope scope, {FakeFirebaseFirestore? db}) => [
  adminScopeProvider.overrideWith((ref) => Stream.value(scope)),
  branchesProvider.overrideWith(
    (ref) => Stream.value(const [_london, _leeds, _accra]),
  ),
  if (db != null) firestoreProvider.overrideWithValue(db),
];

Future<void> _pump(
  WidgetTester tester,
  Widget home,
  List<Override> overrides,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(home: home),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('AdminScope.fromProfile', () {
    test('roles and campus lists map to scopes', () {
      expect(AdminScope.fromProfile({'role': 'admin'}).isSuperAdmin, isTrue);
      expect(
        AdminScope.fromProfile({
          'role': 'member',
        }, adminClaim: true).isSuperAdmin,
        isTrue,
      );
      final campus = AdminScope.fromProfile({
        'role': 'campus_admin',
        'adminBranchIds': ['london'],
        'adminBranchNames': ['London'],
      });
      expect(campus.isCampusAdmin, isTrue);
      expect(campus.canUseStudio, isTrue);
      expect(campus.branchNames, {'London'});
      expect(
        AdminScope.fromProfile({'role': 'campus_admin'}).canUseStudio,
        isFalse,
        reason: 'a campus admin without campuses has no Studio',
      );
    });
  });

  group('hub', () {
    testWidgets('a branch admin sees Notifications and their branches', (
      tester,
    ) async {
      await _pump(tester, const AdminHubScreen(), _overrides(_campusAdmin));

      expect(find.text('Leeds · London'), findsOneWidget);
      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('Team access'), findsNothing);
      expect(
        find.textContaining('managed in the Kharis Content Studio'),
        findsOneWidget,
      );
    });

    testWidgets('a super admin sees Notifications and Team access', (
      tester,
    ) async {
      await _pump(
        tester,
        const AdminHubScreen(),
        _overrides(const AdminScope.superAdmin()),
      );
      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('Team access'), findsOneWidget);
      for (final removed in [
        'Announcements',
        'Events',
        'Branches',
        'App settings',
        'Bible Reading',
        'Reading Plans',
        'Sermons',
      ]) {
        expect(find.text(removed), findsNothing, reason: removed);
      }
      expect(find.text('BRANCH ADMIN'), findsNothing);
    });
  });

  group('users', () {
    Future<FakeFirebaseFirestore> pumpUsers(WidgetTester tester) async {
      final db = FakeFirebaseFirestore();
      await db.collection('users').doc('u1').set({
        'displayName': 'Ada',
        'email': 'ada@kharis.org',
        'role': 'member',
      });
      await _pump(
        tester,
        const AdminUsersScreen(),
        _overrides(const AdminScope.superAdmin(), db: db),
      );
      return db;
    }

    testWidgets('making a campus admin writes the role and both campus lists', (
      tester,
    ) async {
      final db = await pumpUsers(tester);

      await tester.tap(find.text('Ada'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Branch admin'));
      await tester.pumpAndSettle();

      // Save stays disabled until a campus is picked.
      final save = find.widgetWithText(FilledButton, 'Make branch admin');
      expect(tester.widget<FilledButton>(save).onPressed, isNull);

      await tester.tap(find.text('London'));
      await tester.tap(find.text('Accra'));
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.pumpAndSettle();

      final data = (await db.collection('users').doc('u1').get()).data()!;
      expect(data['role'], 'campus_admin');
      expect(data['adminBranchIds'], ['london', 'accra']);
      expect(data['adminBranchNames'], ['London', 'Accra']);
      expect(find.text('Manages London, Accra'), findsOneWidget);
    });

    testWidgets('switching away from campus admin clears both lists', (
      tester,
    ) async {
      final db = await pumpUsers(tester);
      await db.collection('users').doc('u1').update({
        'role': 'campus_admin',
        'adminBranchIds': ['london'],
        'adminBranchNames': ['London'],
      });
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ada'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Member'));
      await tester.pumpAndSettle();

      final data = (await db.collection('users').doc('u1').get()).data()!;
      expect(data['role'], 'member');
      expect(data.containsKey('adminBranchIds'), isFalse);
      expect(data.containsKey('adminBranchNames'), isFalse);
    });
  });
}
