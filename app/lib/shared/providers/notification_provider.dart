import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/firebase_service.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/app_router.dart';
import 'auth_provider.dart';
import 'branch_provider.dart';
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

/// Shows the OS notification prompt once, and only once the member is in the
/// app: onboarding is complete, or they are signed in with a real account.
/// That is the router's "past the welcome screen" test, minus guests: every
/// launch signs in anonymously, so a guest session alone proves nothing.
///
/// Asking on the very first frame (as the app used to) put the system sheet
/// over the welcome screen, before the member knew what the app was, which is
/// the moment they are most likely to refuse. A returning member who signs in
/// on a fresh install never completes onboarding (Splash -> Sign in -> Home,
/// and the branch step is skipped when their profile has one), so signing in
/// opens the gate too. The onboarding flag lives in SharedPreferences and is
/// not observable, so the gate re-checks it on every navigation (the step
/// that completes onboarding always navigates into the app) and on every auth
/// change.
final notificationPermissionGateProvider = Provider<void>((ref) {
  final service = ref.watch(notificationServiceProvider);
  final onboarding = ref.watch(onboardingRepositoryProvider);
  final delegate = ref.watch(appRouterProvider).routerDelegate;

  var asked = false;
  void check() {
    if (asked) return;
    final user = ref.read(currentUserProvider).valueOrNull;
    final member = user != null && user.id.isNotEmpty && user.role != 'guest';
    if (!onboarding.isCompleted && !member) return;
    asked = true;
    delegate.removeListener(check);
    // Taken now: the gate can be rebuilt while the OS sheet is up.
    final onAnswer = ref.read(notificationPermissionAnsweredProvider);
    unawaited(() async {
      await onAnswer(await service.requestPermission());
    }());
  }

  delegate.addListener(check);
  ref.onDispose(() => delegate.removeListener(check));
  ref.listen(currentUserProvider, (_, _) => check());
  check();
});

/// The follow-up to an answered OS permission prompt, shared by
/// [notificationPermissionGateProvider] and the "Turn on notifications" card
/// (notifications inbox and Notification settings).
///
/// Read it BEFORE showing the prompt and call it with the answer: it runs on
/// this provider's own `ref`, so it still works after the screen that asked
/// has been popped (a widget's `ref` is dead by then).
final notificationPermissionAnsweredProvider =
    Provider<Future<void> Function(bool granted)>((ref) {
      return (granted) async {
        try {
          if (granted) {
            // The campus as the app scopes content: the profile branch for a
            // signed-in member, the onboarding choice otherwise.
            var branch = ref.read(onboardingRepositoryProvider).selectedBranch;
            try {
              branch = await ref
                  .read(currentBranchProvider.future)
                  .timeout(const Duration(seconds: 10));
            } catch (_) {
              // Unresolved or failed: keep the local choice rather than skip
              // the topic subscriptions.
            }
            await ref
                .read(notificationServiceProvider)
                .onPermissionGranted(branch: branch);
            // iOS rejects topic subscriptions until permission is granted, so
            // re-apply the preference topics now that it has been.
            ref.invalidate(notificationTopicSyncProvider);
          }
          ref.invalidate(notificationPermissionProvider);
        } catch (_) {
          // The container was disposed while the prompt was up.
        }
      };
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

/// What the OS currently lets the app do with notifications.
///
/// Queries the current [AuthorizationStatus] without re-requesting. Until
/// [notificationPermissionGateProvider] opens nothing has asked yet, so this
/// reads [NotificationPermission.askable]; the notifications inbox and the
/// Notification settings screen offer their own "Turn on notifications"
/// (`NotificationPermissionCard`). [NotificationPermission.unavailable] when
/// Firebase is disabled ([kUseFirebase] == false) or the query fails.
final notificationPermissionProvider = FutureProvider<NotificationPermission>((
  ref,
) async {
  if (!kUseFirebase) return NotificationPermission.unavailable;
  try {
    final settings = await FirebaseMessaging.instance.getNotificationSettings();
    return notificationPermissionFor(
      settings.authorizationStatus,
      defaultTargetPlatform,
    );
  } catch (_) {
    return NotificationPermission.unavailable;
  }
});

const _kPromptDeclinedKey = 'notification_prompt_declined';

/// Whether the member answered "Not now" to the inbox's "Turn on
/// notifications" card. Remembered on this device so the inbox never asks
/// again; Notification settings keeps its own notice for when they change
/// their mind.
class NotificationPromptDeclinedController extends StateNotifier<bool> {
  NotificationPromptDeclinedController(this._ref)
    : super(
        _ref.read(sharedPreferencesProvider).getBool(_kPromptDeclinedKey) ??
            false,
      );

  final Ref _ref;

  Future<void> decline() async {
    state = true;
    await _ref
        .read(sharedPreferencesProvider)
        .setBool(_kPromptDeclinedKey, true);
  }
}

final notificationPromptDeclinedProvider =
    StateNotifierProvider<NotificationPromptDeclinedController, bool>(
      NotificationPromptDeclinedController.new,
    );
