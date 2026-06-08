import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/onboarding/presentation/screens/splash_screen.dart';
import '../../features/onboarding/presentation/screens/role_selection_screen.dart';
import '../../features/onboarding/presentation/screens/branch_selection_screen.dart';

/// Central router for the Kharis app.
///
/// Onboarding: / -> /role-selection -> /branch-selection -> /home
/// Main: /home (bottom nav shell)
final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: [
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
    GoRoute(
      path: '/home',
      builder: (context, state) => const Scaffold(
        body: Center(child: Text('Home - coming next sprint')),
      ),
    ),
  ],
);
