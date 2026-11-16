import 'package:flutter/material.dart';

import '../../theme/kharis_theme.dart';
import 'k_badge.dart';
import 'k_hero_card.dart';
import 'k_icon.dart';
import 'k_states.dart';

/// Where the hero's message is with being saved to the phone.
enum KMessageDownloadState { idle, downloading, done }

/// The featured message at the top of Messages: a [KHeroCard] with a badge
/// on the artwork, the title, one meta line, "Listen now", and the download
/// and add-to-collection buttons on glass.
class KMessageHero extends StatelessWidget {
  const KMessageHero({
    super.key,
    required this.title,
    required this.onListen,
    this.badge,
    this.meta,
    this.image,
    this.imageSemanticLabel,
    this.listenLabel = 'Listen now',
    this.onDownload,
    this.downloadState = KMessageDownloadState.idle,
    this.downloadProgress,
    this.downloadLabel = 'Download',
    this.onAddToCollection,
    this.addToCollectionLabel = 'Add to a collection',
    this.listenKey,
    this.downloadKey,
    this.addToCollectionKey,
  });

  final String title;

  /// For example "New · Part 3".
  final String? badge;

  /// For example "Pastor David Antwi · Sunday Service · 58 min".
  final String? meta;
  final ImageProvider? image;
  final String? imageSemanticLabel;

  /// Null disables the button.
  final VoidCallback? onListen;
  final String listenLabel;

  /// Null hides the download button.
  final VoidCallback? onDownload;
  final KMessageDownloadState downloadState;

  /// Fraction received while downloading; null spins.
  final double? downloadProgress;

  /// What the download button announces in its current state.
  final String downloadLabel;

  /// Null hides the button.
  final VoidCallback? onAddToCollection;
  final String addToCollectionLabel;

  final Key? listenKey;
  final Key? downloadKey;
  final Key? addToCollectionKey;

  /// Fill of the glass buttons, as a share of onInk.
  static const double _glass = 0.18;
  static const double _glassStrong = 0.32;

  @override
  Widget build(BuildContext context) {
    final k = context.k;

    return Stack(
      children: [
        KHeroCard(
          title: title,
          meta: meta,
          image: image,
          imageSemanticLabel: imageSemanticLabel,
          primaryAction: TextButton(
            key: listenKey,
            onPressed: onListen,
            style: TextButton.styleFrom(
              backgroundColor: k.onInk,
              foregroundColor: k.ink,
              disabledBackgroundColor: k.onInk.withValues(alpha: _glass),
              disabledForegroundColor: k.onInk,
              minimumSize: const Size(KSize.touchMin, KSize.button),
              padding: const EdgeInsets.symmetric(horizontal: KSpace.x3),
              textStyle: KharisText.button,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(KRadius.button)),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                KIcon(
                  KIcons.play,
                  size: KSize.iconSm,
                  color: onListen == null ? k.onInk : k.ink,
                ),
                const SizedBox(width: KSpace.md),
                Flexible(
                  child: Text(
                    listenLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          secondaryActions: [
            if (onDownload != null)
              _GlassButton(
                key: downloadKey,
                label: downloadLabel,
                value:
                    downloadState == KMessageDownloadState.downloading &&
                        downloadProgress != null
                    ? '${(downloadProgress! * 100).round()}%'
                    : null,
                strong: downloadState == KMessageDownloadState.done,
                onPressed: onDownload!,
                child: switch (downloadState) {
                  KMessageDownloadState.idle => KIcon(
                    KIcons.download,
                    color: k.onInk,
                  ),
                  KMessageDownloadState.done => KIcon(
                    KIcons.check,
                    color: k.onInk,
                  ),
                  KMessageDownloadState.downloading => SizedBox.square(
                    dimension: KSize.icon,
                    child: CircularProgressIndicator(
                      value: downloadProgress,
                      strokeWidth: KSize.tabUnderline,
                      color: k.onInk,
                      backgroundColor: k.onInk.withValues(alpha: _glass),
                    ),
                  ),
                },
              ),
            if (onAddToCollection != null)
              _GlassButton(
                key: addToCollectionKey,
                label: addToCollectionLabel,
                onPressed: onAddToCollection!,
                child: KIcon(KIcons.plus, color: k.onInk),
              ),
          ],
        ),
        if (badge != null)
          PositionedDirectional(
            top: KSpace.x3,
            start: KSpace.x3,
            end: KSpace.x3,
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: KBadge(badge!, variant: KBadgeVariant.live),
            ),
          ),
      ],
    );
  }
}

/// A square icon button on the hero's ink: onInk on a translucent fill.
class _GlassButton extends StatelessWidget {
  const _GlassButton({
    super.key,
    required this.label,
    required this.onPressed,
    required this.child,
    this.value,
    this.strong = false,
  });

  final String label;
  final String? value;
  final VoidCallback onPressed;
  final Widget child;

  /// A heavier fill, for a state that is on.
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      value: value,
      onTap: onPressed,
      excludeSemantics: true,
      child: Material(
        color: context.k.onInk.withValues(
          alpha: strong ? KMessageHero._glassStrong : KMessageHero._glass,
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(KRadius.button)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox.square(
            dimension: KSize.button,
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}

/// Stands in for a [KMessageHero] while the library loads.
class KMessageHeroSkeleton extends StatelessWidget {
  const KMessageHeroSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading',
      child: KSkeleton(
        height: MediaQuery.textScalerOf(context).scale(KSize.hero),
        radius: KRadius.card,
      ),
    );
  }
}
