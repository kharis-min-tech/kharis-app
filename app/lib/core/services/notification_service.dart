import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
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
  // Every topic here has a publisher in `backend/functions/src`: events are
  // sent under `'events' in topics && '<branch topic>' in topics`, service
  // reminders under `'service_reminders' in topics && ...`, and the daily
  // reading straight to `daily_reading`.
  static const String serviceReminders = 'service_reminders';
  static const String events = 'events';
  static const String dailyReading = 'daily_reading';

  /// Maps a `notificationPrefsProvider` key to the topic it gates.
  static const Map<String, String> byPreference = <String, String>{
    'serviceReminders': serviceReminders,
    'events': events,
    'dailyReading': dailyReading,
  };

  /// Branch-scoped topic for a raw branch name (e.g. `KP2 London`).
  ///
  /// Rule for members on "All campuses" (no branch): the app SHOWS every
  /// campus's announcements and events, but the device follows no branch
  /// topic, so it is only PUSHED church-wide items (`all`, all-campus
  /// events). Subscribing them to every campus would send them each campus's
  /// service reminder every Sunday. A member who wants a campus's pushes
  /// picks that campus.
  ///
  /// The slug MUST stay character-identical to the backend's in
  /// `backend/functions/src/index.ts` (`pushPendingAnnouncements`), which is
  /// the only other implementation of it.
  static String branch(String name) => 'branch_${slugifyBranch(name)}';

  /// Branch name -> FCM topic suffix. Single source of truth on the client.
  static String slugifyBranch(String name) =>
      name.toLowerCase().trim().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
}

/// Where a tapped push takes the member.
@immutable
class NotificationTarget {
  const NotificationTarget(this.location, {this.overlay = false});

  /// go_router location.
  final String location;

  /// Overlay routes (detail screens, the reader, the feeds) are pushed on top
  /// of `/home` so their back button always has somewhere to return to. Tab
  /// roots are simply switched to.
  final bool overlay;

  @override
  bool operator ==(Object other) =>
      other is NotificationTarget &&
      other.location == location &&
      other.overlay == overlay;

  @override
  int get hashCode => Object.hash(location, overlay);

  @override
  String toString() => 'NotificationTarget($location, overlay: $overlay)';
}

