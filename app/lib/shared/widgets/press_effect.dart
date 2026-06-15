import 'package:flutter/material.dart';

/// Wraps [child] in a subtle scale + opacity press animation.
///
/// Uses a [Listener] (not GestureDetector) for pointer events so inner
/// widgets (ElevatedButton, InkWell, etc.) still receive their own taps
/// without gesture-arena conflicts.
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

  @override
  Widget build(BuildContext context) {
    final active = !widget.disabled;
    return Listener(
      onPointerDown: active ? (_) => setState(() => _pressed = true) : null,
      onPointerUp: active ? (_) => setState(() => _pressed = false) : null,
      onPointerCancel: active ? (_) => setState(() => _pressed = false) : null,
      child: GestureDetector(
        onTap: (active && widget.onTap != null) ? widget.onTap : null,
        child: AnimatedScale(
          scale: _pressed ? 0.96 : 1.0,
          duration: const Duration(milliseconds: 80),
          curve: Curves.easeOut,
          child: AnimatedOpacity(
            opacity: _pressed ? 0.85 : 1.0,
            duration: const Duration(milliseconds: 80),
            curve: Curves.easeOut,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
