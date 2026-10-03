import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/onboarding/data/auth_repository.dart';
import '../../features/onboarding/data/firebase_auth_repository.dart';
import '../models/user.dart';
import 'onboarding_provider.dart';
import 'cache_provider.dart';

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
  return ref
      .watch(currentUserProvider)
      .maybeWhen(data: (user) => user != null, orElse: () => false);
});

/// Guarantees the session always has a Firebase user.
///
/// The primary onboarding path (role selection → branch selection → home)
/// never visits the login screen, so most members reach the app with NO
/// Firebase user at all — and everything keyed on `users/{uid}` (playlists,
/// note upload, profile sync) would silently have nowhere to write. Watching
/// this provider (done once in `KharisApp`) signs the session in anonymously
/// whenever auth resolves to "no user"; an explicit email sign-in later
/// replaces the anonymous account through the normal auth flow.
///
/// A failed attempt (offline first launch) is logged, and [AnonymousSignIn
/// .ensure] can be re-kicked from any surface whose UI says "still signing
/// you in — try again" so the retry actually retries.
final anonymousSignInProvider = Provider<AnonymousSignIn>((ref) {
  final bootstrap = AnonymousSignIn(ref);
  ref.listen<AsyncValue<User?>>(currentUserProvider, (_, next) {
    if (next is AsyncData<User?> && next.value == null) bootstrap.ensure();
  }, fireImmediately: true);
  return bootstrap;
});

/// Single-flight anonymous sign-in used by [anonymousSignInProvider].
class AnonymousSignIn {
  AnonymousSignIn(this._ref);

  final Ref _ref;
  Future<void>? _inFlight;

  /// Signs in anonymously unless a user already exists or an attempt is
  /// already running. Failures are logged — the next call retries.
  void ensure() {
    if (_ref.read(authRepositoryProvider).isAuthenticated) return;
    _inFlight ??= _attempt();
  }

  Future<void> _attempt() async {
    try {
      await _ref.read(authRepositoryProvider).loginAsGuest();
    } catch (e) {
      debugPrint('[auth] anonymous sign-in failed: $e');
    } finally {
      _inFlight = null;
    }
  }
}

/// True when the signed-in user is an admin (profile role or `admin` claim).
final isAdminProvider = FutureProvider<bool>((ref) async {
  final user = ref.watch(currentUserProvider).valueOrNull;
  if (user == null) return false;
  if (user.role == 'admin') return true;
  return ref.read(firebaseAuthRepositoryProvider).isCurrentUserAdmin();
});

// ── Notification preferences ──────────────────────────────────────────────────

/// One entry per FCM topic the backend actually publishes to (see
/// `KharisTopics.byPreference`). A toggle with no publisher behind it is a
/// promise the app cannot keep, so there is no "new sermons" switch.
const _kDefaultNotificationPrefs = <String, bool>{
  'serviceReminders': true,
  'events': true,
  'dailyReading': true,
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
          for (final key in _kDefaultNotificationPrefs.keys)
            key: (raw[key] as bool?) ?? true,
        };
      });
});
// ── Router notifier ───────────────────────────────────────────────────────────

/// [ChangeNotifier] that pings [GoRouter] whenever auth or admin state
/// changes, causing redirect logic to re-evaluate the current location.
class RouterNotifier extends ChangeNotifier {
  RouterNotifier(this._ref) {
    _ref.listen<AsyncValue<User?>>(currentUserProvider, (_, _) {
      notifyListeners();
    });
    // Keeps the admin check alive and re-runs the guard when it resolves, so
    // a member who loses the role is moved off an admin screen.
    _ref.listen<AsyncValue<bool>>(isAdminProvider, (_, _) {
      notifyListeners();
    });
  }

  final Ref _ref;

  /// Called by [GoRouter] on every navigation and after [notifyListeners].
  String? redirect(BuildContext context, GoRouterState state) {
    final location = state.matchedLocation;

    // Admin console: only a confirmed admin gets in. The More entry is only
    // rendered once [isAdminProvider] has resolved true, so an admin never
    // hits the unresolved case through the UI; a deep link that arrives
    // before the check resolves is bounced rather than shown.
    if (location == '/admin' || location.startsWith('/admin/')) {
      final isAdmin = _ref.read(isAdminProvider).valueOrNull ?? false;
      return isAdmin ? null : '/home';
    }

    // One-time welcome: once onboarding is complete (or the user is signed in),
    // the '/' splash entry routes straight to Home. Only '/' is gated, so
    // "Switch Branch" (/branch-selection) and re-onboarding still work.
    if (location == '/') {
      final completed = _ref.read(onboardingCompletedProvider);
      final authed = _ref.read(isAuthenticatedProvider);
      if (completed || authed) {
        const tabs = ['/home', '/messages', '/giving', '/calendar', '/more'];
        final i = _ref
            .read(cacheServiceProvider)
            .getPreference<int>('last_tab', 0);
        return tabs[i >= 0 && i < tabs.length ? i : 0];
      }
    }
    return null;
  }
}

final routerNotifierProvider = ChangeNotifierProvider<RouterNotifier>((ref) {
  return RouterNotifier(ref);
});