/// Resolves a push's `data` payload to the screen that shows what it is
/// about.
///
/// `data['type']` (plus `newsId` / `eventId`) is the contract with the
/// backend: `pushPendingAnnouncements` sends `{type: 'announcement', newsId}`,
/// `onEventWritten` sends `{type: 'event', eventId}`, `pushServiceReminders`
/// sends `{type: 'service_reminder', branch}`, the reading job sends
/// `{type: 'reading'}` and venue changes send `{type: 'venue'}`. Adding a type
/// server-side without a case here drops the member on `/home`.
NotificationTarget notificationTargetFor(Map<String, dynamic> data) {
  String? id(String key) {
    final value = data[key];
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  final eventId = id('eventId');
  NotificationTarget eventDetail(String id) =>
      NotificationTarget('/events/${Uri.encodeComponent(id)}', overlay: true);

  switch (data['type'] as String?) {
    case 'announcement':
    case 'news':
      // An announcement about an event opens the event itself.
      if (eventId != null) return eventDetail(eventId);
      final newsId = id('newsId');
      return NotificationTarget(
        newsId == null
            ? '/announcements'
            : '/announcements?id=${Uri.encodeQueryComponent(newsId)}',
        overlay: true,
      );
    case 'sermon':
      return const NotificationTarget('/messages');
    case 'event':
    case KharisTopics.events:
      return eventId != null
          ? eventDetail(eventId)
          : const NotificationTarget('/calendar');
    case 'service_reminder':
    case KharisTopics.serviceReminders:
    case 'venue':
      // Service times and the campus address live on Home's campus card.
      return const NotificationTarget('/home');
    case 'reading':
    case KharisTopics.dailyReading:
      return const NotificationTarget('/reading', overlay: true);
    default:
      return const NotificationTarget('/home');
  }
}

/// Opens [target] without leaving a one-page stack: overlays are pushed above
/// `/home`, tab roots are switched to.
void openNotificationTarget(GoRouter router, NotificationTarget target) {
  if (target.overlay) {
    router.go('/home');
    router.push(target.location);
  } else {
    router.go(target.location);
  }
}

class NotificationService {
  NotificationService({this.router, this.onContentPush});

  final GoRouter? router;

  /// Called with `data['type']` whenever a push arrives in the foreground or
  /// is tapped, so cached feeds (announcements, events) can be refetched and
  /// the screen the member lands on shows the item they were told about.
  final void Function(String? type)? onContentPush;

  /// One-time FCM wiring that needs no user consent: message handlers, the
  /// mandatory `all` topic and token persistence.
  ///
  /// It deliberately does NOT show the OS permission prompt — that waits
  /// until onboarding is complete (see `notificationPermissionGateProvider`).
  /// Handlers are registered before anything that can fail (token, topics),
  /// each step in its own guard, so a `getToken` failure can never leave a
  /// tapped notification unrouted.
  Future<void> init() async {
    if (!kUseFirebase) return;
    final FirebaseMessaging messaging;
    try {
      messaging = FirebaseMessaging.instance;
      FirebaseMessaging.onBackgroundMessage(firebaseBackgroundMessageHandler);
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);
      final initial = await messaging.getInitialMessage();
      if (initial != null) _handleNotificationTap(initial);
    } catch (e) {
      debugPrint('[FCM] handler setup error: $e');
      return;
    }

    // Global announcements are not opt-out; the preference-gated topics are
    // applied by `notificationTopicSyncProvider`.
    await subscribeToTopic(KharisTopics.all);

    try {
      messaging.onTokenRefresh.listen(_saveTokenToProfile);
      fb_auth.FirebaseAuth.instance.authStateChanges().listen((u) {
        if (u != null && !u.isAnonymous) syncToken();
      });
    } catch (e) {
      debugPrint('[FCM] token listener error: $e');
    }
    await syncToken();
  }

  /// Re-applies everything that depends on the OS having let us in: iOS
  /// refuses topic subscriptions and tokens until permission is granted, so
  /// the `all` and branch topics subscribed before the prompt are retried
  /// here, and the token is (re)persisted.
  Future<void> onPermissionGranted({String? branch}) async {
    await subscribeToTopic(KharisTopics.all);
    final name = branch?.trim();
    if (name != null && name.isNotEmpty) {
      await subscribeToTopic(KharisTopics.branch(name));
    }
    await syncToken();
  }

  /// Persists the current FCM token on the member's profile. Never throws.
  Future<void> syncToken() async {
    if (!kUseFirebase) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      await _saveTokenToProfile(token);
    } catch (e) {
      debugPrint('[FCM] getToken skipped: $e');
    }
  }

  /// Best-effort write of `users/{uid}.fcmToken` for direct pushes.
  ///
  /// No-op for guests and signed-out sessions. Uses the same role-free
  /// merge shape as notification prefs, which the rules already allow.
  /// Failures only log — token persistence must never block startup.
  Future<void> _saveTokenToProfile(String? token) async {
    if (token == null || token.isEmpty) return;
    try {
      final user = fb_auth.FirebaseAuth.instance.currentUser;
      if (user == null || user.isAnonymous) return;
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'fcmToken': token,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[FCM] token save skipped: $e');
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
    onContentPush?.call(message.data['type'] as String?);
    final title = message.notification?.title;
    final body = message.notification?.body;
    debugPrint('[FCM] Foreground: $title / $body');
    // FCM draws nothing while the app is foregrounded, so surface it in-app.
    final text = [
      title,
      body,
    ].whereType<String>().where((s) => s.isNotEmpty).join(': ');
    if (text.isEmpty) return;
    kharisMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(text),
        duration: const Duration(seconds: 6),
        action: SnackBarAction(label: 'View', onPressed: () => _open(message)),
      ),
    );
  }

  void _handleNotificationTap(RemoteMessage message) {
    debugPrint('[FCM] Tapped: ${message.notification?.title}');
    onContentPush?.call(message.data['type'] as String?);
    _open(message);
  }

  void _open(RemoteMessage message) {
    final router = this.router;
    if (router == null) return;
    openNotificationTarget(router, notificationTargetFor(message.data));
  }

  /// Subscribe to an FCM topic.
  ///
  /// Built-in topics: [KharisTopics.all], [KharisTopics.events],
  /// [KharisTopics.dailyReading], [KharisTopics.serviceReminders]. Branch
  /// topics: [KharisTopics.branch].
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
