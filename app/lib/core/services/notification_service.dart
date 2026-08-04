import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'firebase_service.dart';

/// Messenger used to surface foreground pushes as in-app banners.
///
/// Wired into `MaterialApp.router` in `main.dart`; FCM draws nothing itself
/// while the app is in the foreground, so this is the only place a foreground
/// push becomes visible.
final GlobalKey<ScaffoldMessengerState> kharisMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

/// Top-level background message handler — must be a top-level function.
@pragma('vm:entry-point')
Future<void> firebaseBackgroundMessageHandler(RemoteMessage message) async {
  debugPrint('[FCM] Background: ${message.notification?.title}');
}

/// Kharis topic constants.
class KharisTopics {
  KharisTopics._();

  /// Mandatory topic — carries global (unscoped) announcements.
  static const String all = 'all';

  // Preference-controlled topics. Keys mirror `notificationPrefsProvider`.
  static const String serviceReminders = 'service_reminders';
  static const String events = 'events';
  static const String dailyReading = 'daily_reading';
  static const String newSermons = 'new_sermons';

  /// Maps a `notificationPrefsProvider` key to the topic it gates.
  static const Map<String, String> byPreference = <String, String>{
    'serviceReminders': serviceReminders,
    'events': events,
    'dailyReading': dailyReading,
    'newSermons': newSermons,
  };

  /// Branch-scoped topic for a raw branch name (e.g. `KP2 London`).
  ///
  /// The slug MUST stay character-identical to the backend's in
  /// `backend/functions/src/index.ts` (`pushPendingAnnouncements`), which is
  /// the only other implementation of it.
  static String branch(String name) => 'branch_${slugifyBranch(name)}';

  /// Branch name -> FCM topic suffix. Single source of truth on the client.
  static String slugifyBranch(String name) =>
      name.toLowerCase().trim().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
}

class NotificationService {
  NotificationService({this.router});

  final GoRouter? router;

  Future<void> init() async {
    if (!kUseFirebase) return;
    try {
      final messaging = FirebaseMessaging.instance;

      await requestPermission();

      // Print token for testing / admin console.
      final token = await messaging.getToken();
      debugPrint('[FCM] Token: $token');

      // Register background handler.
      FirebaseMessaging.onBackgroundMessage(firebaseBackgroundMessageHandler);

      // Foreground messages.
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Tap while app is in background (not terminated).
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

      // Tap that launched the app from terminated state.
      final initial = await messaging.getInitialMessage();
      if (initial != null) {
        _handleNotificationTap(initial);
      }

      // Global announcements are not opt-out; the preference-gated topics are
      // applied by `notificationTopicSyncProvider`.
      await subscribeToTopic(KharisTopics.all);
    } catch (e) {
      debugPrint('[FCM] init error: $e');
    }
  }

