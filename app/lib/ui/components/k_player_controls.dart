import 'package:flutter/material.dart';

import '../../theme/kharis_theme.dart';
import 'k_button.dart';
import 'k_icon.dart';
import 'k_layout.dart';

/// One option of a [KSegmentedControl].
@immutable
class KSegment {
  const KSegment({
    required this.label,
    required this.semanticLabel,
    this.onTap,
    this.selected = false,
    this.enabled = true,
    this.tooltip,
  });

  final String label;

  /// What screen readers announce, for example "Switch to Video".
  final String semanticLabel;

  /// Null for the selected option and for one that is not available.
  final VoidCallback? onTap;
  final bool selected;

  /// False dims the option and announces it as unavailable.
  final bool enabled;

  /// Says why a disabled option is unavailable.
  final String? tooltip;
}

/// A segmented control: equal-width options on a surface2 track, the selected
/// one on a surface plate. The track is 44 tall, so every option is a full
/// touch target.
class KSegmentedControl extends StatelessWidget {
  const KSegmentedControl({super.key, required this.segments});

  final List<KSegment> segments;

  @override
  Widget build(BuildContext context) {
    final k = context.k;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: k.surface2,
        borderRadius: const BorderRadius.all(Radius.circular(KRadius.button)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(KSpace.xs),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final segment in segments)
                Expanded(child: _Segment(segment)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment(this.segment);

  final KSegment segment;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final selected = segment.selected;

    final plate = GestureDetector(
      onTap: segment.onTap,
      behavior: HitTestBehavior.opaque,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: selected ? k.surface : kClear(k.surface),
          borderRadius: const BorderRadius.all(Radius.circular(KRadius.chip)),
          border: Border.all(color: selected ? k.border : kClear(k.border)),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: KSize.toggle),
          child: Center(
            child: Opacity(
              opacity: segment.enabled ? 1 : KRatio.disabled,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: KSpace.md,
                  vertical: KSpace.xs,
                ),
                child: Text(
                  segment.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: KharisText.itemTitle.copyWith(
                    color: selected ? k.text : k.muted,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final node = Semantics(
      button: true,
      enabled: segment.enabled,
      selected: segment.enabled ? selected : null,
      label: segment.semanticLabel,
      onTap: segment.onTap,
      excludeSemantics: true,
      child: plate,
    );
    final tooltip = segment.tooltip;
    if (tooltip == null) return node;
    return Tooltip(message: tooltip, excludeFromSemantics: true, child: node);
  }
}

/// The round primary play or pause button of the full player: 56 across, a
/// spinner while the engine loads. The button stays live while loading, so a
/// stalled stream can still be paused.
class KPlayButton extends StatelessWidget {
  const KPlayButton({
    super.key,
    required this.playing,
    required this.onPressed,
    this.loading = false,
    this.playLabel = 'Play',
    this.pauseLabel = 'Pause',
    this.loadingLabel = 'Loading',
  });

  final bool playing;
  final bool loading;

  /// Null disables the button.
  final VoidCallback? onPressed;
  final String playLabel;
  final String pauseLabel;
  final String loadingLabel;

  @override
  Widget build(BuildContext context) {
    final k = context.k;

    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: playing ? pauseLabel : playLabel,
      value: loading ? loadingLabel : null,
      onTap: onPressed,
      excludeSemantics: true,
      child: Opacity(
        opacity: onPressed == null ? KRatio.disabled : 1,
        child: Material(
          color: k.primary,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            customBorder: const CircleBorder(),
            child: SizedBox.square(
              dimension: KSize.cta,
              child: Center(
                child: loading
                    ? SizedBox.square(
                        dimension: KSize.navIcon,
                        child: CircularProgressIndicator(
                          strokeWidth: KSize.tabUnderline,
                          color: k.onPrimary,
                        ),
                      )
                    : KIcon(
                        playing ? KIcons.pause : KIcons.play,
                        size: KSize.navIcon,
                        color: k.onPrimary,
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A transport button that shows a short text instead of an icon, such as
/// "−15" and "+30" for the time skips (the icon set has no glyph for them).
/// At least 44 square.
class KTransportTextButton extends StatelessWidget {
  const KTransportTextButton({
    super.key,
    required this.text,
    required this.label,
    required this.onPressed,
  });

  /// What the button shows.
  final String text;

  /// Announced by screen readers, for example "Back 15 seconds".
  final String label;

  /// Null disables the button.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final k = context.k;

    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: label,
      onTap: onPressed,
      excludeSemantics: true,
      child: Opacity(
        opacity: onPressed == null ? KRatio.disabled : 1,
        child: Material(
          type: MaterialType.transparency,
          clipBehavior: Clip.antiAlias,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(KRadius.button)),
          ),
          child: InkWell(
            onTap: onPressed,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minWidth: KSize.touchMin,
                minHeight: KSize.touchMin,
              ),
              child: Center(
                widthFactor: 1,
                heightFactor: 1,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: KSpace.xs),
                  child: Text(
                    text,
                    maxLines: 1,
                    style: KharisText.title.copyWith(color: k.text),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// An inline error: what went wrong on a surface plate outlined in the error
/// colour, with text actions (Retry) beneath when there are any.
class KErrorBanner extends StatelessWidget {
  const KErrorBanner({
    super.key,
    required this.message,
    this.actions = const <KBannerAction>[],
  });

  final String message;
  final List<KBannerAction> actions;

  @override
  Widget build(BuildContext context) {
    final k = context.k;

    return Semantics(
      container: true,
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: k.surface,
          borderRadius: const BorderRadius.all(Radius.circular(KRadius.tile)),
          border: Border.all(color: k.error, width: KSize.outline),
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            KSpace.xxl,
            KSpace.xl,
            KSpace.xxl,
            actions.isEmpty ? KSpace.xl : KSpace.xs,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(message, style: KharisText.meta.copyWith(color: k.text)),
              if (actions.isNotEmpty)
                Wrap(
                  alignment: WrapAlignment.end,
                  children: [
                    for (final action in actions)
                      KButton(
                        label: action.label,
                        onPressed: action.onPressed,
                        variant: KButtonVariant.text,
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A text action on a [KErrorBanner].
@immutable
class KBannerAction {
  const KBannerAction({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;
}
