import 'package:flutter/material.dart';

import '../../theme/kharis_theme.dart';
import 'k_icon.dart';

/// Filter or choice chip. Selected: inverse fill. Unselected: transparent
/// with a 1.5px line border. Chip rows scroll horizontally with an edge fade
/// (see [KChipRow]); they never wrap.
class KChip extends StatelessWidget {
  const KChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
    this.leading,
    this.showChevron = false,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  /// One of the [KIcons] paths.
  final String? leading;

  /// Adds a trailing chevron for chips that open a menu or sheet (Sort, Book...).
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final fg = selected ? k.onInverse : k.text;

    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? k.inverse : Colors.transparent,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(KRadius.chip)),
          side: selected ? BorderSide.none : BorderSide(color: k.line, width: 1.5),
        ),
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: KSize.chip),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: KSpace.xl),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (leading != null) ...[
                    KIcon(leading!, size: 16, color: fg),
                    const SizedBox(width: KSpace.sm),
                  ],
                  Text(
                    label,
                    style: KharisText.itemTitle.copyWith(fontWeight: FontWeight.w700, height: 1.0, color: fg),
                  ),
                  if (showChevron) ...[
                    const SizedBox(width: KSpace.xs),
                    KIcon(KIcons.chevronDown, size: 16, color: fg),
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

/// A horizontally scrolling row of chips that fades out at the right edge.
class KChipRow extends StatelessWidget {
  const KChipRow({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final bg = context.k.bg;
    return Stack(
      children: [
        SizedBox(
          height: KSize.chip,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: KSpace.gutter),
            itemCount: children.length,
            separatorBuilder: (_, _) => const SizedBox(width: KSpace.md),
            itemBuilder: (_, i) => children[i],
          ),
        ),
        Positioned(
          top: 0,
          bottom: 0,
          right: 0,
          width: 24,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [bg.withAlpha(0), bg]),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