  /// Asks the OS for notification permission and reports whether it is granted.
  ///
  /// Safe to call again: iOS only ever shows the sheet once per install, so a
  /// `false` there means the user has to enable it in system settings, while
  /// Android 13+ re-prompts until the user picks "don't ask again".
  Future<bool> requestPermission() async {
    if (!kUseFirebase) return false;
    try {
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        announcement: false,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
      );
      return settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
    } catch (e) {
      debugPrint('[FCM] requestPermission error: $e');
      return false;
    }
  }

  /// Applies the whole notification-preference map to this device's topics.
  ///
  /// Unknown keys are ignored, so adding a preference without a topic is safe.
  Future<void> applyPreferences(Map<String, bool> prefs) async {
    for (final entry in KharisTopics.byPreference.entries) {
      final enabled = prefs[entry.key];
      if (enabled == null) continue;
      await _setTopic(entry.value, enabled);
    }
  }

  /// Applies a single preference toggle. No-op for keys without a topic.
  Future<void> applyPreference(String key, bool enabled) async {
    final topic = KharisTopics.byPreference[key];
    if (topic == null) return;
    await _setTopic(topic, enabled);
  }

  /// Moves this device from one branch topic to another.
  ///
  /// The single code path used by both Switch Branch and Edit Profile. Pass
  /// `null`/empty for [from] on first selection; a no-change call is a no-op.
  ///
  /// Topics are keyed on the slugged branch NAME, so renaming a branch in
  /// Firestore orphans everyone already subscribed under the old name: they
  /// keep the stale topic until they re-select the branch, and pushes for the
  /// new name reach nobody. Rename a branch only alongside a re-subscribe.
  Future<void> switchBranchTopic({String? from, String? to}) async {
    final previous = (from ?? '').trim();
    final next = (to ?? '').trim();
    if (previous == next) return;
    if (previous.isNotEmpty) {
      await unsubscribeFromTopic(KharisTopics.branch(previous));
    }
    if (next.isNotEmpty) {
      await subscribeToTopic(KharisTopics.branch(next));
    }
  }

  Future<void> _setTopic(String topic, bool enabled) =>
      enabled ? subscribeToTopic(topic) : unsubscribeFromTopic(topic);

  void _handleForegroundMessage(RemoteMessage message) {
    final title = message.notification?.title;
    final body = message.notification?.body;
    debugPrint('[FCM] Foreground: $title — $body');
    // FCM draws nothing while the app is foregrounded, so surface it in-app.
    final text =
        [title, body].whereType<String>().where((s) => s.isNotEmpty).join(' — ');
    if (text.isEmpty) return;
    kharisMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(text),
        duration: const Duration(seconds: 6),
        action: SnackBarAction(
          label: 'View',
          onPressed: () => _handleNotificationTap(message),
        ),
      ),
    );
  }

  /// Routes a tapped push to the screen that shows what it is about.
  ///
  /// `message.data['type']` is the contract with the backend: every push sent
  /// from `backend/functions/src/content-notifications.ts` and
  /// `pushPendingAnnouncements` carries one of the types cased below. Adding a
  /// type server-side without a case here drops the member on `/home` with no
  /// sign of what they tapped, so the two move together.
  void _handleNotificationTap(RemoteMessage message) {
    debugPrint('[FCM] Tapped: ${message.notification?.title}');
    final type = message.data['type'] as String?;

    switch (type) {
      case 'announcement':
      case 'news':
        router?.go('/notifications');
      case 'sermon':
      case KharisTopics.newSermons:
        router?.go('/messages');
      case 'event':
      case KharisTopics.events:
      case KharisTopics.serviceReminders:
        router?.go('/calendar');
      case 'venue':
        // Branch address and service times are read off the home screen's
        // campus card — the only member-facing surface for them.
        router?.go('/home');
      case 'reading':
      case KharisTopics.dailyReading:
        router?.go('/reading');
      default:
        router?.go('/home');
    }
  }

  /// Subscribe to an FCM topic.
  ///
  /// Built-in topics: [KharisTopics.all], [KharisTopics.newSermons],
  /// [KharisTopics.events], [KharisTopics.dailyReading],
  /// [KharisTopics.serviceReminders]. Branch topics: [KharisTopics.branch].
  Future<void> subscribeToTopic(String topic) async {
    if (!kUseFirebase) return;
    try {
      await FirebaseMessaging.instance.subscribeToTopic(topic);
      debugPrint('[FCM] Subscribed to $topic');
    } catch (e) {
      debugPrint('[FCM] subscribeToTopic($topic) error: $e');
    }
  }

  Future<void> unsubscribeFromTopic(String topic) async {
    if (!kUseFirebase) return;
    try {
      await FirebaseMessaging.instance.unsubscribeFromTopic(topic);
      debugPrint('[FCM] Unsubscribed from $topic');
    } catch (e) {
      debugPrint('[FCM] unsubscribeFromTopic($topic) error: $e');
    }
  }
}
