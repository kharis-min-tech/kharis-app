import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/onboarding/data/auth_repository.dart';
import '../../features/onboarding/data/firebase_auth_repository.dart';
import '../models/user.dart';
import 'onboarding_provider.dart';

// ── Repository providers ──────────────────────────────────────────────────────

/// Concrete Firebase-backed repository — exposes profile editing and admin
/// checks beyond the [AuthRepository] interface.
final firebaseAuthRepositoryProvider = Provider<FirebaseAuthRepository>((ref) {
  return FirebaseAuthRepository();
});

/// Auth repository as the abstract interface used by most callers.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return ref.watch(firebaseAuthRepositoryProvider);
});

// ── Auth state providers ──────────────────────────────────────────────────────

/// Reactive auth state — emits [User?] whenever login/logout happens.
final currentUserProvider = StreamProvider<User?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

/// Synchronous auth flag derived from the stream. Safe to read in redirects.
final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(currentUserProvider).maybeWhen(
        data: (user) => user != null,
        orElse: () => false,
      );
});

/// True when the signed-in user is an admin (profile role or `admin` claim).
final isAdminProvider = FutureProvider<bool>((ref) async {
  final user = ref.watch(currentUserProvider).valueOrNull;
  if (user == null) return false;
  if (user.role == 'admin') return true;
  return ref.read(firebaseAuthRepositoryProvider).isCurrentUserAdmin();
});

// ── Notification preferences ──────────────────────────────────────────────────

const _kDefaultNotificationPrefs = <String, bool>{
  'serviceReminders': true,
  'events': true,
  'dailyReading': true,
  'newSermons': true,
};

/// Streams notification preference toggles from the user's Firestore doc.
/// Returns defaults for unauthenticated or guest sessions.
final notificationPrefsProvider = StreamProvider<Map<String, bool>>((ref) {
  final user = ref.watch(currentUserProvider).valueOrNull;
  if (user == null || user.role == 'guest') {
    return Stream.value(Map.unmodifiable(_kDefaultNotificationPrefs));
  }
  return FirebaseFirestore.instance
      .collection('users')
      .doc(user.id)
      .snapshots()
      .map((snap) {
    final raw = snap.data()?['notificationPrefs'] as Map<String, dynamic>?;
    if (raw == null) return Map.unmodifiable(_kDefaultNotificationPrefs);
    return {
      'serviceReminders': (raw['serviceReminders'] as bool?) ?? true,
      'events': (raw['events'] as bool?) ?? true,
      'dailyReading': (raw['dailyReading'] as bool?) ?? true,
      'newSermons': (raw['newSermons'] as bool?) ?? true,
    };
  });
});
// ── Router notifier ───────────────────────────────────────────────────────────

/// [ChangeNotifier] that pings [GoRouter] whenever auth state changes,
/// causing redirect logic to re-evaluate the current location.
class RouterNotifier extends ChangeNotifier {
  RouterNotifier(this._ref) {
    _ref.listen<AsyncValue<User?>>(currentUserProvider, (_, _) {
      notifyListeners();
    });
  }

  final Ref _ref;

  /// Called by [GoRouter] on every navigation and after [notifyListeners].
  String? redirect(BuildContext context, GoRouterState state) {
    // One-time welcome: once onboarding is complete (or the user is signed in),
    // the '/' splash entry routes straight to Home. Only '/' is gated, so
    // "Switch Branch" (/branch-selection) and re-onboarding still work.
    if (state.matchedLocation == '/') {
      final completed = _ref.read(onboardingCompletedProvider);
      final authed = _ref.read(isAuthenticatedProvider);
      if (completed || authed) return '/home';
    }
    return null;
  }
}

final routerNotifierProvider = ChangeNotifierProvider<RouterNotifier>((ref) {
  return RouterNotifier(ref);
});
