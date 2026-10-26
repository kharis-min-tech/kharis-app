import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../features/home/data/bible_reference.dart';
import '../../features/home/data/bible_repository.dart';
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
  // reading straight to `daily_reading_v2` (`READING_AUDIENCES` in
  // `topics.ts`).
  static const String serviceReminders = 'service_reminders';
  static const String events = 'events';
  static const String dailyReading = 'daily_reading_v2';

  /// Opt-OUT topic: a device here is left out of branch announcements
  /// (`'<branch topic>' in topics && !('mute_announcements' in topics)`).
  /// Opt-out rather than opt-in so builds that predate the switch, which
  /// never subscribe to it, keep receiving announcements.
  static const String muteAnnouncements = 'mute_announcements';

  /// The `notificationPrefsProvider` key that drives [muteAnnouncements],
  /// inverted: ON leaves the topic, OFF joins it.
  static const String announcementsPreference = 'announcements';

  /// The daily reading's old topic. An earlier reading-plan push sent
  /// chapters that do not exist ("2 Corinthians 40") here, and the OS shows a
  /// background push without asking the app, so every launch leaves it.
  /// The backend still reaches builds that never left it with a condition
  /// excluding [dailyReading] devices.
  static const String legacyDailyReading = 'daily_reading';

  /// Maps an opt-in `notificationPrefsProvider` key to the topic it gates.
  /// [announcementsPreference] is handled separately (inverted).
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
  /// The slug MUST stay character-identical to the backend's `branchTopic`
  /// in `backend/functions/src/topics.ts`, the only other implementation of
  /// it.
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
/// `{type: 'reading'}` and venue changes send `{type: 'venue'}`. Adding a type server-side without a case here drops the member
/// on `/home`.
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
      // The feed opens the announcement, and through it the event it
      // promotes, falling back to the announcement's own text when that event
      // is gone. Only a push with no announcement id goes straight to the
      // event.
      final newsId = id('newsId');
      if (newsId == null && eventId != null) return eventDetail(eventId);
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
    case KharisTopics.legacyDailyReading:
      return const NotificationTarget('/reading', overlay: true);
    default:
      return const NotificationTarget('/home');
  }
}

/// Whether a push that arrived in the foreground may be shown in-app.
///
/// A daily reading push ([notificationTargetFor] routes it to `/reading`) is
/// shown only when its reference, `data['reference']` else [body], names one
/// or more passages and every one is a real book of the 66-book canon with a
/// chapter that book has. An older backend sent "2 Corinthians 40"; the app
/// never presents that. Every other push is shown.
bool isShowableForegroundPush(Map<String, dynamic> data, String? body) {
  final type = data['type'];
  if (type != 'reading' &&
      type != KharisTopics.dailyReading &&
      type != KharisTopics.legacyDailyReading) {
    return true;
  }
  final reference = data['reference'];
  final text = reference is String && reference.trim().isNotEmpty
      ? reference
      : body;
  return text != null && isValidReading(text, BibleIndex.bundled());
}

/// Opens [target] without leaving a one-page stack: overlays are pushed above
/// `/home`, tab roots are switched to.
///
/// The push waits for the frame after the `go`: `push` stacks onto the
/// router's current configuration, which only holds `/home` once the router
/// has processed the `go`. On a cold start (a tap that launched the app) the
/// router is not even on screen yet, and an immediate push would leave the
/// overlay alone on the stack with nothing behind it.
void openNotificationTarget(GoRouter router, NotificationTarget target) {
  if (!target.overlay) {
    router.go(target.location);
    return;
  }
  router.go('/home');
  final binding = WidgetsBinding.instance;
  binding.addPostFrameCallback((_) => router.push(target.location));
  // A go to the current location schedules nothing; make sure a frame comes.
  binding.ensureVisualUpdate();
}

/// What the OS lets the app do with notifications, as far as the member's
/// next step is concerned.
enum NotificationPermission {
  /// Allowed (iOS provisional included).
  granted,

  /// Not allowed, and asking may still show the OS sheet: iOS before the
  /// first answer, and Android, which reports every not-granted state as
  /// "denied" (when it will not ask again the request simply returns).
  askable,

