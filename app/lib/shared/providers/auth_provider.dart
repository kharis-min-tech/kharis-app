import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/onboarding/data/auth_repository.dart';
import '../models/user.dart';
import 'onboarding_provider.dart';

// ── Repository provider ───────────────────────────────────────────────────────

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final repo = TestAuthRepository(prefs);
  ref.onDispose(repo.dispose);
  return repo;
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

// ── Router notifier ───────────────────────────────────────────────────────────

/// [ChangeNotifier] that pings [GoRouter] whenever auth state changes,
/// causing redirect logic to re-evaluate the current location.
class RouterNotifier extends ChangeNotifier {
  RouterNotifier(this._ref) {
    // Listen without rebuilding this provider — only notify the router.
    _ref.listen<AsyncValue<User?>>(currentUserProvider, (_, _) {
      notifyListeners();
    });
  }

  final Ref _ref;

  /// Called by [GoRouter] on every navigation and after [notifyListeners].
  ///
  /// Reads auth state synchronously from the repository to avoid stream lag.
  String? redirect(BuildContext context, GoRouterState state) {
    // Read directly from the repository: _currentUser is updated before the
    // stream event is processed, so this is always current.
    final isAuthenticated =
        _ref.read(authRepositoryProvider).isAuthenticated;

    final path = state.uri.path;

    if (isAuthenticated) {
      // Authenticated users skip the splash, onboarding, and auth screens.
      if (path == '/' ||
          path == '/login' ||
          path == '/register') {
        return '/home';
      }
      return null;
    }

    // Unauthenticated: gate all main-app routes.
    const protected = {'/home', '/messages', '/giving', '/calendar', '/more'};
    if (protected.contains(path)) return '/login';

    return null;
  }
}

final routerNotifierProvider = ChangeNotifierProvider<RouterNotifier>((ref) {
  return RouterNotifier(ref);
});
