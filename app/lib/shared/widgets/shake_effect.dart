import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Wraps [child] and exposes a [shake] method (access via [GlobalKey]).
///
/// Calling [shake] triggers a quick horizontal oscillation: 3 full cycles
/// of +/- 6 px over 400 ms, returning to zero naturally. Designed for
/// form-validation error feedback.
///
/// ```dart
/// final _shakeKey = GlobalKey<ShakeEffectState>();
///
/// ShakeEffect(key: _shakeKey, child: ...)
///
/// // on validation failure:
/// _shakeKey.currentState?.shake();
/// ```
class ShakeEffect extends StatefulWidget {
  const ShakeEffect({super.key, required this.child});

  final Widget child;

  @override
  State<ShakeEffect> createState() => ShakeEffectState();
}

class ShakeEffectState extends State<ShakeEffect>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Triggers one shake sequence (3 horizontal cycles, 400 ms total).
  void shake() {
    _controller
      ..reset()
      ..forward();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // sin(v * 6π) gives exactly 3 full cycles from 0→1, starting and
        // ending at 0 displacement — no visible jitter when animation is idle.
        final dx =
            math.sin(_controller.value * math.pi * 6) * 6.0;
        return Transform.translate(
          offset: Offset(dx, 0),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
