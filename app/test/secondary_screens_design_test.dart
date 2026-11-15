// Layout checks for Give, the notification list, the announcements list and
// detail, notification settings, the Branch page and branch card, Edit
// profile and the delete-account dialogs: each is built at the 390 design
// width in light and dark at 100% and 130% text size and must lay out with
// no overflow or error.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kharis_app/core/services/notification_service.dart';
import 'package:kharis_app/features/calendar/data/event_repository.dart';
import 'package:kharis_app/features/giving/presentation/screens/giving_screen.dart';
import 'package:kharis_app/features/home/data/news_repository.dart';
import 'package:kharis_app/features/home/presentation/screens/branch_screen.dart';
import 'package:kharis_app/features/home/presentation/screens/notifications_screen.dart';
import 'package:kharis_app/features/home/presentation/widgets/announcement_detail.dart';
import 'package:kharis_app/features/home/presentation/widgets/campus_card.dart';
import 'package:kharis_app/features/onboarding/data/branch_repository.dart';
import 'package:kharis_app/features/settings/presentation/screens/edit_profile_screen.dart';
import 'package:kharis_app/features/settings/presentation/screens/notifications_settings_screen.dart';
import 'package:kharis_app/features/settings/presentation/widgets/delete_account_flow.dart';
import 'package:kharis_app/shared/models/campus_config.dart';
import 'package:kharis_app/shared/models/user.dart';
import 'package:kharis_app/shared/providers/admin_provider.dart';
import 'package:kharis_app/shared/providers/auth_provider.dart';
import 'package:kharis_app/shared/providers/notification_provider.dart';
import 'package:kharis_app/shared/providers/onboarding_provider.dart';
import 'package:kharis_app/shared/providers/sermon_provider.dart';
import 'package:kharis_app/ui/components/components.dart';

import 'support/design_harness.dart';

const _phone = Size(KSize.designWidth, 844);

const _london = Branch(
  id: 'london',
  name: 'Kharis London',
  subtitle: 'England · Headquarters',
  contact: CampusContact(
    phone: '020 7000 0000',
    email: 'london@kharis.org',
    instagram: '@kharislondon',
  ),
  venues: [
    CampusVenue(
      id: 'lighthouse',
      name: 'The Lighthouse Theatre',
      addressLine1: '262–274 Camberwell Road',
      city: 'London',
      postcode: 'SE5 0AY',
      parkingInfo: 'Street parking on Camberwell Road is free on Sundays.',
      publicTransportInfo: 'Buses 12, 35, 40 and 171 stop outside.',
    ),
  ],
  services: [
    CampusService(
      id: 'sun',
      name: 'Sunday Service',
      day: 'Sundays',
      startTime: '10:00',
      endTime: '12:00',
      venueId: 'lighthouse',
    ),
    CampusService(
      id: 'mid',
      name: 'Midweek Service',
      day: 'Wednesdays',
      startTime: '19:00',
      venueId: 'lighthouse',
    ),
  ],
);

final _member = User(
  id: 'uid-1',
  email: 'member@kharis.org',
  displayName: 'Esther Mensah',
  role: 'member',
  branch: 'Kharis London',
  createdAt: DateTime(2024),
);

final _news = [
  NewsItem(
    id: 'n1',
    title: 'Baptism Sunday',
    type: 'Announcement',
    publishedAt: DateTime(2026, 11, 14, 9),
    body:
        'Ready to be baptised? Speak to the pastoral team by Sunday 15 '
        'November. Classes run on Wednesday evenings before the service.',
    linkUrl: 'https://kharis.org/baptism',
    ctaLabel: 'Register interest',
  ),
  NewsItem(
    id: 'n2',
    title: 'Carols at The Lighthouse, with the whole church family',
    type: 'Announcement',
    publishedAt: DateTime(2026, 11, 14, 8),
  ),
  NewsItem(
    id: 'n3',
    title: 'Car park closed',
    type: 'Notice',
    publishedAt: DateTime(2026, 11, 2),
    body: 'Please use street parking this week.',
  ),
];

final _events = [
  Event(
    id: 'e1',
    title: 'Prayer Night',
    description: 'An evening of corporate prayer. All welcome.',
    location: 'Main Hall, London',
    branch: 'Kharis London',
    startTime: DateTime(2026, 11, 20, 19),
  ),
];

class _QuietNotifications extends NotificationService {
  @override
  Future<void> applyPreference(String key, bool enabled) async {}
}

