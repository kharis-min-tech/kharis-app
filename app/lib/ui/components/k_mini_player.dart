import 'package:flutter/material.dart';

import '../../theme/kharis_theme.dart';
import 'k_icon.dart';
import 'k_icon_button.dart';
import 'k_progress_bar.dart';
import 'k_thumbnail.dart';

/// The mini player: a floating surface card that sits above the nav, with
/// the artwork, the title, play or pause, close, and the progress along its
/// bottom edge. It only draws what it is given; playback lives elsewhere.
class KMiniPlayer extends StatelessWidget {
  const KMiniPlayer({
    super.key,
    required this.title,
    required this.progress,
    required this.playing,
    required this.onPlayPause,
    required this.onClose,
    this.subtitle,
    this.artwork,
    this.onTap,
    this.playLabel = 'Play',
    this.pauseLabel = 'Pause',
    this.closeLabel = 'Close player',
  });

  final String title;
  final String? subtitle;

  /// Null shows the surface2 placeholder.
  final ImageProvider? artwork;

  /// From 0 to 1.
  final double progress;
  final bool playing;
  final VoidCallback? onPlayPause;
  final VoidCallback? onClose;

  /// Opens the full player.
  final VoidCallback? onTap;
  final String playLabel;
  final String pauseLabel;
  final String closeLabel;

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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                onTap: onTap,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: KSize.listRow),
                  child: Padding(
                    padding: const EdgeInsetsDirectional.only(
                      start: KSpace.md,
                      end: KSpace.xs,
                    ),
                    child: Row(
                      children: [
                        KThumbnail(image: artwork),
                        const SizedBox(width: KSpace.lg),
                        Expanded(
                          child: MergeSemantics(
                            child: Semantics(
                              button: onTap != null,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: KharisText.itemTitle.copyWith(
                                      color: k.text,
                                    ),
                                  ),
                                  if (subtitle != null)
                                    Text(
                                      subtitle!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: KharisText.caption.copyWith(
                                        color: k.muted,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        KIconButton(
                          icon: playing ? KIcons.pause : KIcons.play,
                          label: playing ? pauseLabel : playLabel,
                          onPressed: onPlayPause,
                        ),
                        KIconButton(
                          icon: KIcons.close,
                          label: closeLabel,
                          onPressed: onClose,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              KProgressBar(value: progress, rounded: false),
            ],
          ),
        ),
      ),
    );
  }
}
