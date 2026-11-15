import 'package:flutter/widgets.dart';

import '../../theme/kharis_theme.dart';
import 'k_icon.dart';

/// A week of streak dots: seven 28 circles. A done day is filled with
/// highlight and carries a check, so it does not rest on colour alone.
class KStreakDots extends StatelessWidget {
  const KStreakDots({
    super.key,
    required this.days,
    required this.semanticLabel,
  });

  /// One entry per day, oldest first. True when the day is done.
  final List<bool> days;

  /// Read in place of the dots, for example "5 of 7 days this week".
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    assert(days.length == 7, 'A streak shows one week: seven days.');
    final k = context.k;

    return Semantics(
      container: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: Wrap(
        spacing: KSpace.sm,
        runSpacing: KSpace.sm,
        children: [
          for (final done in days)
            DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: done ? k.highlight : k.surface2,
              ),
              child: SizedBox.square(
                dimension: KSize.streakDot,
                child: done
                    ? Center(
                        child: KIcon(
                          KIcons.check,
                          size: KSize.iconXs,
                          color: k.onHighlight,
                        ),
                      )
                    : null,
              ),
            ),
        ],
      ),
    );
  }
}