Future<void> _pumpScreen(
  WidgetTester tester,
  Widget home, {
  required bool dark,
  required double textScale,
  User? user,
  List<NewsItem> news = const [],
  List<Event> events = const [],
  NotificationPermission permission = NotificationPermission.granted,
}) async {
  tester.view.physicalSize = _phone;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({
    'onboarding_branch': 'Kharis London',
  });
  final prefs = await SharedPreferences.getInstance();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        branchesProvider.overrideWith((ref) => Stream.value(const [_london])),
        currentUserProvider.overrideWith((ref) => Stream.value(user)),
        notificationServiceProvider.overrideWithValue(_QuietNotifications()),
        notificationPermissionProvider.overrideWith((ref) async => permission),
        notificationPrefsProvider.overrideWith(
          (ref) => Stream.value(const {'events': false}),
        ),
        newsProvider.overrideWith((ref, branch) async => news),
        upcomingEventsProvider.overrideWith(
          (ref, branch) => Stream.value(events),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: KharisTheme.light(),
        darkTheme: KharisTheme.dark(),
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        builder: (context, app) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
            disableAnimations: true,
          ),
          child: app!,
        ),
        home: home,
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void _forEachMode(
  String name,
  Future<void> Function(WidgetTester tester, bool dark, double scale) body,
) {
  for (final dark in const [false, true]) {
    for (final scale in const [1.0, 1.3, 2.0]) {
      testWidgets(
        '$name · ${dark ? 'dark' : 'light'} · ${(scale * 100).round()}%',
        (tester) async {
          await body(tester, dark, scale);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}

Finder get _primaryButtons => find.byWidgetPredicate(
  (w) => w is KButton && w.variant == KButtonVariant.primary,
);

void main() {
  setUpAll(loadDesignAssets);
  group('delete account dialogs', dialogBehaviour);

  _forEachMode('give', (tester, dark, scale) async {
    await _pumpScreen(
      tester,
      const GivingScreen(),
      dark: dark,
      textScale: scale,
    );
    expect(find.text('Give'), findsOneWidget);
    expect(
      find.text('To Kharis London. Thank you for giving.'),
      findsOneWidget,
    );
    expect(find.text('Give to Kharis London'), findsOneWidget);
    expect(_primaryButtons, findsOneWidget);
    expect(find.text('Copy bank details'), findsOneWidget);
  });

  _forEachMode('notifications, with reminders and news', (
    tester,
    dark,
    scale,
  ) async {
    await _pumpScreen(
      tester,
      const NotificationsScreen(),
      dark: dark,
      textScale: scale,
      news: _news,
      events: _events,
    );
    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('Prayer Night'), findsOneWidget);
    expect(find.text('Baptism Sunday'), findsOneWidget);
    expect(find.text('Clear all'), findsOneWidget);
    // Rows sit in one group per day: two announcements share 14 November.
    expect(find.byType(KListGroup), findsNWidgets(3));
  });

  _forEachMode('notifications, empty and not yet allowed', (
    tester,
    dark,
    scale,
  ) async {
    await _pumpScreen(
      tester,
      const NotificationsScreen(),
      dark: dark,
      textScale: scale,
      permission: NotificationPermission.askable,
    );
    expect(find.text('No notifications yet'), findsOneWidget);
    expect(
      find.byKey(const Key('notification-permission-card')),
      findsOneWidget,
    );
  });

  _forEachMode('announcements list', (tester, dark, scale) async {
    await _pumpScreen(
      tester,
      const NotificationsScreen.announcements(),
      dark: dark,
      textScale: scale,
      news: _news,
    );
    expect(find.text('Announcements'), findsOneWidget);
    expect(find.byType(KAnnouncementCard), findsNWidgets(3));
    expect(find.text('Clear all'), findsNothing);
  });

  _forEachMode('announcement detail', (tester, dark, scale) async {
    await _pumpScreen(
      tester,
      const NotificationsScreen.announcements(),
      dark: dark,
      textScale: scale,
      news: _news,
    );
    await tester.tap(find.text('Baptism Sunday'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(AnnouncementDetailSheet), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('announcement-cta')),
        matching: find.text('Register interest'),
      ),
      findsOneWidget,
    );
  });

  _forEachMode('notification settings', (tester, dark, scale) async {
    await _pumpScreen(
      tester,
      const NotificationsSettingsScreen(),
      dark: dark,
      textScale: scale,
      permission: NotificationPermission.blocked,
    );
    expect(find.byType(KSwitch), findsNWidgets(4));
    expect(
      find.byKey(const Key('notification-permission-card')),
      findsOneWidget,
    );
  });

  _forEachMode('branch page', (tester, dark, scale) async {
    await _pumpScreen(
      tester,
      const BranchScreen(),
      dark: dark,
      textScale: scale,
    );
    expect(find.text('Kharis London'), findsOneWidget);
    expect(find.text('Directions'), findsOneWidget);
    expect(find.byKey(const Key('home-branch-change')), findsOneWidget);
    expect(find.byKey(const Key('campus-service-sun')), findsOneWidget);
    expect(find.byKey(const Key('campus-service-mid')), findsOneWidget);
  });

  _forEachMode('branch card, full and summary', (tester, dark, scale) async {
    await _pumpScreen(
      tester,
      const Scaffold(
        body: SingleChildScrollView(
          padding: EdgeInsets.all(KSpace.gutter),
          child: Column(
            children: [
              CampusCard(),
              SizedBox(height: KSpace.gutter),
              CampusCard(key: Key('summary'), summary: true),
            ],
          ),
        ),
      ),
      dark: dark,
      textScale: scale,
    );
    expect(find.text('Kharis London'), findsNWidgets(2));
    expect(find.text('Directions'), findsNWidgets(2));
    expect(find.text('Change branch'), findsNWidgets(2));
    // Contacts are on the full card only.
    expect(find.byKey(const Key('campus-call')), findsOneWidget);
  });

  _forEachMode('edit profile', (tester, dark, scale) async {
    await _pumpScreen(
      tester,
      const EditProfileScreen(),
      dark: dark,
      textScale: scale,
      user: _member,
    );
    expect(find.text('Edit profile'), findsOneWidget);
    expect(find.text('Display name'), findsOneWidget);
    expect(find.text('Save changes'), findsOneWidget);
    expect(_primaryButtons, findsOneWidget);
  });

  _forEachMode('edit profile, guest', (tester, dark, scale) async {
    await _pumpScreen(
      tester,
      const EditProfileScreen(),
      dark: dark,
      textScale: scale,
    );
    expect(find.text('Sign in to edit your profile'), findsOneWidget);
    expect(_primaryButtons, findsOneWidget);
  });

  _forEachMode('delete account dialog', (tester, dark, scale) async {
    await _pumpScreen(
      tester,
      const Scaffold(body: DeleteAccountDialog(requirePassword: true)),
      dark: dark,
      textScale: scale,
    );
    expect(find.text('Delete account?'), findsOneWidget);
    expect(find.byType(KDestructiveButton), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
  });

  _forEachMode('confirm password dialog', (tester, dark, scale) async {
    await _pumpScreen(
      tester,
      const Scaffold(body: ConfirmPasswordDialog()),
      dark: dark,
      textScale: scale,
    );
    expect(find.text('Confirm your password'), findsOneWidget);
    expect(find.byType(KDestructiveButton), findsOneWidget);
  });
}

/// Opens [dialog] from a button and records what it pops.
Future<List<String?>> _openDialog(WidgetTester tester, Widget dialog) async {
  final results = <String?>[];
  await tester.pumpWidget(
    MaterialApp(
      theme: KharisTheme.light(),
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async => results.add(
            await showDialog<String>(context: context, builder: (_) => dialog),
          ),
          child: const Text('open'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return results;
}

void dialogBehaviour() {
  final confirm = find.widgetWithText(TextButton, 'Delete account');

  testWidgets('delete account: confirm waits for the password, then pops it', (
    tester,
  ) async {
    final results = await _openDialog(
      tester,
      const DeleteAccountDialog(requirePassword: true),
    );
    expect(tester.widget<TextButton>(confirm).onPressed, isNull);

    await tester.enterText(
      find.byKey(const ValueKey('delete-account-password')),
      'hunter2',
    );
    await tester.pump();
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    expect(results, ['hunter2']);
  });

  testWidgets('delete account: Cancel pops nothing', (tester) async {
    final results = await _openDialog(
      tester,
      const DeleteAccountDialog(requirePassword: false),
    );
    // No password needed: confirm is live straight away.
    expect(tester.widget<TextButton>(confirm).onPressed, isNotNull);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(results, [null]);
  });

  testWidgets('confirm password: pops the re-entered password', (tester) async {
    final results = await _openDialog(tester, const ConfirmPasswordDialog());
    expect(tester.widget<TextButton>(confirm).onPressed, isNull);
    await tester.enterText(
      find.byKey(const ValueKey('confirm-password')),
      'again',
    );
    await tester.pump();
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    expect(results, ['again']);
  });
}
