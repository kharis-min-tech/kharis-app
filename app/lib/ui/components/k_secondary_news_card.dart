import 'package:flutter/widgets.dart';

import '../../theme/kharis_theme.dart';
import 'k_card.dart';
import 'k_icon.dart';

/// A branch news item in a list: the date block on primaryTint, the title,
/// a two-line snippet of the body and a link naming the action. The whole
/// card is one target and reads as one item.
class KAnnouncementCard extends StatelessWidget {
  const KAnnouncementCard({
    super.key,
    required this.month,
    required this.day,
    required this.title,
    required this.actionLabel,
    required this.onTap,
    this.snippet,
    this.dateSemanticLabel,
  });

  /// Short month, for example "Nov".
  final String month;

  /// Day of the month, for example "15".
  final String day;
  final String title;

  /// The start of the body. At most two lines are shown.
  final String? snippet;

  /// What tapping does, for example "Read more". Starts with a verb.
  final String actionLabel;
  final VoidCallback? onTap;

  /// How the date is read aloud; defaults to "[day] [month]".
  final String? dateSemanticLabel;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final date = dateSemanticLabel ?? '$day $month';

    return KCard(
      padding: const EdgeInsets.all(KSpace.xxl),
      onTap: onTap,
      semanticLabel: [
        title,
        date,
        ?snippet,
        actionLabel,
      ].join('. '),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: k.primaryTint,
              borderRadius: const BorderRadius.all(
                Radius.circular(KRadius.tile),
              ),
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
          const SizedBox(width: KSpace.xl),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: KharisText.title.copyWith(color: k.text),
                ),
                if (snippet != null) ...[
                  const SizedBox(height: KSpace.xxs),
                  Text(
                    snippet!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: KharisText.body.copyWith(color: k.muted),
                  ),
                ],
                const SizedBox(height: KSpace.md),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        actionLabel,
                        style: KharisText.link.copyWith(color: k.primaryText),
                      ),
                    ),
                    const SizedBox(width: KSpace.xxs),
                    KIcon(
                      KIcons.chevronRight,
                      size: KSize.iconXs,
                      color: k.primaryText,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
