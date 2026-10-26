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

/// Records topic changes instead of touching FCM; topics in [failing] fail.
class _RecordingTopics extends NotificationService {
  final calls = <String>[];
  final failing = <String>{};

  @override
  Future<bool> subscribeToTopic(String topic) async {
    calls.add('+$topic');
    return !failing.contains(topic);
  }

  @override
  Future<bool> unsubscribeFromTopic(String topic) async {
    calls.add('-$topic');
    return !failing.contains(topic);
  }
}

const _key = NotificationService.subscribedBranchTopicKey;

Future<String?> _stored() async =>
    (await SharedPreferences.getInstance()).getString(_key);

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('Announcements toggle drives the opt-out mute topic', () {
    test('OFF joins mute_announcements, ON leaves it', () async {
      final topics = _RecordingTopics();
      await topics.applyPreference('announcements', false);
      await topics.applyPreference('announcements', true);
      expect(topics.calls, ['+mute_announcements', '-mute_announcements']);
    });

    test('applied with the other preferences', () async {
      final topics = _RecordingTopics();
      await topics.applyPreferences({'announcements': true, 'events': false});
      expect(topics.calls, [
        '-daily_reading',
        '-mute_announcements',
        '-events',
      ]);
    });
  });

  group('branch topic is re-applied on launch', () {
    setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

    test('subscribes the current branch and remembers it', () async {
      final topics = _RecordingTopics();
      await topics.syncBranchTopic('Chatham');
      expect(topics.calls, ['+branch_chatham']);
      expect(await _stored(), 'branch_chatham');

      topics.calls.clear();
      await topics.syncBranchTopic('Chatham');
      expect(topics.calls, ['+branch_chatham']);
    });

    test('a branch switched while offline leaves the stored topic', () async {
      SharedPreferences.setMockInitialValues({_key: 'branch_chatham'});
      final topics = _RecordingTopics();
      await topics.syncBranchTopic('KP2 London');
      expect(topics.calls, ['-branch_chatham', '+branch_kp2-london']);
      expect(await _stored(), 'branch_kp2-london');
    });

    test('a renamed branch moves the device to the new topic', () async {
      final topics = _RecordingTopics();
      await topics.syncBranchTopic('Kharis Chatham');
      topics.calls.clear();

      await topics.syncBranchTopic('Kharis Medway');
      expect(topics.calls, ['-branch_kharis-chatham', '+branch_kharis-medway']);
      expect(await _stored(), 'branch_kharis-medway');
    });

    test('a failed leave keeps the old topic for the next launch', () async {
      SharedPreferences.setMockInitialValues({_key: 'branch_chatham'});
      final topics = _RecordingTopics()..failing.add('branch_chatham');
      await topics.syncBranchTopic('Medway');
      expect(await _stored(), 'branch_chatham');
    });

    test('a switch records the new topic', () async {
      final topics = _RecordingTopics();
      await topics.switchBranchTopic(from: 'Chatham', to: 'Medway');
      expect(topics.calls, ['-branch_chatham', '+branch_medway']);
      expect(await _stored(), 'branch_medway');
    });
  });

  testWidgets('settings shows the four switches with their subtitles', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    final topics = _RecordingTopics();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          notificationServiceProvider.overrideWithValue(topics),
          currentUserProvider.overrideWith((ref) => Stream.value(null)),
          currentBranchProvider.overrideWith((ref) => Stream.value('Chatham')),
          notificationPermissionProvider.overrideWith(
            (ref) async => NotificationPermission.granted,
          ),
        ],
        child: const MaterialApp(home: NotificationsSettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Switch), findsNWidgets(4));
    expect(find.text('Announcements'), findsOneWidget);
    expect(find.text('News and notices from your branch'), findsOneWidget);
    expect(
      find.text(
        'An hour before your branch\u2019s service, and when its time or '
        'place changes',
      ),
      findsOneWidget,
    );
    expect(find.text('Events'), findsOneWidget);
    expect(find.text('Daily reading'), findsOneWidget);
  });
}
