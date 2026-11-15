import 'package:flutter/material.dart';

import '../../theme/kharis_theme.dart';
import 'k_icon.dart';

/// The end of a chapter in the Bible reader: a round Previous button, the
/// "End of John 1" line and a round Next button. Next is the inverse one:
/// it is where most readers go.
class KChapterNav extends StatelessWidget {
  const KChapterNav({
    super.key,
    required this.label,
    this.previousLabel,
    this.nextLabel,
    this.onPrevious,
    this.onNext,
  });

  /// For example "End of John 1".
  final String label;

  /// The chapter before, for screen readers ("Genesis 50"); null with
  /// [onPrevious] at the start of the Bible.
  final String? previousLabel;
  final String? nextLabel;

  /// Null leaves that side empty.
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final k = context.k;

    return Row(
      children: [
        if (onPrevious == null)
          const SizedBox.square(dimension: KSize.touchMin)
        else
          _Step(
            key: const Key('bible-prev'),
            icon: KIcons.chevronLeft,
            label: previousLabel == null
                ? 'Previous chapter'
                : 'Previous chapter, $previousLabel',
            fill: k.surface,
            border: k.border,
            iconColor: k.text,
            onTap: onPrevious!,
          ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: KSpace.xl),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: KharisText.caption.copyWith(color: k.muted),
            ),
          ),
        ),
        if (onNext == null)
          const SizedBox.square(dimension: KSize.touchMin)
        else
          _Step(
            key: const Key('bible-next'),
            icon: KIcons.chevronRight,
            label: nextLabel == null
                ? 'Next chapter'
                : 'Next chapter, $nextLabel',
            fill: k.inverse,
            iconColor: k.onInverse,
            onTap: onNext!,
          ),
      ],
    );
  }
}

/// A 38 round button in a 44 hit area.
class _Step extends StatelessWidget {
  const _Step({
    super.key,
    required this.icon,
    required this.label,
    required this.fill,
    required this.iconColor,
    required this.onTap,
    this.border,
  });

  final String icon;
  final String label;
  final Color fill;
  final Color iconColor;
  final Color? border;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox.square(
          dimension: KSize.touchMin,
          child: Center(
            child: Material(
              color: fill,
              clipBehavior: Clip.antiAlias,
              shape: CircleBorder(
                side: border == null
                    ? BorderSide.none
                    : BorderSide(color: border!),
              ),
              child: InkWell(
                onTap: onTap,
                child: SizedBox.square(
                  dimension: KSize.toolbar,
                  child: Center(
                    child: KIcon(icon, size: KSize.iconSm, color: iconColor),
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
