import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kharis_app/core/services/notification_service.dart';
import 'package:kharis_app/features/calendar/data/event_repository.dart';
import 'package:kharis_app/features/home/data/news_repository.dart';
import 'package:kharis_app/features/home/presentation/screens/notifications_screen.dart';
import 'package:kharis_app/features/settings/presentation/screens/notifications_settings_screen.dart';
import 'package:kharis_app/shared/providers/auth_provider.dart';
import 'package:kharis_app/shared/providers/branch_provider.dart';
import 'package:kharis_app/shared/providers/notification_provider.dart';
import 'package:kharis_app/shared/providers/onboarding_provider.dart';
import 'package:kharis_app/shared/providers/sermon_provider.dart';

/// Tester feedback: "No notification prompt to allow notifications when I
/// click it and it doesn't even tell me what I can select."
///
/// The inbox (Home bell) and Notification settings must say notifications are
/// off, what they would bring, turn them on (OS prompt, or system settings
/// once the OS won't ask), link to the preferences, and respect "Not now".

/// Stands in for FCM: the OS answers with [grant], and a grant flips [status]
/// the way the real authorization status would.
class _FakeNotifications extends NotificationService {
  _FakeNotifications(this.status, {this.grant = false});

  NotificationPermission status;
  final bool grant;
  int requests = 0;
  int settingsOpened = 0;

  @override
  Future<bool> requestPermission() async {
    requests++;
    if (grant) status = NotificationPermission.granted;
    return grant;
  }

  @override
  Future<bool> openSystemSettings() async {
    settingsOpened++;
    return true;
  }

  @override
  Future<void> onPermissionGranted({String? branch}) async {}

  @override
  Future<void> applyPreference(String key, bool enabled) async {}
}

final _card = find.byKey(const Key('notification-permission-card'));

Future<List<Override>> _overrides(
  _FakeNotifications fcm, {
  Map<String, Object> stored = const {},
}) async {
  SharedPreferences.setMockInitialValues(stored);
  final prefs = await SharedPreferences.getInstance();
  return [
    sharedPreferencesProvider.overrideWithValue(prefs),
    notificationServiceProvider.overrideWithValue(fcm),
    notificationPermissionProvider.overrideWith((ref) async => fcm.status),
    currentUserProvider.overrideWith((ref) => Stream.value(null)),
    currentBranchProvider.overrideWith((ref) => Stream.value('Chatham')),
    notificationPrefsProvider.overrideWith(
      (ref) => Stream.value(const {
        'serviceReminders': true,
        'events': true,
        'dailyReading': true,
      }),
    ),
    newsProvider.overrideWith((ref, branch) async => const <NewsItem>[]),
    upcomingEventsProvider.overrideWith(
      (ref, branch) => Stream.value(const <Event>[]),
    ),
  ];
}

