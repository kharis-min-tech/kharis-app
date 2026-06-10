import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/calendar/presentation/screens/calendar_screen.dart';
import '../../features/giving/presentation/screens/giving_screen.dart';
import '../../features/home/presentation/screens/dashboard_shell.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/messages/presentation/screens/messages_screen.dart';
import '../../features/onboarding/presentation/screens/branch_selection_screen.dart';
import '../../features/onboarding/presentation/screens/login_screen.dart';
import '../../features/onboarding/presentation/screens/register_screen.dart';
import '../../features/onboarding/presentation/screens/role_selection_screen.dart';
import '../../features/onboarding/presentation/screens/splash_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/player/presentation/screens/full_player_screen.dart';
import '../../shared/providers/auth_provider.dart';

/// Central router as a Riverpod provider so [RouterNotifier] can drive
/// reactive redirects when auth state changes.
///
/// Onboarding flow (unauthenticated):
///   / → /role-selection → /branch-selection → /login → /home
///
/// Authenticated users: redirect straight to /home from /, /login, /register.
/// Unauthenticated users: redirect to /login from any protected main-app route.
final appRouterProvider = Provider<GoRouter>((ref) {
  final notifier = ref.read(routerNotifierProvider);

  final router = GoRouter(
    initialLocation: '/',
    refreshListenable: notifier,
    redirect: notifier.redirect,
    routes: [
      // ── Onboarding ────────────────────────────────────────────────────────
      GoRoute(
        path: '/',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/role-selection',
        builder: (context, state) => const RoleSelectionScreen(),
      ),
      GoRoute(
        path: '/branch-selection',
        builder: (context, state) => const BranchSelectionScreen(),
      ),

      // ── Auth ──────────────────────────────────────────────────────────────
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),

      // ── Main app (shell with bottom nav) ──────────────────────────────────
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            DashboardShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/messages',
                builder: (context, state) => const MessagesScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/giving',
                builder: (context, state) => const GivingScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/calendar',
                builder: (context, state) => const CalendarScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/more',
                builder: (context, state) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),

      // ── Full player (overlays shell) ──────────────────────────────────────
      GoRoute(
        path: '/player',
        builder: (context, state) => const FullPlayerScreen(),
      ),
    ],
  );

  ref.onDispose(router.dispose);
  return router;
});
