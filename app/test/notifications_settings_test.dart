import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kharis_app/core/services/notification_service.dart';
import 'package:kharis_app/features/settings/presentation/screens/notifications_settings_screen.dart';
import 'package:kharis_app/shared/providers/auth_provider.dart';
import 'package:kharis_app/shared/providers/branch_provider.dart';
import 'package:kharis_app/shared/providers/notification_provider.dart';
import 'package:kharis_app/shared/providers/onboarding_provider.dart';

/// Holds the OS permission sheet open until the test answers it.
class _PendingPrompt extends NotificationService {
  final answer = Completer<bool>();
  final grantedBranches = <String?>[];

  @override
  Future<bool> requestPermission() => answer.future;

  @override
  Future<void> onPermissionGranted({String? branch}) async {
    grantedBranches.add(branch);
  }
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('leaving the screen while the OS prompt is up neither throws '
      'nor skips the follow-up', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    final fcm = _PendingPrompt();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          notificationServiceProvider.overrideWithValue(fcm),
          currentUserProvider.overrideWith((ref) => Stream.value(null)),
          currentBranchProvider.overrideWith((ref) => Stream.value('Chatham')),
          notificationPrefsProvider.overrideWith(
            (ref) => Stream.value(const {
              'serviceReminders': true,
              'events': true,
              'dailyReading': true,
            }),
          ),
          notificationPermissionProvider.overrideWith((ref) async => false),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const NotificationsSettingsScreen(),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Allow notifications'));
    await tester.pump();
    // The member backs out while the system sheet is still showing.
    await tester.tap(find.byIcon(Icons.arrow_back_ios_new));
    await tester.pumpAndSettle();
    expect(find.byType(NotificationsSettingsScreen), findsNothing);

    fcm.answer.complete(true);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(fcm.grantedBranches, ['Chatham']);
  });
}
