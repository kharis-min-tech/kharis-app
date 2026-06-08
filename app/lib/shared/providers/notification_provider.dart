import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/firebase_service.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/app_router.dart';

// ── Service ───────────────────────────────────────────────────────────────────

/// Provides the [NotificationService] wired up to the app router so that
/// notification taps can navigate to the right screen.
final notificationServiceProvider = Provider<NotificationService>((ref) {
  // Read (not watch) — the router is a stable singleton that never rebuilds.
  final router = ref.read(appRouterProvider);
  return NotificationService(router: router);
});

// ── Permission ────────────────────────────────────────────────────────────────

/// Whether the user has granted notification permission.
///
/// Queries the current [AuthorizationStatus] without re-requesting; call
/// [NotificationService.init] first so the OS prompt has already been shown.
/// Returns `false` when Firebase is disabled ([kUseFirebase] == false) or
/// when permission is denied/undetermined.
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
