import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/calendar/presentation/screens/calendar_screen.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import '../../features/giving/presentation/screens/giving_screen.dart';
import '../../features/home/presentation/screens/dashboard_shell.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/browse/presentation/screens/browse_screen.dart';
import '../../features/messages/presentation/screens/messages_screen.dart';
import '../../features/onboarding/presentation/screens/branch_selection_screen.dart';
import '../../features/onboarding/presentation/screens/login_screen.dart';
import '../../features/onboarding/presentation/screens/register_screen.dart';
import '../../features/onboarding/presentation/screens/role_selection_screen.dart';
import '../../features/onboarding/presentation/screens/splash_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/player/presentation/screens/full_player_screen.dart';
import '../../features/player/presentation/screens/playlist_screen.dart';
import '../../features/home/presentation/screens/reading_screen.dart';
import '../../features/notes/presentation/screens/notes_screen.dart';
import '../../features/home/presentation/screens/notifications_screen.dart';
import '../../features/settings/presentation/screens/edit_profile_screen.dart';
import '../../features/admin/presentation/screens/admin_hub_screen.dart';
import '../../features/admin/presentation/screens/admin_announcements_screen.dart';
import '../../features/admin/presentation/screens/admin_events_screen.dart';
import '../../features/admin/presentation/screens/admin_branches_screen.dart';
import '../../features/admin/presentation/screens/admin_users_screen.dart';
import '../../features/admin/presentation/screens/admin_bible_reading_screen.dart';
import '../../features/admin/presentation/screens/admin_reading_plans_screen.dart';
import '../../features/admin/presentation/screens/admin_sermons_screen.dart';
import '../../features/admin/presentation/screens/admin_branch_detail_screen.dart';
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
    observers: [
      // Screen-view analytics; no-op when Firebase isn't initialized.
      if (Firebase.apps.isNotEmpty)
        FirebaseAnalyticsObserver(analytics: FirebaseAnalytics.instance),
    ],
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
                routes: [
                  GoRoute(
                    path: 'browse',
                    builder: (context, state) => const BrowseScreen(),
                  ),
                ],
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

      // ── Today's reading (overlays shell) ──────────────────────────────────
      GoRoute(
        path: '/reading',
        builder: (context, state) => const ReadingScreen(),
      ),

      // ── Playlists / collections (overlays shell) ──────────────────────────
      GoRoute(
        path: '/playlists',
        builder: (context, state) => const PlaylistScreen(),
      ),

      // ── Notes (overlays shell) ────────────────────────────────────────────
      GoRoute(
        path: '/notes',
        builder: (context, state) => const NotesScreen(),
      ),

      // ── Notifications feed (overlays shell; push deep-link target) ────────
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),

      // ── Profile (overlays shell) ──────────────────────────────────────────
      GoRoute(
        path: '/profile/edit',
        builder: (context, state) => const EditProfileScreen(),
      ),

      // ── Admin console (overlays shell) ────────────────────────────────────
      GoRoute(
        path: '/admin',
        builder: (context, state) => const AdminHubScreen(),
      ),
      GoRoute(
        path: '/admin/announcements',
        builder: (context, state) => const AdminAnnouncementsScreen(),
      ),
      GoRoute(
        path: '/admin/events',
        builder: (context, state) => const AdminEventsScreen(),
      ),
      GoRoute(
        path: '/admin/branches',
        builder: (context, state) => const AdminBranchesScreen(),
      ),
      GoRoute(
        path: '/admin/users',
        builder: (context, state) => const AdminUsersScreen(),
      ),
      GoRoute(
        path: '/admin/bible-reading',
        builder: (context, state) => const AdminBibleReadingScreen(),
      ),
      GoRoute(
        path: '/admin/reading-plans',
        builder: (context, state) => const AdminReadingPlansScreen(),
      ),
      GoRoute(
        path: '/admin/sermons',
        builder: (context, state) => const AdminSermonsScreen(),
      ),
      GoRoute(
        path: '/admin/branches/:id',
        builder: (context, state) => AdminBranchDetailScreen(
          branchId: state.pathParameters['id']!,
          branchName: state.extra as String? ?? '',
        ),
      ),
    ],
  );

  ref.onDispose(router.dispose);
  return router;
});
