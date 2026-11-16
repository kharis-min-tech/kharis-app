import 'package:flutter/material.dart';

import '../../theme/kharis_theme.dart';
import 'k_layout.dart';
import 'k_thumbnail.dart';

/// The one hero of a screen: an image that fills the card, an ink gradient
/// over its lower part, and on it an overline, a headline and the actions.
/// Use at most one per screen.
///
/// At the design size the gradient runs from clear at 42% of the card to
/// solid ink at 76%. It is tied to the text, not to the card: however long
/// the title or large the text, the words start halfway down the fade and
/// everything below them is solid ink.
///
/// [compact] is the short form (Bible's "Continue reading"): 170 tall, the
/// overline at the top, the title at the bottom left and the button at the
/// end of the title's row, over ink that fades out towards the right.
class KHeroCard extends StatelessWidget {
  const KHeroCard({
    super.key,
    required this.title,
    required this.primaryAction,
    this.overline,
    this.meta,
    this.image,
    this.imageSemanticLabel,
    this.secondaryActions = const [],
    this.fullBleed = false,
    this.compact = false,
  });

  final String title;

  /// The screen's primary button. It takes the free width; in the compact
  /// form it keeps its own width at the end of the title's row.
  final Widget primaryAction;

  /// Small eyebrow above the title, shown in uppercase.
  final String? overline;
  final String? meta;

  /// Null shows the surface2 placeholder.
  final ImageProvider? image;

  /// Alt text for the image. Leave null when the title says it all.
  final String? imageSemanticLabel;

  /// Icon buttons after the primary action, such as Download.
  final List<Widget> secondaryActions;

  /// Square corners, for a hero that runs edge to edge at the top of a
  /// screen. Otherwise the card takes the card radius.
  final bool fullBleed;

  /// The short form: see the class comment.
  final bool compact;

  /// Height of the fade from clear to solid ink.
  static const double _fade =
      (KRatio.heroGradientEnd - KRatio.heroGradientStart) * KSize.hero;

  /// Height of the compact form at the design text size.
  static const double _compactHeight = 170;

  /// The compact form's ink, left to right: nearly solid under the words,
  /// thinner by the middle, clear at the far edge.
  static const double _compactInkStart = 0.92;
  static const double _compactInkMiddle = 0.55;
  static const double _compactInkMiddleStop = 0.55;

  @override
  Widget build(BuildContext context) {
    final k = context.k;

    return ClipRRect(
      borderRadius: fullBleed
          ? BorderRadius.zero
          : const BorderRadius.all(Radius.circular(KRadius.card)),
      child: Stack(
        children: [
          Positioned.fill(
            child: KImageFill(image: image, semanticLabel: imageSemanticLabel),
          ),
          if (compact) ...[
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      k.ink.withValues(alpha: _compactInkStart),
                      k.ink.withValues(alpha: _compactInkMiddle),
                      kClear(k.ink),
                    ],
                    stops: const [0, _compactInkMiddleStop, 1],
                  ),
                ),
              ),
            ),
            _compactContent(context),
          ] else
            ConstrainedBox(
              constraints: BoxConstraints(
                // The card grows with the text so the image keeps its share.
                minHeight: MediaQuery.textScalerOf(context).scale(KSize.hero),
                minWidth: double.infinity,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CustomPaint(
                    painter: _InkFadePainter(ink: k.ink, fade: _fade),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        KSpace.gutter,
                        _fade / 2,
                        KSpace.gutter,
                        KSpace.gutter,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (overline != null) ...[
                            _overline(context),
                            const SizedBox(height: KSpace.sm),
                          ],
                          _title(context, KharisText.headline),
                          if (meta != null) ...[
                            const SizedBox(height: KSpace.xs),
                            _meta(context),
                          ],
                          const SizedBox(height: KSpace.x3),
                          Row(
                            children: [
                              Expanded(child: primaryAction),
                              for (final action in secondaryActions) ...[
                                const SizedBox(width: KSpace.md),
                                action,
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // On ink the eyebrow takes onInk: primaryText is tuned for light surfaces
  // and is too dim here.
  Widget _overline(BuildContext context) => Text(
    overline!.toUpperCase(),
    semanticsLabel: overline,
    style: KharisText.overline.copyWith(color: context.k.onInk),
  );

  Widget _title(BuildContext context, TextStyle style) => Semantics(
    header: true,
    child: Text(
      title,
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
      style: style.copyWith(color: context.k.onInk),
    ),
  );

  Widget _meta(BuildContext context) =>
      Text(meta!, style: KharisText.meta.copyWith(color: context.k.onInk));

  Widget _compactContent(BuildContext context) {
    final words = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _title(context, KharisText.pageTitle),
        if (meta != null) ...[const SizedBox(height: KSpace.xs), _meta(context)],
      ],
    );
    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        primaryAction,
        for (final action in secondaryActions) ...[
          const SizedBox(width: KSpace.md),
          action,
        ],
      ],
    );

    return ConstrainedBox(
      constraints: BoxConstraints(
        minHeight: MediaQuery.textScalerOf(context).scale(_compactHeight),
        minWidth: double.infinity,
      ),
      child: Padding(
        padding: const EdgeInsets.all(KSpace.x3),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (overline != null) _overline(context),
            const SizedBox(height: KSpace.x3),
            // At large text the button drops below the title, so neither
            // is squeezed.
            if (kIsLargeText(context))
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [words, const SizedBox(height: KSpace.xl), actions],
              )
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(child: words),
                  const SizedBox(width: KSpace.xl),
                  actions,
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// Paints the hero's ink: a fade from clear to solid over the first [fade]
/// pixels, then solid ink to the bottom.
class _InkFadePainter extends CustomPainter {
  const _InkFadePainter({required this.ink, required this.fade});

  final Color ink;
  final double fade;

  @override
  void paint(Canvas canvas, Size size) {
    // One gradient over the whole block, so there is no seam where the fade
    // meets the solid ink.
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [kClear(ink), ink],
          stops: [0, (fade / size.height).clamp(0.0, 1.0)],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_InkFadePainter old) => old.ink != ink || old.fade != fade;
}
