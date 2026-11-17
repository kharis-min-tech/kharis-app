import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/calendar/data/event_repository.dart';
import '../../features/calendar/presentation/screens/calendar_screen.dart';
import '../../features/calendar/presentation/screens/event_detail_screen.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import '../../features/giving/presentation/screens/giving_screen.dart';
import '../../features/home/presentation/screens/branch_screen.dart';
import '../../features/home/presentation/screens/dashboard_shell.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/messages/presentation/screens/messages_screen.dart';
import '../../features/messages/presentation/screens/downloads_screen.dart';
import '../../features/messages/presentation/screens/listening_history_screen.dart';
import '../../features/messages/presentation/screens/message_search_screen.dart';
import '../../features/onboarding/presentation/screens/branch_selection_screen.dart';
import '../../features/onboarding/presentation/screens/login_screen.dart';
import '../../features/onboarding/presentation/screens/register_screen.dart';
import '../../features/onboarding/presentation/screens/role_selection_screen.dart';
import '../../features/onboarding/presentation/screens/splash_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/player/presentation/screens/full_player_screen.dart';
import '../../features/playlists/presentation/screens/favorites_screen.dart';
import '../../features/playlists/presentation/screens/playlist_detail_screen.dart';
import '../../features/playlists/presentation/screens/playlists_screen.dart';
import '../../features/bible/presentation/bible_routes.dart';
import '../../features/notes/presentation/screens/notes_screen.dart';
import '../../features/home/presentation/screens/notifications_screen.dart';
import '../../features/settings/presentation/screens/edit_profile_screen.dart';
import '../../features/settings/presentation/screens/notifications_settings_screen.dart';
import '../../features/shared_links/presentation/shared_link_screens.dart';
import '../../shared/providers/auth_provider.dart';
import '../../ui/gallery/component_gallery_screen.dart';

