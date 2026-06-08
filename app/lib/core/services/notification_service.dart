import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import 'firebase_service.dart';

/// Top-level background message handler — must be a top-level function.
@pragma('vm:entry-point')
Future<void> firebaseBackgroundMessageHandler(RemoteMessage message) async {
  debugPrint('[FCM] Background: ${message.notification?.title}');
}

/// Kharis topic constants.
class KharisTopics {
  KharisTopics._();

  static const String all = 'all';
  static const String newSermons = 'new_sermons';
  static const String events = 'events';
  static const String dailyReading = 'daily_reading';

  // Branch topics
  static const String branchLondon = 'branch_london';
  static const String branchBirmingham = 'branch_birmingham';

  static String branch(String name) => 'branch_$name';
}

class NotificationService {
  NotificationService({this.router});

  final GoRouter? router;

  Future<void> init() async {
    if (!kUseFirebase) return;
    try {
      final messaging = FirebaseMessaging.instance;

      // Request permission (iOS / web; Android 13+ also honours this).
      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        announcement: false,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
      );

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

      // Subscribe to default topics for all users.
      await subscribeToTopic(KharisTopics.all);
      await subscribeToTopic(KharisTopics.newSermons);
    } catch (e) {
      debugPrint('[FCM] init error: $e');
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint(
        '[FCM] Foreground: ${message.notification?.title} — ${message.notification?.body}');
    // TODO: show an in-app snackbar/banner if desired.
  }

  void _handleNotificationTap(RemoteMessage message) {
    debugPrint('[FCM] Tapped: ${message.notification?.title}');
    final type = message.data['type'] as String?;

    switch (type) {
      case 'sermon':
      case KharisTopics.newSermons:
        router?.go('/messages');
      case 'event':
      case KharisTopics.events:
        router?.go('/calendar');
      default:
        router?.go('/home');
    }
  }

  /// Subscribe to an FCM topic.
  ///
  /// Built-in topics: [KharisTopics.all], [KharisTopics.newSermons],
  /// [KharisTopics.events], [KharisTopics.dailyReading].
  /// Branch topics: [KharisTopics.branch].
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
