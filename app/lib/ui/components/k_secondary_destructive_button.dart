import 'package:flutter/material.dart';

import '../../theme/kharis_theme.dart';

/// The confirm button of an action that cannot be undone (delete account):
/// the `error` role with `onError` text, 48 tall. The label is a clear verb
/// naming what is destroyed. Never the first thing offered: it confirms a
/// choice the member has already made.
class KDestructiveButton extends StatelessWidget {
  const KDestructiveButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.expand = false,
  });

  final String label;

  /// Null disables the button (shown at 40% opacity).
  final VoidCallback? onPressed;

  /// Fill the available width.
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final button = TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        backgroundColor: k.error,
        foregroundColor: k.onError,
        disabledBackgroundColor: k.error,
        disabledForegroundColor: k.onError,
        minimumSize: const Size(KSize.touchMin, KSize.button),
        padding: const EdgeInsets.symmetric(horizontal: KSpace.x3),
        textStyle: KharisText.button,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(KRadius.button)),
        ),
      ),
      child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
    );

    return Opacity(
      opacity: onPressed == null ? KRatio.disabled : 1,
      child: expand ? SizedBox(width: double.infinity, child: button) : button,
    );
  }
}
