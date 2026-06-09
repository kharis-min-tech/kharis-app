import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:kharis_app/shared/providers/audio_provider.dart';
import 'package:kharis_app/features/player/presentation/widgets/mini_player.dart';

/// Bottom-nav shell that wraps all 5 dashboard tabs.
///
/// Uses [StatefulNavigationShell] from [StatefulShellRoute.indexedStack] so
/// every branch gets its own navigator and state is preserved between tab
/// switches via an IndexedStack under the hood.
class DashboardShell extends ConsumerStatefulWidget {
  const DashboardShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<DashboardShell> createState() => _DashboardShellState();
}

class _DashboardShellState extends ConsumerState<DashboardShell> {
  void _onTap(int index) {
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentSermon = ref.watch(currentSermonProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF111014),
      body: widget.navigationShell,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Mini player sits above the bottom nav when a sermon is loaded.
          if (currentSermon != null) const MiniPlayer(),

          // Nav bar with dark gradient background matching Figma Group 30
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Color(0xFF111014)],
              ),
            ),
            child: BottomNavigationBar(
              currentIndex: widget.navigationShell.currentIndex,
              onTap: _onTap,
              backgroundColor: Colors.transparent,
              selectedItemColor: Colors.white,
              unselectedItemColor: const Color(0xFF8A8A8A),
              type: BottomNavigationBarType.fixed,
              elevation: 0,
              selectedLabelStyle: GoogleFonts.dmSans(
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: GoogleFonts.dmSans(
                fontSize: 10,
                fontWeight: FontWeight.w400,
              ),
              items: [
                BottomNavigationBarItem(
                  icon: const Icon(Icons.home_outlined),
                  activeIcon: const Icon(Icons.home),
                  label: 'Home',
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.play_circle_outline),
                  activeIcon: const Icon(Icons.play_circle),
                  label: 'Messages',
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.volunteer_activism_outlined),
                  activeIcon: const Icon(Icons.volunteer_activism),
                  label: 'Giving',
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.calendar_today_outlined),
                  activeIcon: const Icon(Icons.calendar_today),
                  label: 'Calendar',
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.more_horiz),
                  activeIcon: const Icon(Icons.more_horiz),
                  label: 'More',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
