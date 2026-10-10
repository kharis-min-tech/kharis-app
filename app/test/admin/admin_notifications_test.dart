import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:kharis_app/features/admin/presentation/screens/admin_notifications_screen.dart';
import 'package:kharis_app/features/home/data/studio_notification_repository.dart';
import 'package:kharis_app/features/onboarding/data/branch_repository.dart';
import 'package:kharis_app/shared/models/campus_config.dart';
import 'package:kharis_app/shared/models/user.dart';
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

const _branchAdmin = AdminScope.campus(
  branchIds: {'london'},
  branchNames: {'London'},
);

final _user = User(
  id: 'uid-1',
  email: 'pastor@kharis.org',
  displayName: 'Pastor Ade',
  role: 'campus_admin',
  createdAt: DateTime(2026),
);

Future<FakeFirebaseFirestore> _pump(
  WidgetTester tester,
  AdminScope scope,
) async {
  final db = FakeFirebaseFirestore();
  // Tall enough that the whole composer is on screen.
  tester.view.physicalSize = const Size(1200, 3200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        adminScopeProvider.overrideWith((ref) => Stream.value(scope)),
        branchesProvider.overrideWith(
          (ref) => Stream.value(const [_london, _leeds]),
        ),
        currentUserProvider.overrideWith((ref) => Stream.value(_user)),
        firestoreProvider.overrideWithValue(db),
      ],
      child: const MaterialApp(home: AdminNotificationsScreen()),
    ),
  );
  await tester.pumpAndSettle();
  return db;
}

Future<void> _fill(WidgetTester tester) async {
  await tester.enterText(
    find.byKey(const Key('notification-title')),
    'Friday prayer moves to 8pm',
  );
  await tester.enterText(
    find.byKey(const Key('notification-body')),
    'Friday prayer starts at 8pm this week.',
  );
  await tester.pump();
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('canManageNotificationAudience', () {
    test('super admin: every audience', () {
      const scope = AdminScope.superAdmin();
      for (final audience in const [
        NotificationAudience.all(),
        NotificationAudience.test(),
        NotificationAudience.branch('Leeds'),
      ]) {
        expect(canManageNotificationAudience(scope, audience), isTrue);
      }
    });

    test('branch admin: own branches and test devices, never everyone', () {
      expect(
        canManageNotificationAudience(
          _branchAdmin,
          const NotificationAudience.all(),
        ),
        isFalse,
      );
      expect(
        canManageNotificationAudience(
          _branchAdmin,
          const NotificationAudience.branch('Leeds'),
        ),
        isFalse,
      );
      expect(
        canManageNotificationAudience(
          _branchAdmin,
          const NotificationAudience.branch('London'),
        ),
        isTrue,
      );
      expect(
        canManageNotificationAudience(
          _branchAdmin,
          const NotificationAudience.test(),
        ),
        isTrue,
      );
      expect(
        canManageNotificationAudience(
          const AdminScope.none(),
          const NotificationAudience.test(),
        ),
        isFalse,
      );
    });
  });

  testWidgets('empty title and message are refused; nothing is written', (
    tester,
  ) async {
    final db = await _pump(tester, const AdminScope.superAdmin());
    await tester.tap(find.text('Send now'));
    await tester.pumpAndSettle();
    expect(find.text('Add a title'), findsOneWidget);
    expect(find.text('Add a message'), findsOneWidget);
    expect((await db.collection('notifications').get()).docs, isEmpty);
  });

  testWidgets('title and message stop at 65 and 240 characters', (
    tester,
  ) async {
    await _pump(tester, const AdminScope.superAdmin());
    await tester.enterText(
      find.byKey(const Key('notification-title')),
      'x' * 80,
    );
    await tester.enterText(
      find.byKey(const Key('notification-body')),
      'y' * 300,
    );
    await tester.pump();
    expect(find.text('65/65'), findsOneWidget);
    expect(find.text('240/240'), findsOneWidget);
  });

  testWidgets('a web link must be https', (tester) async {
    await _pump(tester, const AdminScope.superAdmin());
    await _fill(tester);
    await tester.tap(find.byKey(const Key('notification-link-kind')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('A web address').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('notification-web-url')),
      'javascript:alert(1)',
    );
    await tester.tap(find.text('Send now'));
    await tester.pumpAndSettle();
    expect(
      find.text('Use a web address starting with https://'),
      findsOneWidget,
    );
  });

  testWidgets('branch admin is not offered Everyone, only their branches', (
    tester,
  ) async {
    await _pump(tester, _branchAdmin);
    expect(find.widgetWithText(ChoiceChip, 'Everyone'), findsNothing);
    expect(find.widgetWithText(ChoiceChip, 'One branch'), findsOneWidget);
    expect(
      find.widgetWithText(ChoiceChip, 'Staff test devices'),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(ChoiceChip, 'One branch'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('notification-branch')));
    await tester.pumpAndSettle();
    expect(find.text('London'), findsWidgets);
    expect(find.text('Leeds'), findsNothing);
  });

  testWidgets('super admin is offered Everyone', (tester) async {
    await _pump(tester, const AdminScope.superAdmin());
    expect(find.widgetWithText(ChoiceChip, 'Everyone'), findsOneWidget);
  });

  testWidgets('branch admin sends to their branch: one scheduled doc', (
    tester,
  ) async {
    final db = await _pump(tester, _branchAdmin);
    await _fill(tester);
    await tester.tap(find.widgetWithText(ChoiceChip, 'One branch'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('notification-branch')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('London').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send now'));
    await tester.pumpAndSettle();

    final docs = (await db.collection('notifications').get()).docs;
    expect(docs, hasLength(1));
    final data = docs.single.data();
    expect(data['title'], 'Friday prayer moves to 8pm');
    expect(data['audience'], {'type': 'branch', 'branch': 'London'});
    expect(data['status'], 'scheduled');
    expect(data['createdBy'], 'uid-1');
    expect(data['createdByName'], 'Pastor Ade');
    expect(data.containsKey('link'), isFalse);
    // The form resets for the next one, and the history lists this one.
    final title = tester.widget<TextFormField>(
      find.byKey(const Key('notification-title')),
    );
    expect(title.controller!.text, isEmpty);
    expect(find.text('Friday prayer moves to 8pm'), findsOneWidget);
    expect(find.textContaining('London · Scheduled'), findsOneWidget);
  });

  testWidgets('sending to Everyone asks first; Cancel writes nothing', (
    tester,
  ) async {
    final db = await _pump(tester, const AdminScope.superAdmin());
    await _fill(tester);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Everyone'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send now'));
    await tester.pumpAndSettle();
    expect(find.text('Send to everyone?'), findsOneWidget);
    await tester.tap(find.text('Cancel').last);
    await tester.pumpAndSettle();
    expect((await db.collection('notifications').get()).docs, isEmpty);

    await tester.tap(find.text('Send now'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send to everyone'));
    await tester.pumpAndSettle();
    final docs = (await db.collection('notifications').get()).docs;
    expect(docs.single.data()['audience'], {'type': 'all'});
  });
}