Future<void> _pumpInbox(
  WidgetTester tester,
  _FakeNotifications fcm, {
  Map<String, Object> stored = const {},
}) async {
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => const NotificationsScreen()),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: await _overrides(fcm, stored: stored),
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('notifications inbox', () {
    testWidgets('not yet allowed: says what the member would get and the OS '
        'prompt turns notifications on', (tester) async {
      final fcm = _FakeNotifications(
        NotificationPermission.askable,
        grant: true,
      );
      await _pumpInbox(tester, fcm);

      expect(_card, findsOneWidget);
      expect(find.text('Notifications are off'), findsOneWidget);
      expect(
        find.textContaining('the daily Bible reading and church announcements'),
        findsOneWidget,
      );
      // The empty feed still reads as before, under the card.
      expect(find.text('No notifications yet'), findsOneWidget);

      await tester.tap(find.text('Turn on notifications'));
      await tester.pumpAndSettle();

      expect(fcm.requests, 1);
      expect(fcm.settingsOpened, 0);
      expect(_card, findsNothing);
    });

    testWidgets('a refused prompt offers system settings once, and the card '
        'stays', (tester) async {
      final fcm = _FakeNotifications(NotificationPermission.askable);
      await _pumpInbox(tester, fcm);

      await tester.tap(find.text('Turn on notifications'));
      await tester.pumpAndSettle();

      expect(fcm.requests, 1);
      expect(find.text('Notifications are still off.'), findsOneWidget);
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      expect(fcm.settingsOpened, 1);
      expect(_card, findsOneWidget);
    });

    testWidgets('refused before (iOS): goes to system settings without '
        're-asking, and coming back allowed hides the card', (tester) async {
      final fcm = _FakeNotifications(NotificationPermission.blocked);
      await _pumpInbox(tester, fcm);

      await tester.tap(find.text('Turn on in Settings'));
      await tester.pumpAndSettle();
      expect(fcm.settingsOpened, 1);
      expect(fcm.requests, 0);

      // The member allows notifications in Settings and comes back.
      fcm.status = NotificationPermission.granted;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(_card, findsNothing);
    });

    for (final status in [
      NotificationPermission.granted,
      NotificationPermission.unavailable,
    ]) {
      testWidgets('${status.name}: no card, preferences still one tap away', (
        tester,
      ) async {
        final fcm = _FakeNotifications(status);
        await _pumpInbox(tester, fcm);

        expect(_card, findsNothing);
        await tester.tap(find.byTooltip('Notification settings'));
        await tester.pumpAndSettle();
        expect(find.byType(NotificationsSettingsScreen), findsOneWidget);
        expect(find.text('Service reminders'), findsOneWidget);
        expect(find.text('Events'), findsOneWidget);
        expect(find.text('Daily reading'), findsOneWidget);
      });
    }

    testWidgets('"Choose what you get" lists the preferences', (tester) async {
      final fcm = _FakeNotifications(NotificationPermission.askable);
      await _pumpInbox(tester, fcm);

      await tester.tap(find.text('Choose what you get'));
      await tester.pumpAndSettle();
      expect(find.byType(NotificationsSettingsScreen), findsOneWidget);
      expect(find.text('Service reminders'), findsOneWidget);
      expect(fcm.requests, 0);
    });

    testWidgets('"Not now" hides the card for good without asking', (
      tester,
    ) async {
      final fcm = _FakeNotifications(NotificationPermission.askable);
      await _pumpInbox(tester, fcm);

      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();
      expect(_card, findsNothing);
      expect(fcm.requests, 0);

      final prefs = await SharedPreferences.getInstance();
      final stored = {for (final key in prefs.getKeys()) key: prefs.get(key)!};
      // A later visit (fresh app state, same device) does not ask again.
      await tester.pumpWidget(const SizedBox());
      await _pumpInbox(tester, fcm, stored: stored);
      expect(_card, findsNothing);
      expect(find.byTooltip('Notification settings'), findsOneWidget);
    });
  });

  group('Notification settings', () {
    Future<void> pumpSettings(
      WidgetTester tester,
      _FakeNotifications fcm,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: await _overrides(fcm),
          child: const MaterialApp(home: NotificationsSettingsScreen()),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('blocked: the notice sends the member to system settings', (
      tester,
    ) async {
      final fcm = _FakeNotifications(NotificationPermission.blocked);
      await pumpSettings(tester, fcm);

      expect(_card, findsOneWidget);
      // Already on the preferences: no link to them, and no "Not now".
      expect(find.text('Choose what you get'), findsNothing);
      expect(find.text('Not now'), findsNothing);
      await tester.tap(find.text('Turn on in Settings'));
      await tester.pumpAndSettle();
      expect(fcm.settingsOpened, 1);
      expect(fcm.requests, 0);
    });

    testWidgets('granted: no notice', (tester) async {
      await pumpSettings(
        tester,
        _FakeNotifications(NotificationPermission.granted),
      );
      expect(_card, findsNothing);
      expect(find.text('Service reminders'), findsOneWidget);
    });
  });

  test('OS status maps to the member\u2019s next step per platform', () {
    for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
      expect(
        notificationPermissionFor(AuthorizationStatus.authorized, platform),
        NotificationPermission.granted,
      );
      expect(
        notificationPermissionFor(AuthorizationStatus.provisional, platform),
        NotificationPermission.granted,
      );
      expect(
        notificationPermissionFor(AuthorizationStatus.notDetermined, platform),
        NotificationPermission.askable,
      );
    }
    // iOS shows its sheet once; Android says "denied" until granted and
    // decides itself whether to show its dialog again.
    expect(
      notificationPermissionFor(AuthorizationStatus.denied, TargetPlatform.iOS),
      NotificationPermission.blocked,
    );
    expect(
      notificationPermissionFor(
        AuthorizationStatus.denied,
        TargetPlatform.android,
      ),
      NotificationPermission.askable,
    );
  });
}
