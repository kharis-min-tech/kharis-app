import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/onboarding/data/auth_repository.dart';
import '../../features/onboarding/data/firebase_auth_repository.dart';
import '../models/campus_config.dart';
import '../models/user.dart';
import 'branch_provider.dart' show firestoreProvider;
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

/// What the signed-in user may manage in Content Studio, from their live
/// `users/{uid}` doc (role + campus lists) and the `admin` custom claim.
///
/// A profile read error falls back to the role already hydrated on the
/// session, so a super admin keeps Studio while a campus admin (whose
/// campuses only live on the doc) does not.
final adminScopeProvider = StreamProvider<AdminScope>((ref) async* {
  final user = ref.watch(currentUserProvider).valueOrNull;
  if (user == null) {
    yield const AdminScope.none();
    return;
  }
  // True for the profile role 'admin' or the custom claim; either makes a
  // super admin, so it stands in for the claim in [AdminScope.fromProfile].
  final adminClaim = await ref
      .read(firebaseAuthRepositoryProvider)
      .isCurrentUserAdmin();
  try {
    await for (final snap
        in ref
            .watch(firestoreProvider)
            .collection('users')
            .doc(user.id)
            .snapshots()) {
      yield AdminScope.fromProfile(snap.data(), adminClaim: adminClaim);
    }
  } catch (_) {
    yield AdminScope.fromProfile({'role': user.role}, adminClaim: adminClaim);
  }
});

/// True when the signed-in user may open Content Studio: a super admin
/// (profile role or `admin` claim) or a campus admin with 1+ campuses.
/// Screens use [adminScopeProvider] for what they may manage inside it.
final isAdminProvider = FutureProvider<bool>((ref) async {
  final scope = await ref.watch(adminScopeProvider.future);
  return scope.canUseStudio;
});

/// Studio routes only a super admin may open; campus admins are sent back
/// to the Studio hub. `/admin/branches/:id` is checked per campus.
const _superAdminRoutes = [
  '/admin/users',
  '/admin/sermons',
  '/admin/reading-plans',
  '/admin/bible-reading',
  '/admin/settings',
];

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
    // Keeps the Studio access check alive and re-runs the guard when it
    // resolves or changes, so a member who loses the role (or a campus admin
    // who loses a campus) is moved off a screen they may no longer open.
    _ref.listen<AsyncValue<bool>>(isAdminProvider, (_, _) {
      notifyListeners();
    });
    _ref.listen<AsyncValue<AdminScope>>(adminScopeProvider, (_, _) {
      notifyListeners();
    });
  }

  final Ref _ref;

  /// Called by [GoRouter] on every navigation and after [notifyListeners].
  String? redirect(BuildContext context, GoRouterState state) {
    final location = state.matchedLocation;

    // Content Studio: only a confirmed super or campus admin gets in. The
    // More entry is only rendered once [isAdminProvider] has resolved true,
    // so an admin never hits the unresolved case through the UI; a deep link
    // that arrives before the check resolves is bounced rather than shown.
    // Campus admins are kept to their campuses' screens: super-admin-only
    // areas and other campuses' branch pages return them to the hub.
    if (location == '/admin' || location.startsWith('/admin/')) {
      final isAdmin = _ref.read(isAdminProvider).valueOrNull ?? false;
      if (!isAdmin) return '/home';
      final scope = _ref.read(adminScopeProvider).valueOrNull;
      if (scope == null || scope.isSuperAdmin) return null;
      final superOnly = _superAdminRoutes.any(
        (r) => location == r || location.startsWith('$r/'),
      );
      if (superOnly) return '/admin';
      const branchPrefix = '/admin/branches/';
      if (location.startsWith(branchPrefix)) {
        final id = location.substring(branchPrefix.length).split('/').first;
        if (!scope.canManageBranchId(id)) return '/admin';
      }
      return null;
    }

    // One-time welcome: once onboarding is complete (or a member has signed
    // in), the '/' splash entry routes straight to Home. Only '/' is gated,
    // so "Switch Branch" (/branch-selection) and re-onboarding still work.
    // The automatic anonymous guest session every launch creates does NOT
    // count: a fresh install must still see Welcome and role selection.
    if (location == '/') {
      final completed = _ref.read(onboardingCompletedProvider);
      final user = _ref.read(currentUserProvider).valueOrNull;
      final member =
          user != null && user.role != 'guest' && user.email.isNotEmpty;
      if (completed || member) {
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
