import 'package:flutter/material.dart';

import '../../theme/kharis_theme.dart';
import 'k_card.dart';
import 'k_circle_button.dart';
import 'k_icon.dart';
import 'k_progress_bar.dart';
import 'k_section_header.dart';
import 'k_thumbnail.dart';

/// One unfinished message, podcast or video.
class KContinueItem {
  const KContinueItem({
    required this.title,
    required this.meta,
    required this.progress,
    this.artwork,
    this.onPlay,
    this.onTap,
  });

  final String title;

  /// For example "Pastor David Antwi · 18 min left".
  final String meta;

  /// From 0 to 1.
  final double progress;

  /// Null shows the surface2 placeholder.
  final ImageProvider? artwork;
  final VoidCallback? onPlay;
  final VoidCallback? onTap;
}

/// The "Continue listening" section: a header with a History link and at
/// most three cards. Pass the items newest first; anything past the third is
/// left for the History list.
class KContinueListening extends StatelessWidget {
  const KContinueListening({
    super.key,
    required this.items,
    this.onHistory,
    this.title = 'Continue listening',
    this.historyLabel = 'History',
    this.playLabel = 'Play',
  });

  /// The most a screen ever shows.
  static const int maxItems = 3;

  final List<KContinueItem> items;

  /// Opens the full history. Null hides the link.
  final VoidCallback? onHistory;
  final String title;
  final String historyLabel;

  /// Read before the item title on each play button.
  final String playLabel;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final shown = items.take(maxItems).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        KSectionHeader(
          title: title,
          actionLabel: onHistory == null ? null : historyLabel,
          onAction: onHistory,
        ),
        for (var i = 0; i < shown.length; i++) ...[
          if (i > 0) const SizedBox(height: KSpace.md),
          KCard(
            padding: const EdgeInsets.all(KSpace.xl),
            onTap: shown[i].onTap,
            child: Row(
              children: [
                KThumbnail(image: shown[i].artwork, size: KSize.artwork),
                const SizedBox(width: KSpace.xl),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        shown[i].title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: KharisText.itemTitle.copyWith(color: k.text),
                      ),
                      const SizedBox(height: KSpace.xxs),
                      Text(
                        shown[i].meta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: KharisText.caption.copyWith(color: k.muted),
                      ),
                      const SizedBox(height: KSpace.md),
                      KProgressBar(value: shown[i].progress),
                    ],
                  ),
                ),
                const SizedBox(width: KSpace.md),
                KCircleButton(
                  icon: KIcons.play,
                  label: '$playLabel ${shown[i].title}',
                  onPressed: shown[i].onPlay,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
