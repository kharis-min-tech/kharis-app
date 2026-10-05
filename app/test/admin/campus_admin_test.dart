import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kharis_app/features/admin/presentation/screens/admin_announcements_screen.dart';
import 'package:kharis_app/features/admin/presentation/screens/admin_branch_detail_screen.dart';
import 'package:kharis_app/features/admin/presentation/screens/admin_hub_screen.dart';
import 'package:kharis_app/features/admin/presentation/screens/admin_users_screen.dart';
import 'package:kharis_app/features/admin/presentation/widgets/event_form_sheet.dart';
import 'package:kharis_app/features/calendar/data/event_repository.dart';
import 'package:kharis_app/features/home/data/news_repository.dart';
import 'package:kharis_app/features/onboarding/data/branch_repository.dart';
import 'package:kharis_app/shared/models/campus_config.dart';
import 'package:kharis_app/shared/providers/admin_provider.dart';
import 'package:kharis_app/shared/providers/auth_provider.dart';
import 'package:kharis_app/shared/providers/branch_provider.dart';
import 'package:kharis_app/shared/providers/sermon_provider.dart';

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
      expect(campus.canManageCampusNamed('London'), isTrue);
      expect(campus.canManageCampusNamed(null), isFalse);
      expect(
        AdminScope.fromProfile({'role': 'campus_admin'}).canUseStudio,
        isFalse,
        reason: 'a campus admin without campuses has no Studio',
      );
    });
  });

  group('hub', () {
    testWidgets('a campus admin sees only their campus sections', (
      tester,
    ) async {
      await _pump(tester, const AdminHubScreen(), _overrides(_campusAdmin));

      expect(find.text('Leeds · London'), findsOneWidget);
      expect(find.text('Announcements'), findsOneWidget);
      expect(find.text('Events'), findsOneWidget);
      expect(find.text('Your branch'), findsOneWidget);
      for (final hidden in [
        'Users',
        'Sermons',
        'App settings',
        'Bible Reading',
        'Reading Plans',
        'Branches',
      ]) {
        expect(find.text(hidden), findsNothing, reason: hidden);
      }
    });

    testWidgets('a super admin sees every section', (tester) async {
      await _pump(
        tester,
        const AdminHubScreen(),
        _overrides(const AdminScope.superAdmin()),
      );
      for (final shown in [
        'Announcements',
        'Events',
        'Branches',
        'App settings',
        'Users',
        'Bible Reading',
        'Reading Plans',
        'Sermons',
      ]) {
        await tester.scrollUntilVisible(find.text(shown), 100);
        expect(find.text(shown), findsOneWidget, reason: shown);
      }
      expect(find.text('BRANCH ADMIN'), findsNothing);
    });
  });

  group('campus pickers', () {
    Future<void> openEventForm(WidgetTester tester, AdminScope scope) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: _overrides(scope),
          child: MaterialApp(
            home: Scaffold(
              // The Studio screens that open this form already watch the
              // scope, so it has resolved by the time the form opens.
              body: Consumer(
                builder: (context, ref, _) {
                  ref.watch(adminScopeProvider);
                  return TextButton(
                    onPressed: () => showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => EventFormSheet(
                        eventRepo: EventRepository(
                          firestore: FakeFirebaseFirestore(),
                        ),
                        onSuccess: (_) {},
                        onError: (_) {},
                      ),
                    ),
                    child: const Text('open'),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets(
      'a campus admin can only pick their campuses, with no all-campus option',
      (tester) async {
        await openEventForm(tester, _campusAdmin);

        // A new event starts on one of their campuses.
        final field = find.byType(DropdownButtonFormField<String?>);
        expect(
          find.descendant(of: field, matching: find.text('Leeds')),
          findsOneWidget,
        );

        await tester.tap(field);
        await tester.pumpAndSettle();
        expect(find.text('London'), findsWidgets);
        expect(find.text('Leeds'), findsWidgets);
        expect(find.text('Accra'), findsNothing);
        expect(find.text('All branches'), findsNothing);
      },
    );

    testWidgets('a super admin keeps every campus and all-campus', (
      tester,
    ) async {
      await openEventForm(tester, const AdminScope.superAdmin());

      await tester.tap(find.byType(DropdownButtonFormField<String?>));
      await tester.pumpAndSettle();
      expect(find.text('Accra'), findsWidgets);
      expect(find.text('All branches'), findsWidgets);
    });

    testWidgets('the announcements list shows only their campuses', (
      tester,
    ) async {
      NewsItem item(String id, String? branch) => NewsItem(
        id: id,
        title: 'News $id',
        type: NewsItem.types.first,
        publishedAt: DateTime(2026, 10, 1),
        branch: branch,
      );
      await _pump(tester, const AdminAnnouncementsScreen(), [
        ..._overrides(_campusAdmin),
        adminNewsProvider.overrideWith(
          (ref) => Stream.value([
            item('1', 'London'),
            item('2', 'Accra'),
            item('3', null),
          ]),
        ),
      ]);

      expect(find.text('News 1'), findsOneWidget);
      expect(find.text('News 2'), findsNothing);
      expect(find.text('News 3'), findsNothing);
    });
  });

  group('branch page', () {
    testWidgets('a campus admin sees campus settings but not identity', (
      tester,
    ) async {
      final db = FakeFirebaseFirestore();
      await db.collection('branches').doc('london').set({
        'name': 'London',
        'contact': {'email': 'london@kharis.org'},
        'services': [
          {'id': 'sunday', 'name': 'Sunday Service', 'day': 'Sundays'},
        ],
      });
      await _pump(
        tester,
        const AdminBranchDetailScreen(branchId: 'london', branchName: 'London'),
        [
          ..._overrides(_campusAdmin, db: db),
          upcomingEventsProvider.overrideWith((ref, _) => Stream.value([])),
          adminNewsProvider.overrideWith((ref) => Stream.value([])),
        ],
      );

      expect(find.text('Group'), findsNothing);
      expect(find.text('london@kharis.org'), findsOneWidget);
      expect(find.text('Sunday Service'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('GIVING'), 100);
      expect(find.text('Uses the church-wide giving details.'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('HOME LAYOUT'), 100);
      expect(find.text('Uses the church-wide default.'), findsOneWidget);
    });

    testWidgets('another campus is refused', (tester) async {
      await _pump(
        tester,
        const AdminBranchDetailScreen(branchId: 'accra', branchName: 'Accra'),
        [
          ..._overrides(_campusAdmin, db: FakeFirebaseFirestore()),
          upcomingEventsProvider.overrideWith((ref, _) => Stream.value([])),
          adminNewsProvider.overrideWith((ref) => Stream.value([])),
        ],
      );
      expect(
        find.text('You can only manage your own branches.'),
        findsOneWidget,
      );
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
