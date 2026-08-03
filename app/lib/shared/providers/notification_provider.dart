import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/firebase_service.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/app_router.dart';
import 'auth_provider.dart';

// ── Service ───────────────────────────────────────────────────────────────────

/// Provides the [NotificationService] wired up to the app router so that
/// notification taps can navigate to the right screen.
final notificationServiceProvider = Provider<NotificationService>((ref) {
  // Read (not watch) — the router is a stable singleton that never rebuilds.
  final router = ref.read(appRouterProvider);
  return NotificationService(router: router);
});

// ── Startup ───────────────────────────────────────────────────────────────────

/// Runs the one-time FCM setup: OS permission prompt, token, message handlers
/// and the mandatory `all` topic.
///
/// Watched by `KharisApp` so it runs on every real launch without blocking the
/// first frame (the future is never awaited by the widget tree).
final notificationInitProvider = FutureProvider<void>((ref) {
  return ref.read(notificationServiceProvider).init();
});

// ── Preference enforcement ────────────────────────────────────────────────────

/// Keeps this device's preference-gated FCM topics in step with the user's
/// saved notification preferences.
///
/// Without this the toggles in Notification settings would only ever write to
/// Firestore. Watched by `KharisApp` so it applies on launch and on every
/// later preference change (including changes made on another device).
final notificationTopicSyncProvider = Provider<void>((ref) {
  if (!kUseFirebase) return;
  final service = ref.watch(notificationServiceProvider);
  ref.listen<AsyncValue<Map<String, bool>>>(
    notificationPrefsProvider,
    (_, next) {
      final prefs = next.valueOrNull;
      if (prefs != null) service.applyPreferences(prefs);
    },
    fireImmediately: true,
  );
});

// ── Permission ────────────────────────────────────────────────────────────────

/// Whether the user has granted notification permission.
///
/// Queries the current [AuthorizationStatus] without re-requesting;
/// [notificationInitProvider] has already shown the OS prompt by the time any
/// screen reads this. Returns `false` when Firebase is disabled
/// ([kUseFirebase] == false) or when permission is denied/undetermined.
final notificationPermissionProvider = FutureProvider<bool>((ref) async {
  if (!kUseFirebase) return false;
  try {
    final settings =
        await FirebaseMessaging.instance.getNotificationSettings();
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  } catch (_) {
    return false;
  }
});
