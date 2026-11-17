import 'package:flutter/material.dart';

import '../../theme/kharis_theme.dart';
import 'k_layout.dart' show kClear;

/// An on/off switch. On: primary track with the thumb on the right; off:
/// surface2 track with the thumb on the left, so state never rests on colour
/// alone. The visible track is 48×28 inside a 44-tall touch target, and the
/// state is exposed to screen readers as a toggle.
///
/// Give [semanticLabel] when the switch stands alone; inside a row that
/// already reads its own title (wrapped in `MergeSemantics`), leave it null.
class KSwitch extends StatelessWidget {
  const KSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.semanticLabel,
  });

  final bool value;

  /// Null disables the switch (shown at 40% opacity).
  final ValueChanged<bool>? onChanged;
  final String? semanticLabel;

  static const double _trackWidth = 48;
  static const double _trackHeight = 28;
  static const double _thumb = 20;
  static const double _inset = (_trackHeight - _thumb) / 2;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final enabled = onChanged != null;
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : KMotion.fast;

    return Semantics(
      toggled: value,
      enabled: enabled,
      label: semanticLabel,
      onTap: enabled ? () => onChanged!(!value) : null,
      excludeSemantics: true,
      child: Opacity(
        opacity: enabled ? 1 : KRatio.disabled,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: enabled ? () => onChanged!(!value) : null,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: _trackWidth,
              minHeight: KSize.touchMin,
            ),
            child: Center(
              widthFactor: 1,
              heightFactor: 1,
              child: AnimatedContainer(
                duration: duration,
                width: _trackWidth,
                height: _trackHeight,
                padding: const EdgeInsets.all(_inset),
                decoration: BoxDecoration(
                  color: value ? k.primary : k.surface2,
                  borderRadius: const BorderRadius.all(
                    Radius.circular(_trackHeight / 2),
                  ),
                  // Kept, but invisible, so the thumb does not shift.
                  border: Border.all(color: value ? kClear(k.line) : k.line),
                ),
                child: AnimatedAlign(
                  duration: duration,
                  alignment: value
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: value ? k.onPrimary : k.muted,
                      shape: BoxShape.circle,
                    ),
                    child: const SizedBox.square(dimension: _thumb - 2),
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
