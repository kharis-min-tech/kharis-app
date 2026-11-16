import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../theme/kharis_theme.dart';
import 'k_icon.dart';

class KNavItem {
  const KNavItem({required this.label, required this.icon});

  final String label;
  /// One of the [KIcons] paths.
  final String icon;
}

/// Floating bottom nav: Home, Messages, Bible, More.
///
/// Place it in a Stack above the screen content (not in Scaffold.bottomNavigationBar),
/// and give scrolling content `KSize.contentBottomPad` of bottom padding.
class KFloatingNav extends StatelessWidget {
  const KFloatingNav({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
  });

  final List<KNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    const radius = BorderRadius.all(Radius.circular(KRadius.nav));
    // 18pt from the bottom, or the device safe area if that is larger.
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    final bottom = safeBottom > KSize.navInsetBottom ? safeBottom : KSize.navInsetBottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(KSize.navInsetX, 0, KSize.navInsetX, bottom),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: context.isDarkTheme ? KShadow.floatingDark : KShadow.floatingLight,
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: KSize.navBlur / 2, sigmaY: KSize.navBlur / 2),
            child: Container(
              height: KSize.navHeight,
              padding: const EdgeInsets.symmetric(horizontal: KSpace.sm),
              decoration: BoxDecoration(
                color: k.navBg,
                borderRadius: radius,
                border: Border.all(color: k.navBorder),
              ),
              child: Row(
                children: [
                  for (var i = 0; i < items.length; i++) ...[
                    if (i > 0) const SizedBox(width: KSpace.xs),
                    Expanded(
                      child: _NavTab(
                        item: items[i],
                        active: i == currentIndex,
                        onTap: () => onTap(i),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavTab extends StatelessWidget {
  const _NavTab({required this.item, required this.active, required this.onTap});

  final KNavItem item;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final color = active ? k.navActive : k.muted;
    const radius = BorderRadius.all(Radius.circular(KRadius.tile));

    return Semantics(
      button: true,
      selected: active,
      label: item.label,
      excludeSemantics: true,
      child: Material(
        color: active ? k.navActiveBg : Colors.transparent,
        borderRadius: radius,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: SizedBox(
            height: KSize.navItem,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                KIcon(item.icon, size: KSize.navIcon, color: color),
                const SizedBox(height: KSpace.xs),
                Text(
                  item.label,
                  maxLines: 1,
                  style: KharisText.small.copyWith(
                    color: color,
                    height: 1.0,
                    fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
