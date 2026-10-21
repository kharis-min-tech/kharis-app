import 'package:flutter/gestures.dart' show kTouchSlop;
import 'package:flutter/material.dart';

/// Wraps [child] in a subtle scale + opacity press animation.
///
/// Uses a [Listener] (not GestureDetector) for pointer events so inner
/// widgets (ElevatedButton, InkWell, etc.) still receive their own taps
/// without gesture-arena conflicts.
///
/// The press shows only for a real press: once the finger travels past the
/// touch slop (a scroll starting on the card) it lets go at once, so a list
/// never drags shrunken cards around. With reduced motion it dims without
/// scaling.
///
/// Provide [onTap] only when PressEffect should own the tap; omit it when
/// the child already handles taps.
class PressEffect extends StatefulWidget {
  const PressEffect({
    super.key,
    required this.child,
    this.onTap,
    this.disabled = false,
  });

  final Widget child;
  final VoidCallback? onTap;
  final bool disabled;

  @override
  State<PressEffect> createState() => _PressEffectState();
}

class _PressEffectState extends State<PressEffect> {
  bool _pressed = false;
  Offset? _down;

  void _press(PointerDownEvent e) {
    _down = e.position;
    setState(() => _pressed = true);
  }

  void _move(PointerMoveEvent e) {
    final down = _down;
    if (_pressed && down != null && (e.position - down).distance > kTouchSlop) {
      _release();
    }
  }

  void _release([PointerEvent? _]) {
    _down = null;
    if (_pressed) setState(() => _pressed = false);
  }

  @override
  Widget build(BuildContext context) {
    final active = !widget.disabled;
    final still = MediaQuery.disableAnimationsOf(context);
    return Listener(
      onPointerDown: active ? _press : null,
      onPointerMove: active ? _move : null,
      onPointerUp: active ? _release : null,
      onPointerCancel: active ? _release : null,
      child: GestureDetector(
        onTap: (active && widget.onTap != null) ? widget.onTap : null,
        child: AnimatedScale(
          key: const Key('press-effect-scale'),
          scale: _pressed && !still ? 0.97 : 1.0,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: AnimatedOpacity(
            opacity: _pressed ? 0.85 : 1.0,
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
