import 'package:flutter/widgets.dart';

import '../../theme/kharis_theme.dart';

/// A 4px progress bar: primary on a surface2 track.
class KProgressBar extends StatelessWidget {
  const KProgressBar({
    super.key,
    required this.value,
    this.semanticLabel,
    this.rounded = true,
  });

  /// From 0 to 1. Values outside that range are clamped.
  final double value;

  /// For example "Listened". Read with the percentage. Leave null when the
  /// text beside the bar already says how far along it is.
  final String? semanticLabel;

  /// False for a bar that runs along the edge of a card.
  final bool rounded;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final progress = value.clamp(0.0, 1.0);

    final bar = ClipRRect(
      borderRadius: rounded
          ? const BorderRadius.all(Radius.circular(KRadius.xs))
          : BorderRadius.zero,
      child: SizedBox(
        width: double.infinity,
        height: KSize.progress,
        child: ColoredBox(
          color: k.surface2,
          child: FractionallySizedBox(
            alignment: AlignmentDirectional.centerStart,
            widthFactor: progress,
            heightFactor: 1,
            child: ColoredBox(color: k.primary),
          ),
        ),
      ),
    );

    if (semanticLabel == null) return ExcludeSemantics(child: bar);
    return Semantics(
      label: semanticLabel,
      value: '${(progress * 100).round()}%',
      child: bar,
    );
  }
}