  /// Refused on iOS. The sheet is shown once per install, so only system
  /// settings can turn notifications on.
  blocked,

  /// Unknown (Firebase disabled or the plugin failed): nothing to offer.
  unavailable,
}

/// Maps the plugin's [status] to the member's next step on [platform].
NotificationPermission notificationPermissionFor(
  AuthorizationStatus status,
  TargetPlatform platform,
) {
  switch (status) {
    case AuthorizationStatus.authorized:
    case AuthorizationStatus.provisional:
      return NotificationPermission.granted;
    case AuthorizationStatus.notDetermined:
      return NotificationPermission.askable;
    case AuthorizationStatus.denied:
      return platform == TargetPlatform.iOS
          ? NotificationPermission.blocked
          : NotificationPermission.askable;
    case AuthorizationStatus.deniedPermanently:
      return NotificationPermission.blocked;
  }
}

/// Opens this app's notification settings on Android (see `MainActivity`).
const MethodChannel _systemSettingsChannel = MethodChannel(
  'com.kharis.church/system_settings',
);

class NotificationService {
  NotificationService({this.router, this.onContentPush});

  final GoRouter? router;

  /// Called with `data['type']` whenever a push arrives in the foreground or
  /// is tapped, so cached feeds (announcements, events) can be refetched and
  /// the screen the member lands on shows the item they were told about.
  final void Function(String? type)? onContentPush;

  /// How long [init] waits for the launch notification before moving on.
  @visibleForTesting
  static Duration initialMessageTimeout = const Duration(seconds: 3);

