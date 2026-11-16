import 'package:flutter/material.dart';

import '../../theme/kharis_theme.dart';
import 'k_icon.dart';

enum KButtonVariant {
  /// Main call to action. One per view.
  primary,

  /// Strong secondary action, such as "Save for offline".
  inverse,

  /// Soft action on the primary tint.
  tonal,

  /// Transparent with a 1.5px line border.
  outline,

  /// Text only, in primaryText.
  text,
}

enum KButtonSize {
  /// 48 tall.
  standard,

  /// 56 tall, for the main call to action at the bottom of a flow (Give).
  cta,
}

/// The only button in the app. See "Components > Actions" in the handoff doc.
class KButton extends StatelessWidget {
  const KButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = KButtonVariant.primary,
    this.size = KButtonSize.standard,
    this.icon,
    this.loading = false,
    this.expand = false,
  });

  final String label;

  /// Null disables the button (shown at 40% opacity).
  final VoidCallback? onPressed;
  final KButtonVariant variant;
  final KButtonSize size;
  /// One of the [KIcons] paths.
  final String? icon;

  /// Shows a spinner in place of the label and blocks taps. Width stays fixed.
  final bool loading;

  /// Fill the available width.
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final (Color bg, Color fg, BorderSide side) = switch (variant) {
      KButtonVariant.primary => (k.primary, k.onPrimary, BorderSide.none),
      KButtonVariant.inverse => (k.inverse, k.onInverse, BorderSide.none),
      KButtonVariant.tonal => (k.primaryTint, k.primaryText, BorderSide.none),
      KButtonVariant.outline => (Colors.transparent, k.text, BorderSide(color: k.line, width: 1.5)),
      KButtonVariant.text => (Colors.transparent, k.primaryText, BorderSide.none),
    };
    final height = size == KButtonSize.cta ? KSize.cta : KSize.button;

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          KIcon(icon!, size: 18, color: fg),
          const SizedBox(width: KSpace.md),
        ],
        Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis)),
      ],
    );

    final button = TextButton(
      onPressed: loading ? null : onPressed,
      style: TextButton.styleFrom(
        backgroundColor: bg,
        foregroundColor: fg,
        disabledBackgroundColor: bg,
        disabledForegroundColor: fg,
        minimumSize: Size(KSize.touchMin, height),
        padding: const EdgeInsets.symmetric(horizontal: KSpace.x3),
        textStyle: KharisText.button,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(KRadius.button)),
          side: side,
        ),
      ),
      child: loading
          ? Stack(
              alignment: Alignment.center,
              children: [
                Opacity(opacity: 0, child: content),
                Semantics(
                  label: '$label, loading',
                  child: SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: fg),
                  ),
                ),
              ],
            )
          : content,
    );

    return Opacity(
      opacity: onPressed == null && !loading ? 0.4 : 1.0,
      child: expand ? SizedBox(width: double.infinity, child: button) : button,
    );
  }
}
