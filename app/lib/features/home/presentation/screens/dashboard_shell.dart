import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/shared/providers/audio_provider.dart';
import 'package:kharis_app/features/player/presentation/widgets/mini_player.dart';
import 'package:kharis_app/shared/providers/cache_provider.dart';
import 'package:kharis_app/shared/providers/sermon_provider.dart';

/// Bottom-nav shell wrapping all 5 dashboard tabs.
///
/// Uses [StatefulNavigationShell] from [StatefulShellRoute.indexedStack] so
/// every branch gets its own navigator and state is preserved between tab
/// switches. The tab bar follows the active theme: a `surface` bar with a
/// `divider` top hairline; the active tab is gold, inactive tabs are muted.
class DashboardShell extends ConsumerStatefulWidget {
  const DashboardShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<DashboardShell> createState() => _DashboardShellState();
}

class _DashboardShellState extends ConsumerState<DashboardShell> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _restoreMiniPlayer());
  }

  /// Restores the minimised player with the last-played sermon (paused at its
  /// saved position) so the user picks up where they left off.
  Future<void> _restoreMiniPlayer() async {
    final svc = ref.read(audioPlayerServiceProvider);
    if (svc.currentSermon != null) return;
    final recent = ref.read(cacheServiceProvider).getRecentlyPlayed();
    if (recent.isEmpty) return;
    final lastId = recent.first;
    try {
      final sermons = await ref.read(sermonsProvider.future);
      final match = sermons.where((s) => s.id == lastId);
      if (match.isNotEmpty && mounted && svc.currentSermon == null) {
        await svc.loadPaused(match.first);
      }
    } catch (_) {}
  }

  void _onTap(int index) {
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
    ref.read(cacheServiceProvider).cachePreference('last_tab', index);
  }

  @override
  Widget build(BuildContext context) {
    final currentSermon = ref.watch(currentSermonProvider);
    final safeBottom = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      extendBody: true,
      body: widget.navigationShell,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (currentSermon != null) const MiniPlayer(),
          Container(
            decoration: BoxDecoration(
              color: context.kc.surface,
              border: Border(
                top: BorderSide(color: context.kc.divider, width: 1),
              ),
            ),
            padding: EdgeInsets.fromLTRB(6, 10, 6, 12 + safeBottom),
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
                  label: 'Events',
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
        ],
      ),
    );
  }
}

/// Single tab item: icon 24 + label 10.5px w600.
/// Active color: `context.kc.accentInk` (gold).
/// Inactive color: `context.kc.muted`.
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
    final color = isActive ? context.kc.accentInk : context.kc.muted;

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
