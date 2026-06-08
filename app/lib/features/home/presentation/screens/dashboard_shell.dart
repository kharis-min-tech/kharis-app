import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/providers/audio_provider.dart';
import '../../../player/presentation/widgets/mini_player.dart';

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
      backgroundColor: AppColors.surfaceDark,
      body: widget.navigationShell,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Mini player sits above the bottom nav when a sermon is loaded.
          if (currentSermon != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: const MiniPlayer(),
            ),
          // 1 px top separator
          Container(height: 1, color: AppColors.surfaceSubtle),
          BottomNavigationBar(
            currentIndex: widget.navigationShell.currentIndex,
            onTap: _onTap,
            backgroundColor: AppColors.surfaceElevated,
            selectedItemColor: AppColors.orange,
            unselectedItemColor: AppColors.textMuted,
            type: BottomNavigationBarType.fixed,
            elevation: 0,
            selectedLabelStyle: GoogleFonts.dmSans(
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
            unselectedLabelStyle: GoogleFonts.dmSans(
              fontSize: 10,
            ),
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home_rounded),
                activeIcon: Icon(Icons.home_rounded),
                label: 'Home',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.chat_bubble_outline_rounded),
                activeIcon: Icon(Icons.chat_bubble_rounded),
                label: 'Messages',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.favorite_border_rounded),
                activeIcon: Icon(Icons.favorite_rounded),
                label: 'Giving',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.calendar_today_rounded),
                activeIcon: Icon(Icons.calendar_today_rounded),
                label: 'Calendar',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.menu_rounded),
                activeIcon: Icon(Icons.menu_rounded),
                label: 'More',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
