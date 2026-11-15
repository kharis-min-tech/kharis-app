import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../theme/kharis_theme.dart';
import 'k_icon.dart';
import 'k_thumbnail.dart';
import 'k_layout.dart';

// Home's hero is the one place that sits on ink in both modes, so its
// fills are the ink roles at fixed strengths rather than surface roles.
const double _glass = 0.18;
const double _glassStrong = 0.32;
const double _pill = 0.45;
const double _softText = 0.86;
const double _backdropOpacity = 0.75;
const double _backdropBlur = 38;
const double _backdropBleed = 60;
const double _artwork = 156;
const double _dot = 8;

/// Home's "New from Sunday" hero: the newest message's artwork blurred
/// across an ink panel under an ink gradient, with the greeting row
/// ([header]) and the message ([message]) on top. Text always sits on the
/// gradient. Runs under the status bar; [bottomInset] is the room the card
/// overlapping its bottom edge needs.
class KHomeHero extends StatelessWidget {
  const KHomeHero({
    super.key,
    required this.header,
    this.message,
    this.backdrop,
    this.bottomInset = 0,
  });

  final Widget header;

  /// [KHeroMessage], [KHeroMessageSkeleton], or null when there is none.
  final Widget? message;

  /// The artwork blurred behind everything; ink alone when null.
  final ImageProvider? backdrop;

  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final top = MediaQuery.paddingOf(context).top;

