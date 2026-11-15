import 'package:flutter/material.dart';

import '../../theme/kharis_theme.dart';
import 'k_icon.dart';
import 'k_section_header.dart';
import 'k_states.dart';

const double _statusDot = 7;

/// One cell of a [KStatsStrip]: an overline, the value, and a line under it
/// (a status with its dot, or a caption).
class KStat {
  const KStat({
    required this.label,
    required this.value,
    this.icon,
    this.caption,
    this.status,
    this.statusDone = false,
    this.semanticLabel,
    this.onTap,
    this.loading = false,
    this.key,
  });

  final String label;
  final String value;

  /// Shown before a numeric [value], in highlight.
  final String? icon;

  /// A muted line under the value ("day streak").
  final String? caption;

  /// A status line under the value ("Read", "Not read"), with a dot: the
  /// words carry the state, the dot only repeats it.
  final String? status;
  final bool statusDone;
  final String? semanticLabel;
  final VoidCallback? onTap;

  /// Blocks in place of the value and the line under it.
  final bool loading;
  final Key? key;
}

/// A floating card of two or three stats side by side, the first a little
/// wider. On Home it overlaps the bottom of the hero.
class KStatsStrip extends StatelessWidget {
  const KStatsStrip({super.key, required this.stats});

  final List<KStat> stats;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    const radius = BorderRadius.all(Radius.circular(KRadius.card));

    return DecoratedBox(
      decoration: BoxDecoration(
        color: k.surface,
        borderRadius: radius,
        border: Border.all(color: k.border),
        boxShadow: context.isDarkTheme
            ? KShadow.floatingDark
            : KShadow.floatingLight,
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Material(
          type: MaterialType.transparency,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, stat) in stats.indexed) ...[
                  if (i > 0) VerticalDivider(width: 1, color: k.line),
                  Expanded(
                    flex: i == 0 ? 5 : 4,
                    child: _Cell(stat, key: stat.key),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell(this.stat, {super.key});

  final KStat stat;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final numeric = stat.icon != null;

    final content = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: KSpace.xl,
        vertical: KSpace.xxl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          KOverline(stat.label),
          const SizedBox(height: KSpace.xs),
          if (stat.loading) ...[
            const KSkeleton(height: KSize.icon, radius: KRadius.xs),
            const SizedBox(height: KSpace.xs),
            const KSkeleton(
              width: KSize.artwork,
              height: KSize.iconXs,
              radius: KRadius.xs,
            ),
          ] else ...[
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (numeric) ...[
                  KIcon(
                    stat.icon!,
                    size: KSize.iconMd,
                    color: k.highlightText,
                  ),
                  const SizedBox(width: KSpace.xs),
                ],
                Flexible(
                  child: Text(
                    stat.value,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: (numeric ? KharisText.section : KharisText.title)
                        .copyWith(color: k.text),
                  ),
                ),
              ],
            ),
            const SizedBox(height: KSpace.xs),
            if (stat.status != null)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: stat.statusDone ? k.success : k.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const SizedBox.square(dimension: _statusDot),
                  ),
                  const SizedBox(width: KSpace.xs),
                  Flexible(
                    child: Text(
                      stat.status!,
                      style: KharisText.small.copyWith(
                        color: stat.statusDone ? k.text : k.primaryText,
                      ),
                    ),
                  ),
                ],
              )
            else if (stat.caption != null)
              Text(
                stat.caption!,
                style: KharisText.small.copyWith(color: k.muted),
              ),
          ],
        ],
      ),
    );

    return Semantics(
      container: true,
      button: stat.onTap != null,
      label: stat.semanticLabel,
      excludeSemantics: stat.semanticLabel != null,
      child: InkWell(onTap: stat.onTap, child: content),
    );
  }
}
