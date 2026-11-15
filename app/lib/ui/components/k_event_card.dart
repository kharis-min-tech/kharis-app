import 'package:flutter/widgets.dart';

import '../../theme/kharis_theme.dart';
import 'k_card.dart';
import 'k_layout.dart';

/// An event: a date block on primaryTint, the title, a meta line and an
/// optional [KToggleButton] such as "Remind me". At large text sizes the
/// toggle moves under the text so nothing is squeezed.
class KEventCard extends StatelessWidget {
  const KEventCard({
    super.key,
    required this.month,
    required this.day,
    required this.title,
    this.meta,
    this.toggle,
    this.onTap,
    this.dateSemanticLabel,
  });

  /// Short month or weekday, for example "Nov".
  final String month;

  /// Day of the month, for example "15".
  final String day;
  final String title;

  /// For example "Kharis London · 19:00".
  final String? meta;

  /// Usually a [KToggleButton].
  final Widget? toggle;
  final VoidCallback? onTap;

  /// The date in full for screen readers, for example "Sunday 15 November".
  /// Defaults to the day and month as shown.
  final String? dateSemanticLabel;

  @override
  Widget build(BuildContext context) {
    final k = context.k;

    final date = Semantics(
      label: dateSemanticLabel ?? '$day $month',
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: k.primaryTint,
          borderRadius: const BorderRadius.all(Radius.circular(KRadius.tile)),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: KSize.dateBlockWidth,
            minHeight: KSize.dateBlockHeight,
          ),
          child: Padding(
            padding: const EdgeInsets.all(KSpace.xs),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  month,
                  style: KharisText.small.copyWith(color: k.primaryText),
                ),
                Text(
                  day,
                  style: KharisText.section.copyWith(color: k.primaryText),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: KharisText.title.copyWith(color: k.text),
        ),
        if (meta != null)
          Text(meta!, style: KharisText.meta.copyWith(color: k.muted)),
      ],
    );

    final stacked = toggle != null && kIsLargeText(context);

    return KCard(
      padding: const EdgeInsets.all(KSpace.xxl),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              date,
              const SizedBox(width: KSpace.xl),
              Expanded(child: text),
              if (toggle != null && !stacked) ...[
                const SizedBox(width: KSpace.md),
                toggle!,
              ],
            ],
          ),
          if (stacked) ...[const SizedBox(height: KSpace.md), toggle!],
        ],
      ),
    );
  }
}