  /// One-time FCM wiring that needs no user consent: message handlers, the
  /// mandatory `all` topic and token persistence.
  ///
  /// It deliberately does NOT show the OS permission prompt — that waits
  /// until the member is in the app (see `notificationPermissionGateProvider`).
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
      // iOS with the implicit Flutter engine never answers this call (the
      // plugin misses the launch notification it waits on), which used to
      // stall topics, token sync and the permission gate forever.
      final initial = await messaging.getInitialMessage().timeout(
        initialMessageTimeout,
        onTimeout: () => null,
      );
      if (initial != null) _handleNotificationTap(initial);
    } catch (e) {
      debugPrint('[FCM] handler setup error: $e');
      return;
    }

    // Global announcements are not opt-out; the preference-gated topics and
    // the branch topic are applied by `notificationTopicSyncProvider`.
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
    await syncBranchTopic(branch);
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
        // The backend never sets a badge count, so do not ask for one.
        badge: false,
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

  /// Opens the system settings page where the member can allow Kharis
  /// notifications, for when the OS will no longer show its own prompt.
  /// Returns whether a settings page opened. Never throws.
  Future<bool> openSystemSettings() async {
    try {
      switch (defaultTargetPlatform) {
        case TargetPlatform.iOS:
          // UIApplication.openSettingsURLString: this app's page in Settings,
          // with Notifications at the top.
          return await launchUrl(Uri.parse('app-settings:'));
        case TargetPlatform.android:
          return await _systemSettingsChannel.invokeMethod<bool>(
                'openNotificationSettings',
              ) ??
              false;
        default:
          return false;
      }
    } catch (e) {
      debugPrint('[FCM] openSystemSettings error: $e');
      return false;
    }
  }

  /// Applies the whole notification-preference map to this device's topics.
  ///
  /// Unknown keys are ignored, so adding a preference without a topic is safe.
  /// Always leaves [KharisTopics.legacyDailyReading] first, whatever the
  /// preferences say (this runs on every launch, and on iOS again once
  /// permission is granted).
  Future<void> applyPreferences(Map<String, bool> prefs) async {
    await unsubscribeFromTopic(KharisTopics.legacyDailyReading);
    for (final entry in prefs.entries) {
      await applyPreference(entry.key, entry.value);
    }
  }

  /// Applies a single preference toggle. No-op for keys without a topic.
  Future<void> applyPreference(String key, bool enabled) async {
    if (key == KharisTopics.announcementsPreference) {
      await _setTopic(KharisTopics.muteAnnouncements, !enabled);
      return;
    }
    final topic = KharisTopics.byPreference[key];
    if (topic == null) return;
    await _setTopic(topic, enabled);
  }

  /// SharedPreferences key of the branch topic this device last subscribed.
  @visibleForTesting
  static const String subscribedBranchTopicKey = 'fcm_subscribed_branch_topic';

  /// Puts this device on [branch]'s topic, leaving the one it last joined if
  /// that differs (the branch was switched while offline, or renamed).
  /// Runs on every launch; a missing branch is left alone. Never throws.
  Future<void> syncBranchTopic(String? branch) async {
    final name = branch?.trim();
    if (name == null || name.isEmpty) return;
    await _moveToBranchTopic(KharisTopics.branch(name));
  }

  /// Moves this device from one branch topic to another.
  ///
  /// The single code path used by both Switch Branch and Edit Profile. Pass
  /// `null`/empty for [from] on first selection; a no-change call is a no-op.
  ///
  /// Topics are keyed on the slugged branch NAME. A renamed branch moves the
  /// device on its next launch: [syncBranchTopic] subscribes the new name's
  /// topic and leaves the stored old one.
  Future<void> switchBranchTopic({String? from, String? to}) async {
    final previous = (from ?? '').trim();
    final next = (to ?? '').trim();
    if (previous == next) return;
    final previousTopic = previous.isEmpty
        ? null
        : KharisTopics.branch(previous);
    if (next.isEmpty) {
      if (previousTopic != null) await unsubscribeFromTopic(previousTopic);
      return;
    }
    await _moveToBranchTopic(KharisTopics.branch(next), from: previousTopic);
  }

  /// Subscribes [topic], unsubscribing [from] and the stored topic when they
  /// differ from it, and records [topic] once every step has succeeded (a
  /// failed leave keeps the old record, so the next launch retries it).
  Future<void> _moveToBranchTopic(String topic, {String? from}) async {
    SharedPreferences? store;
    try {
      store = await SharedPreferences.getInstance();
    } catch (e) {
      debugPrint('[FCM] branch topic store unavailable: $e');
    }
    final stored = store?.getString(subscribedBranchTopicKey);
    var left = true;
    for (final old in {from, stored}) {
      if (old == null || old == topic) continue;
      final ok = await unsubscribeFromTopic(old);
      if (old == stored) left = ok;
    }
    final joined = await subscribeToTopic(topic);
    if (joined && left && stored != topic) {
      await store?.setString(subscribedBranchTopicKey, topic);
    }
  }

  Future<bool> _setTopic(String topic, bool enabled) =>
      enabled ? subscribeToTopic(topic) : unsubscribeFromTopic(topic);

  void _handleForegroundMessage(RemoteMessage message) {
    onContentPush?.call(message.data['type'] as String?);
    final title = message.notification?.title;
    final body = message.notification?.body;
    debugPrint('[FCM] Foreground: $title / $body');
    if (!isShowableForegroundPush(message.data, body)) {
      debugPrint('[FCM] Foreground reading dropped: not a real passage');
      return;
    }
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

  /// Subscribe to an FCM topic. Returns whether it succeeded; never throws.
  ///
  /// Built-in topics: [KharisTopics.all], [KharisTopics.events],
  /// [KharisTopics.dailyReading] (`daily_reading_v2`),
  /// [KharisTopics.serviceReminders], [KharisTopics.muteAnnouncements].
  /// Branch topics: [KharisTopics.branch].
  Future<bool> subscribeToTopic(String topic) async {
    if (!kUseFirebase) return false;
    try {
      await FirebaseMessaging.instance.subscribeToTopic(topic);
      debugPrint('[FCM] Subscribed to $topic');
      return true;
    } catch (e) {
      debugPrint('[FCM] subscribeToTopic($topic) error: $e');
      return false;
    }
  }

  /// Unsubscribe from an FCM topic. Returns whether it succeeded.
  Future<bool> unsubscribeFromTopic(String topic) async {
    if (!kUseFirebase) return false;
    try {
      await FirebaseMessaging.instance.unsubscribeFromTopic(topic);
      debugPrint('[FCM] Unsubscribed from $topic');
      return true;
    } catch (e) {
      debugPrint('[FCM] unsubscribeFromTopic($topic) error: $e');
      return false;
    }
  }
}
