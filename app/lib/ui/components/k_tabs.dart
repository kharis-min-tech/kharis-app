import 'package:flutter/material.dart';

import '../../theme/kharis_theme.dart';
import 'k_layout.dart';

/// Text tabs that scroll sideways and fade at the right edge. Selected: text
/// colour with a 2px underline; the rest are muted.
class KTabs extends StatelessWidget {
  const KTabs({
    super.key,
    required this.tabs,
    required this.currentIndex,
    required this.onChanged,
  });

  final List<String> tabs;
  final int currentIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final k = context.k;

    return Stack(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: k.line)),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: KSpace.gutter),
            child: Row(
              children: [
                for (var i = 0; i < tabs.length; i++) ...[
                  if (i > 0) const SizedBox(width: KSize.tabGap),
                  _Tab(
                    label: tabs[i],
                    selected: i == currentIndex,
                    onTap: () => onChanged(i),
                  ),
                ],
              ],
            ),
          ),
        ),
        PositionedDirectional(
          top: 0,
          bottom: 0,
          end: 0,
          width: KSize.edgeFade,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: AlignmentDirectional.centerStart,
                  end: AlignmentDirectional.centerEnd,
                  colors: [kClear(k.bg), k.bg],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final k = context.k;

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: selected ? k.primary : kClear(k.primary),
                  width: KSize.tabUnderline,
                ),
              ),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minWidth: KSize.touchMin,
                minHeight: KSize.touchMin,
              ),
              child: Center(
                widthFactor: 1,
                child: Text(
                  label,
                  maxLines: 1,
                  style: KharisText.link.copyWith(
                    color: selected ? k.text : k.muted,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
