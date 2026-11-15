import 'package:flutter/material.dart';

import 'package:kharis_app/theme/kharis_theme.dart';

/// Animated skeleton placeholder: a surface2 block with a slow opacity
/// pulse (1.1 s, 0.45 → 0.95). Drop-in replacement for loading spinners.
class Skeleton extends StatefulWidget {
  const Skeleton({
    super.key,
    required this.width,
    required this.height,
    this.radius = KRadius.tile,
  });

  final double width;
  final double height;
  final double radius;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 1100),
      vsync: this,
    )..repeat(reverse: true);
    _opacity = Tween<double>(begin: 0.45, end: 0.95).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // surface2; under a theme without the Kharis roles (screens not yet on
    // the redesign), Material's nearest role.
    final theme = Theme.of(context);
    final color =
        theme.extension<KharisColors>()?.surface2 ??
        theme.colorScheme.surfaceContainerHighest;
    return FadeTransition(
      opacity: _opacity,
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}

/// Convenience single-line skeleton.
class SkeletonLine extends StatelessWidget {
  const SkeletonLine({super.key, required this.width, this.height = 14});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Skeleton(width: width, height: height);
  }
}
