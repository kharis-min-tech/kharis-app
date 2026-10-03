import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/firebase_service.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/app_router.dart';
import 'auth_provider.dart';
import 'onboarding_provider.dart';
import 'sermon_provider.dart';

// ── Service ───────────────────────────────────────────────────────────────────

/// Provides the [NotificationService] wired up to the app router so that
/// notification taps can navigate to the right screen.
final notificationServiceProvider = Provider<NotificationService>((ref) {
  // Read (not watch) — the router is a stable singleton that never rebuilds.
  final router = ref.read(appRouterProvider);
  return NotificationService(
    router: router,
    // A push is the signal that the content behind it changed. The
    // announcement feed is a cached API future, so without this the member
    // taps "new announcement" and lands on a feed that does not contain it.
    onContentPush: (type) {
      switch (type) {
        case 'announcement':
        case 'news':
          ref.invalidate(newsProvider);
        case 'event':
        case KharisTopics.events:
          ref.invalidate(upcomingEventsProvider);
      }
    },
  );
});

// ── Startup ───────────────────────────────────────────────────────────────────

/// Runs the one-time FCM setup (message handlers, the mandatory `all` topic,
/// token) and arms [notificationPermissionGateProvider].
///
/// Watched by `KharisApp` so it runs on every real launch without blocking the
/// first frame (the future is never awaited by the widget tree). It never
/// shows the OS permission prompt itself.
final notificationInitProvider = FutureProvider<void>((ref) async {
  await ref.read(notificationServiceProvider).init();
  // Read, not watch: a gate rebuild must never re-run init() (and register
  // every FCM handler twice).
  ref.read(notificationPermissionGateProvider);
});

/// Shows the OS notification prompt once, and only after onboarding is
/// complete.
///
/// Asking on the very first frame (as the app used to) put the system sheet
/// over the welcome screen, before the member knew what the app was, which is
/// the moment they are most likely to refuse. The onboarding flag lives in
/// SharedPreferences and is not observable, so the gate re-checks it on every
/// navigation: the step that completes onboarding always navigates into the
/// app, which trips the check.
final notificationPermissionGateProvider = Provider<void>((ref) {
  final service = ref.watch(notificationServiceProvider);
  final onboarding = ref.watch(onboardingRepositoryProvider);
  final delegate = ref.watch(appRouterProvider).routerDelegate;

  var asked = false;
  void check() {
    if (asked || !onboarding.isCompleted) return;
    asked = true;
    delegate.removeListener(check);
    unawaited(() async {
      final granted = await service.requestPermission();
      if (granted) {
        await service.onPermissionGranted(branch: onboarding.selectedBranch);
      }
      try {
        ref.invalidate(notificationPermissionProvider);
        // iOS rejects topic subscriptions until permission is granted, so
        // re-apply the preference topics now that it may have been.
        ref.invalidate(notificationTopicSyncProvider);
      } catch (_) {
        // Container disposed while the prompt was up.
      }
    }());
  }

  delegate.addListener(check);
  ref.onDispose(() => delegate.removeListener(check));
  check();
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
  ref.listen<AsyncValue<Map<String, bool>>>(notificationPrefsProvider, (
    _,
    next,
  ) {
    final prefs = next.valueOrNull;
    if (prefs != null) service.applyPreferences(prefs);
  }, fireImmediately: true);
});

// ── Permission ────────────────────────────────────────────────────────────────

/// Whether the user has granted notification permission.
///
/// Queries the current [AuthorizationStatus] without re-requesting. Before
/// onboarding completes nothing has asked yet, so this reads `false`; the
/// Notification settings screen offers its own "Allow notifications" action.
/// Returns `false` when Firebase is disabled ([kUseFirebase] == false) or
/// when permission is denied/undetermined.
final notificationPermissionProvider = FutureProvider<bool>((ref) async {
  if (!kUseFirebase) return false;
  try {
    final settings = await FirebaseMessaging.instance.getNotificationSettings();
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  } catch (_) {
    return false;
  }
});
