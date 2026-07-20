import 'package:flutter/material.dart';

import 'package:kharis_app/core/theme/app_colors.dart';

/// Layered backdrop for the welcome screen, matching the final design.
///
/// On the [AppColors.surfaceDark] screen, three layers stack back to front:
///   1. A warm orange radial glow pooled near the top, behind the hero.
///   2. A soft purple radial glow rising from the bottom edge.
///   3. A faint orange diagonal pinstripe texture for a premium, printed feel.
class OnboardingBackdrop extends StatelessWidget {
  const OnboardingBackdrop({super.key, required this.child});

  final Widget child;

  static const _gold = Color(0xFFFD7F20);

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.surfaceDark,
      child: Stack(
        children: [
          // Gold glow, upper third.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.84),
                  radius: 0.95,
                  colors: [
                    _gold.withValues(alpha: 0.16),
                    _gold.withValues(alpha: 0.04),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.4, 0.62],
                ),
              ),
            ),
          ),
          // Lavender glow, bottom edge.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, 1.0),
                  radius: 0.85,
                  colors: [
                    AppColors.primaryContainer.withValues(alpha: 0.14),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.65],
                ),
              ),
            ),
          ),
          // Diagonal pinstripe texture.
          const Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(painter: _PinstripePainter()),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _PinstripePainter extends CustomPainter {
  const _PinstripePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = OnboardingBackdrop._gold.withValues(alpha: 0.05)
      ..strokeWidth = 1;
    const gap = 39.0;
    // Lines lean up-to-the-right, approximating the 115deg print rhythm.
    for (double x = 0; x < size.width + size.height; x += gap) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x - size.height, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PinstripePainter oldDelegate) => false;
}
