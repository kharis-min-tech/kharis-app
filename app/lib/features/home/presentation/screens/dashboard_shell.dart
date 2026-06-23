import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:kharis_app/core/theme/app_colors.dart';
import 'package:kharis_app/core/theme/app_typography.dart';
import 'package:kharis_app/shared/providers/audio_provider.dart';
import 'package:kharis_app/features/player/presentation/widgets/mini_player.dart';

/// Bottom-nav shell wrapping all 5 dashboard tabs.
///
/// Uses [StatefulNavigationShell] from [StatefulShellRoute.indexedStack] so
/// every branch gets its own navigator and state is preserved between tab
/// switches. Custom tab bar replaces the Material BottomNavigationBar with a
/// gradient + BackdropFilter blur panel per spec.
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
    final safeBottom = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      extendBody: true,
      backgroundColor: AppColors.surfaceDark,
      body: widget.navigationShell,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (currentSermon != null) const MiniPlayer(),
          ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Color(0xF5131313), // rgba(19,19,19,.96)
                      Color(0xF5131313),
                    ],
                    stops: [0.0, 0.38, 1.0],
                  ),
                ),
                padding: EdgeInsets.fromLTRB(6, 10, 6, 26 + safeBottom),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _TabItem(
                      icon: Icons.home_outlined,
                      activeIcon: Icons.home,
                      label: 'Home',
                      index: 0,
                      currentIndex: widget.navigationShell.currentIndex,
                      onTap: _onTap,
                    ),
                    _TabItem(
                      icon: Icons.play_circle_outline,
                      activeIcon: Icons.play_circle,
                      label: 'Messages',
                      index: 1,
                      currentIndex: widget.navigationShell.currentIndex,
                      onTap: _onTap,
                    ),
                    _TabItem(
                      icon: Icons.volunteer_activism_outlined,
                      activeIcon: Icons.volunteer_activism,
                      label: 'Giving',
                      index: 2,
                      currentIndex: widget.navigationShell.currentIndex,
                      onTap: _onTap,
                    ),
                    _TabItem(
                      icon: Icons.calendar_today_outlined,
                      activeIcon: Icons.calendar_today,
                      label: 'Calendar',
                      index: 3,
                      currentIndex: widget.navigationShell.currentIndex,
                      onTap: _onTap,
                    ),
                    _TabItem(
                      icon: Icons.more_horiz,
                      activeIcon: Icons.more_horiz,
                      label: 'More',
                      index: 4,
                      currentIndex: widget.navigationShell.currentIndex,
                      onTap: _onTap,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Single tab item: icon 24 + label 10.5px w600.
/// Active color: [AppColors.secondary] (gold).
/// Inactive color: [AppColors.textFaint] (#6e6a70).
class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.index,
    required this.currentIndex,
    required this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int index;
  final int currentIndex;
  final void Function(int) onTap;

  @override
  Widget build(BuildContext context) {
    final isActive = index == currentIndex;
    final color = isActive ? AppColors.secondary : AppColors.textFaint;

    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: Semantics(
        label: label,
        selected: isActive,
        button: true,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isActive ? activeIcon : icon,
                size: 24,
                color: color,
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: AppTypography.labelMd.copyWith(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: color,
                  letterSpacing: 0,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