/// Central router as a Riverpod provider so [RouterNotifier] can drive
/// reactive redirects when auth state changes.
///
/// Redirects (see [RouterNotifier.redirect]):
///   - `/` (welcome) routes straight to the last tab once onboarding is
///     complete or the member is signed in.
///
/// Pushed routes (`/give`, `/calendar`, `/notifications`, `/announcements`,
/// `/branch`, `/events/:id`, ...) sit on the root navigator above the tab
/// shell and are meant to be PUSHED, so swipe back and the system back button
/// always return to the tab underneath. Each keeps the tab shell's nav
/// ([WithTabNav]) with the tab the member came from highlighted; only the
/// full player, onboarding, auth and the design check have none. Every route
/// uses the default page, whose transition supports the iOS swipe-back
/// gesture.
final appRouterProvider = Provider<GoRouter>((ref) {
  final notifier = ref.read(routerNotifierProvider);
  // The shell hides the nav while a sheet is open on any navigator.
  final openSheets = ref.read(openSheetsProvider);

  final router = GoRouter(
    initialLocation: '/',
    refreshListenable: notifier,
    redirect: notifier.redirect,
    observers: [
      SheetObserver(openSheets),
      // Screen-view analytics; no-op when Firebase isn't initialized.
      if (Firebase.apps.isNotEmpty)
        FirebaseAnalyticsObserver(analytics: FirebaseAnalytics.instance),
    ],
    routes: [
      // ── Onboarding ────────────────────────────────────────────────────────
      GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
      GoRoute(
        path: '/role-selection',
        builder: (context, state) => const RoleSelectionScreen(),
      ),
      GoRoute(
        path: '/branch-selection',
        builder: (context, state) => const BranchSelectionScreen(),
      ),

      // ── Auth ──────────────────────────────────────────────────────────────
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),

      // ── Main app (shell with the floating nav): Home, Messages, Bible, More
      // Branch order matches kTabPaths and the nav's items.
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            DashboardShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            observers: [SheetObserver(openSheets)],
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            observers: [SheetObserver(openSheets)],
            routes: [
              GoRoute(
                path: '/messages',
                builder: (context, state) => const MessagesScreen(),
                // Shared message links (/m/:id redirects here) open inside
                // the Messages tab so the shell is never torn down.
                routes: [
                  GoRoute(
                    path: 'search',
                    builder: (context, state) => const MessageSearchScreen(),
                  ),
                  sharedMessageRoute,
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            observers: [SheetObserver(openSheets)],
            routes: [
              // Bible: the landing screen, today's reading, the reader,
              // Highlights and My notes.
              bibleTabRoute,
            ],
          ),
          StatefulShellBranch(
            observers: [SheetObserver(openSheets)],
            routes: [
              GoRoute(
                path: '/more',
                builder: (context, state) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),

      // ── Events list (pushed; event pushes and Home's "See all") ───────────
      _navPage('/calendar', (state) => const CalendarScreen()),

      // ── Give (pushed). /giving is the old tab path, kept for saved links ──
      giveRoute(),
      GoRoute(path: '/giving', redirect: (context, state) => '/give'),

      // ── Listening history and downloads (pushed) ──────────────────────────
      _navPage('/history', (state) => const ListeningHistoryScreen()),
      _navPage('/downloads', (state) => const DownloadsScreen()),

      // ── Full player (a full-screen sheet over the shell, no nav) ──────────
      GoRoute(
        path: '/player',
        builder: (context, state) => const FullPlayerScreen(),
      ),

      // ── /reading and /highlights land in the Bible tab ────────────────────
      ...bibleRedirectRoutes,

      // ── Playlists (pushed) ────────────────────────────────────────────────
      // The member's own playlists. Home and detail are both pushed routes on
      // the root navigator, so the shell tab underneath stays intact and back
      // always exits, never replacing tab content.
      _navPage(
        '/playlists',
        (state) => const PlaylistsScreen(),
        routes: [
          _navPage(
            ':id',
            (state) =>
                PlaylistDetailScreen(playlistId: state.pathParameters['id']!),
          ),
        ],
      ),

      // ── Favorites (pushed) ────────────────────────────────────────────────
      // Hearted messages: the quick go-to, separate from playlists. Pushed
      // from More and the top of Playlists, so back always exits.
      _navPage('/favorites', (state) => const FavoritesScreen()),

      // ── Notes (pushed) ────────────────────────────────────────────────────
      _navPage('/notes', (state) => const NotesScreen()),

      // ── Notifications feed (pushed; push deep-link target) ────────────────
      _navPage('/notifications', (state) => const NotificationsScreen()),

      // ── Announcements feed (Home "See all"; announcement push target) ─────
      // `?id=` opens that announcement's detail as soon as it is loaded.
      _navPage(
        '/announcements',
        (state) => NotificationsScreen.announcements(
          focusId: state.uri.queryParameters['id'],
        ),
      ),

      // ── Branch (Home "Next service" card): full timetable ─────────────────
      _navPage('/branch', (state) => const BranchScreen()),

      // ── Event detail (cards, linked announcements, event pushes) ──────────
      // `extra` may carry the already-loaded [Event] so the screen paints
      // instantly; the screen still re-reads the doc by id.
      _navPage(
        '/events/:id',
        (state) => EventDetailScreen(
          eventId: state.pathParameters['id']!,
          initial: state.extra is Event ? state.extra as Event : null,
        ),
      ),

      // ── Shared links: /m/:id, /e/:id, /a/:id (see AppLinks) ───────────────
      ...sharedLinkRoutes,

      // ── Profile (pushed) ──────────────────────────────────────────────────
      _navPage('/profile/edit', (state) => const EditProfileScreen()),

      // ── Notification settings (More's Notifications row) ──────────────────
      _navPage(
        '/settings/notifications',
        (state) => const NotificationsSettingsScreen(),
      ),

      // ── Design check (debug builds only; never ships in release) ──────────
      if (kDebugMode)
        GoRoute(
          path: '/design',
          builder: (context, state) => const ComponentGalleryScreen(),
        ),
    ],
  );

  ref.onDispose(router.dispose);
  return router;
});

/// Give (`/give`): the tab nav stays, the mini player does not (KA-001: it
/// crowded the bank details).
GoRoute giveRoute() =>
    _navPage('/give', (state) => const GivingScreen(), showMiniPlayer: false);

/// A page pushed above the tab shell that keeps the shell's nav.
GoRoute _navPage(
  String path,
  Widget Function(GoRouterState state) page, {
  bool showMiniPlayer = true,
  List<RouteBase> routes = const [],
}) => GoRoute(
  path: path,
  builder: (context, state) =>
      WithTabNav(showMiniPlayer: showMiniPlayer, child: page(state)),
  routes: routes,
);