    return ColoredBox(
      color: k.ink,
      child: Stack(
        children: [
          if (backdrop != null)
            Positioned.fill(
              child: ClipRect(
                child: ExcludeSemantics(
                  child: Opacity(
                    opacity: _backdropOpacity,
                    child: ImageFiltered(
                      imageFilter: ImageFilter.blur(
                        sigmaX: _backdropBlur,
                        sigmaY: _backdropBlur,
                        tileMode: TileMode.decal,
                      ),
                      child: Transform.scale(
                        // Bleeds past the edges so the blur has no rim.
                        scale: 1 + _backdropBleed / KSize.hero,
                        child: Image(
                          image: backdrop!,
                          fit: BoxFit.cover,
                          excludeFromSemantics: true,
                          errorBuilder: (_, _, _) => const SizedBox.expand(),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0, 0.38, 1],
                  colors: [
                    k.ink.withValues(alpha: 0.5),
                    k.ink.withValues(alpha: 0.25),
                    k.ink.withValues(alpha: 0.88),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              KSpace.gutter,
              top + KSpace.sm,
              KSpace.gutter,
              KSpace.gutter + bottomInset,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                header,
                if (message != null) ...[
                  const SizedBox(height: KSpace.sectionTop * 2),
                  message!,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The greeting line with the branch switcher under it, on ink.
class KHeroGreeting extends StatelessWidget {
  const KHeroGreeting({
    super.key,
    required this.greeting,
    required this.branchLabel,
    required this.branchSemanticLabel,
    required this.onBranch,
    this.branchKey,
  });

  final String greeting;
  final String branchLabel;
  final String branchSemanticLabel;
  final VoidCallback? onBranch;
  final Key? branchKey;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final soft = k.onInk.withValues(alpha: _softText);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          greeting,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: KharisText.button.copyWith(color: k.onInk),
        ),
        Semantics(
          button: true,
          label: branchSemanticLabel,
          onTap: onBranch,
          excludeSemantics: true,
          child: InkWell(
            key: branchKey,
            onTap: onBranch,
            borderRadius: const BorderRadius.all(
              Radius.circular(KRadius.button),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: KSize.touchMin),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  KIcon(KIcons.pin, size: KSize.iconXs, color: soft),
                  const SizedBox(width: KSpace.xs),
                  Flexible(
                    child: Text(
                      branchLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: KharisText.caption.copyWith(color: soft),
                    ),
                  ),
                  const SizedBox(width: KSpace.xs),
                  KIcon(KIcons.chevronDown, size: KSize.iconXs, color: soft),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A round 44 button on the hero: glass with an icon (and an unread
/// [dot]), or, with [initial], the member's avatar in primary.
class KHeroRoundButton extends StatelessWidget {
  const KHeroRoundButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.initial,
    this.dot = false,
    this.dotKey,
  }) : assert((icon == null) != (initial == null));

  final String label;
  final VoidCallback? onPressed;
  final String? icon;
  final String? initial;

  /// The unread dot at the top right, in highlight.
  final bool dot;
  final Key? dotKey;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final avatar = initial != null;

    return Semantics(
      button: true,
      label: label,
      onTap: onPressed,
      excludeSemantics: true,
      child: Material(
        color: avatar ? k.primary : k.onInk.withValues(alpha: _glass),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: SizedBox.square(
            dimension: KSize.touchMin,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (avatar)
                  Text(
                    initial!,
                    textScaler: TextScaler.noScaling,
                    style: KharisText.title.copyWith(color: k.onPrimary),
                  )
                else
                  KIcon(icon!, color: k.onInk),
                if (dot)
                  PositionedDirectional(
                    key: dotKey,
                    top: KSpace.lg,
                    end: KSpace.lg,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: k.highlightLight,
                        shape: BoxShape.circle,
                        border: Border.all(color: k.ink, width: KSize.outline),
                      ),
                      child: const SizedBox.square(dimension: _dot),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Where the hero's download button is.
enum KHeroDownloadState { idle, downloading, done }

/// The newest message on the hero: artwork, the badge, title, speaker and
/// meta lines, then Listen, Watch and the download button. A null callback
/// leaves that button out.
class KHeroMessage extends StatelessWidget {
  const KHeroMessage({
    super.key,
    required this.badge,
    required this.title,
    required this.lines,
    this.artwork,
    this.artworkSemanticLabel,
    this.onListen,
    this.onWatch,
    this.onDownload,
    this.downloadState = KHeroDownloadState.idle,
    this.downloadProgress,
    this.downloadLabel = 'Download',
    this.listenKey,
    this.watchKey,
    this.downloadKey,
  });

  final String badge;
  final String title;

  /// Speaker, then part and length; shown one per line.
  final List<String> lines;
  final ImageProvider? artwork;
  final String? artworkSemanticLabel;
  final VoidCallback? onListen;
  final VoidCallback? onWatch;
  final VoidCallback? onDownload;
  final KHeroDownloadState downloadState;

  /// 0–1 while downloading; null spins.
  final double? downloadProgress;
  final String downloadLabel;
  final Key? listenKey;
  final Key? watchKey;
  final Key? downloadKey;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    const tile = BorderRadius.all(Radius.circular(KRadius.tile));
    const chip = BorderRadius.all(Radius.circular(KRadius.chip));

    final art = ClipRRect(
      borderRadius: tile,
      child: SizedBox.square(
        dimension: _artwork,
        child: KImageFill(image: artwork, semanticLabel: artworkSemanticLabel),
      ),
    );

    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: k.ink.withValues(alpha: _pill),
            borderRadius: chip,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: KSpace.lg,
              vertical: KSpace.sm,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: k.highlightLight,
                    shape: BoxShape.circle,
                  ),
                  child: const SizedBox.square(dimension: _dot),
                ),
                const SizedBox(width: KSpace.md),
                Flexible(
                  child: Text(
                    badge.toUpperCase(),
                    semanticsLabel: badge,
                    style: KharisText.overline.copyWith(color: k.onInk),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: KSpace.md),
        Semantics(
          header: true,
          child: Text(
            title,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: KharisText.headline.copyWith(color: k.onInk),
          ),
        ),
        const SizedBox(height: KSpace.md),
        for (final line in lines)
          Text(
            line,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: KharisText.meta.copyWith(
              color: k.onInk.withValues(alpha: _softText),
            ),
          ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // At large text the title gets the full width, so long words are
        // not broken across lines beside the artwork.
        if (kIsLargeText(context)) ...[
          art,
          const SizedBox(height: KSpace.x3),
          text,
        ] else
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              art,
              const SizedBox(width: KSpace.x3),
              Expanded(child: text),
            ],
          ),
        const SizedBox(height: KSpace.x3),
        Wrap(
          spacing: KSpace.lg,
          runSpacing: KSpace.lg,
          children: [
            if (onListen != null)
              _HeroButton(
                key: listenKey,
                label: 'Listen',
                icon: KIcons.play,
                background: k.onInk,
                foreground: k.ink,
                onPressed: onListen!,
              ),
            if (onWatch != null)
              _HeroButton(
                key: watchKey,
                label: 'Watch',
                icon: KIcons.video,
                background: k.onInk.withValues(alpha: _glass),
                foreground: k.onInk,
                onPressed: onWatch!,
              ),
            if (onDownload != null)
              Semantics(
                button: true,
                label: downloadLabel,
                value:
                    downloadState == KHeroDownloadState.downloading &&
                        downloadProgress != null
                    ? '${(downloadProgress! * 100).round()}%'
                    : null,
                onTap: onDownload,
                excludeSemantics: true,
                child: Material(
                  key: downloadKey,
                  color: k.onInk.withValues(
                    alpha: downloadState == KHeroDownloadState.done
                        ? _glassStrong
                        : _glass,
                  ),
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(
                      Radius.circular(KRadius.button),
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: onDownload,
                    child: SizedBox.square(
                      dimension: KSize.button,
                      child: Center(
                        child: switch (downloadState) {
                          KHeroDownloadState.idle => KIcon(
                            KIcons.download,
                            color: k.onInk,
                          ),
                          KHeroDownloadState.done => KIcon(
                            KIcons.check,
                            color: k.onInk,
                          ),
                          KHeroDownloadState.downloading => SizedBox.square(
                            dimension: KSize.icon,
                            child: CircularProgressIndicator(
                              value: downloadProgress,
                              strokeWidth: KSize.tabUnderline,
                              color: k.onInk,
                              backgroundColor: k.onInk.withValues(
                                alpha: _glass,
                              ),
                            ),
                          ),
                        },
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _HeroButton extends StatelessWidget {
  const _HeroButton({
    super.key,
    required this.label,
    required this.icon,
    required this.background,
    required this.foreground,
    required this.onPressed,
  });

  final String label;
  final String icon;
  final Color background;
  final Color foreground;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        backgroundColor: background,
        foregroundColor: foreground,
        minimumSize: const Size(KSize.touchMin, KSize.button),
        padding: const EdgeInsets.symmetric(horizontal: KSpace.gutter),
        textStyle: KharisText.button,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(KRadius.button)),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          KIcon(icon, size: KSize.iconSm, color: foreground),
          const SizedBox(width: KSpace.md),
          Flexible(
            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}

/// The hero while the newest message is still loading: blocks where the
/// artwork, text and buttons will be, in the glass fill.
class KHeroMessageSkeleton extends StatelessWidget {
  const KHeroMessageSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final fill = context.k.onInk.withValues(alpha: _glass);
    Widget block({double? width, required double height}) => DecoratedBox(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: const BorderRadius.all(Radius.circular(KRadius.tile)),
      ),
      child: SizedBox(width: width, height: height),
    );

    return Semantics(
      label: 'Loading the latest message',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                block(width: _artwork, height: _artwork),
                const SizedBox(width: KSpace.x3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      block(width: KSize.artwork * 2, height: KSize.badge),
                      const SizedBox(height: KSpace.md),
                      block(height: KSize.toggle),
                      const SizedBox(height: KSpace.md),
                      block(width: KSize.artwork * 2, height: KSize.iconXs),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: KSpace.x3),
            block(width: _artwork, height: KSize.button),
          ],
        ),
      ),
    );
  }
}
