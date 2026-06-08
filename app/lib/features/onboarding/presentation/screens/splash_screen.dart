import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kharis_app/core/theme/app_colors.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _glowController;
  late final Animation<double> _glowScale;
  late final Animation<double> _glowOpacity;

  late final AnimationController _entryController;
  late final Animation<double> _entryOpacity;
  late final Animation<double> _entryScale;

  @override
  void initState() {
    super.initState();

    // Glow pulse — loops
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _glowScale = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    _glowOpacity = Tween<double>(begin: 0.3, end: 0.7).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    // Entry fade-in (content) — runs once
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..forward();

    _entryOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _entryController, curve: Curves.easeOut),
    );

    _entryScale = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _entryController, curve: Curves.easeOut),
    );

    // Navigate after 2.5 seconds
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) {
        context.go('/role-selection');
      }
    });
  }

  @override
  void dispose() {
    _glowController.dispose();
    _entryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceDark,
      body: Center(
        child: FadeTransition(
          opacity: _entryOpacity,
          child: ScaleTransition(
            scale: _entryScale,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _GlowingDove(
                  glowScale: _glowScale,
                  glowOpacity: _glowOpacity,
                ),
                const SizedBox(height: 28),
                Text(
                  'KHARIS',
                  style: GoogleFonts.mavenPro(
                    color: AppColors.textPrimary,
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 8,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Changing the world with a touch of His grace',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.dmSans(
                    color: AppColors.textBody,
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GlowingDove extends StatelessWidget {
  const _GlowingDove({
    required this.glowScale,
    required this.glowOpacity,
  });

  final Animation<double> glowScale;
  final Animation<double> glowOpacity;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      height: 160,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Radial glow behind the dove
          AnimatedBuilder(
            animation: Listenable.merge([glowScale, glowOpacity]),
            builder: (context, _) {
              return Transform.scale(
                scale: glowScale.value,
                child: Opacity(
                  opacity: glowOpacity.value,
                  child: Container(
                    width: 160,
                    height: 160,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          AppColors.purple,
                          AppColors.purple.withValues(alpha: 0.4),
                          AppColors.purple.withValues(alpha: 0.0),
                        ],
                        stops: const [0.0, 0.45, 1.0],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          // Dove icon
          CustomPaint(
            size: const Size(72, 72),
            painter: _DovePainter(color: AppColors.purple),
          ),
        ],
      ),
    );
  }
}

/// Minimal stylised dove silhouette drawn with paths.
class _DovePainter extends CustomPainter {
  const _DovePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final w = size.width;
    final h = size.height;

    // Body
    final bodyPath = Path()
      ..moveTo(w * 0.50, h * 0.38)
      ..cubicTo(w * 0.28, h * 0.30, w * 0.08, h * 0.45, w * 0.12, h * 0.62)
      ..cubicTo(w * 0.15, h * 0.74, w * 0.30, h * 0.78, w * 0.42, h * 0.72)
      ..cubicTo(w * 0.50, h * 0.68, w * 0.56, h * 0.70, w * 0.62, h * 0.76)
      ..cubicTo(w * 0.70, h * 0.84, w * 0.80, h * 0.80, w * 0.82, h * 0.70)
      ..cubicTo(w * 0.85, h * 0.55, w * 0.72, h * 0.42, w * 0.50, h * 0.38)
      ..close();
    canvas.drawPath(bodyPath, paint);

    // Left wing
    final leftWing = Path()
      ..moveTo(w * 0.42, h * 0.50)
      ..cubicTo(w * 0.28, h * 0.32, w * 0.05, h * 0.28, w * 0.05, h * 0.44)
      ..cubicTo(w * 0.05, h * 0.52, w * 0.20, h * 0.56, w * 0.38, h * 0.58)
      ..close();
    canvas.drawPath(leftWing, paint);

    // Right wing
    final rightWing = Path()
      ..moveTo(w * 0.58, h * 0.48)
      ..cubicTo(w * 0.72, h * 0.30, w * 0.95, h * 0.26, w * 0.95, h * 0.42)
      ..cubicTo(w * 0.95, h * 0.50, w * 0.80, h * 0.55, w * 0.62, h * 0.56)
      ..close();
    canvas.drawPath(rightWing, paint);

    // Head
    final headPath = Path()
      ..addOval(Rect.fromCenter(
        center: Offset(w * 0.50, h * 0.28),
        width: w * 0.22,
        height: h * 0.22,
      ));
    canvas.drawPath(headPath, paint);

    // Beak
    final beakPath = Path()
      ..moveTo(w * 0.50, h * 0.22)
      ..lineTo(w * 0.38, h * 0.18)
      ..lineTo(w * 0.46, h * 0.26)
      ..close();
    canvas.drawPath(beakPath, paint);

    // Tail
    final tailPath = Path()
      ..moveTo(w * 0.62, h * 0.72)
      ..cubicTo(w * 0.72, h * 0.82, w * 0.85, h * 0.90, w * 0.88, h * 0.82)
      ..cubicTo(w * 0.90, h * 0.76, w * 0.80, h * 0.68, w * 0.68, h * 0.68)
      ..close();
    canvas.drawPath(tailPath, paint);
  }

  @override
  bool shouldRepaint(_DovePainter old) => old.color != color;
}
