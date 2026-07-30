import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kharis_app/core/constants/app_assets.dart';
import 'package:kharis_app/core/theme/app_colors.dart';
import 'package:kharis_app/core/theme/app_radius.dart';
import 'package:kharis_app/core/theme/app_typography.dart';

/// Splash / brand entry (design-handoff v3).
///
/// Full-bleed worship photo under a purple→magenta gradient wash, centred dove
/// + "Kharis" wordmark + serif tagline, then a gold **Get started** CTA and a
/// "Log in with iKharis" row. Button-driven (no auto-advance) so returning
/// users are routed by the auth redirect and new users choose to begin.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entry = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..forward();

  @override
  void dispose() {
    _entry.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ink,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Full-bleed worship photo (natural colours).
          Image.asset(AppAssets.splashPink, fit: BoxFit.cover),

          // Purple wash at the top (behind the dove + wordmark) that fades into
          // the natural photo below; a soft dark scrim anchors the CTA text.
          DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xE64A2AA8), // deep purple, top
                  Color(0x995D3FD3), // purple ~60%
                  Color(0x1A5D3FD3), // purple ~10%
                  Color(0x00000000), // transparent — natural photo
                  Color(0x8C0B0A10), // soft ink ~55% for CTA/footer legibility
                ],
                stops: [0.0, 0.20, 0.36, 0.55, 1.0],
              ),
            ),
          ),

          SafeArea(
            child: FadeTransition(
              opacity: _entry,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(26, 24, 26, 30),
                child: Column(
                  children: [
                    const Spacer(flex: 3),
                    Image.asset(AppAssets.doveWhite, width: 96, height: 96),
                    const SizedBox(height: 18),
                    Text(
                      'Kharis',
                      style: AppTypography.display(size: 44, weight: FontWeight.w700)
                          .copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Changing the world with a touch of His Grace',
                      textAlign: TextAlign.center,
                      style: AppTypography.serif(
                        size: 17,
                        italic: true,
                        height: 1.4,
                      ).copyWith(color: const Color(0xFFE6DDFF)),
                    ),
                    const Spacer(flex: 4),

                    // Gold primary CTA.
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => context.go('/role-selection'),
                        child: const Text('Get started'),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Log in with iKharis.
                    _IKharisLoginRow(onTap: () => context.go('/login')),
                    const SizedBox(height: 20),

                    Text(
                      'Establishing believers · Strengthening churches',
                      textAlign: TextAlign.center,
                      style: AppTypography.labelMd.copyWith(
                        color: Colors.white.withValues(alpha: 0.6),
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IKharisLoginRow extends StatelessWidget {
  const _IKharisLoginRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.buttonBorder,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline_rounded, size: 18, color: Colors.white),
            const SizedBox(width: 8),
            Text(
              'Log in with iKharis',
              style: AppTypography.ui(size: 15, weight: FontWeight.w600)
                  .copyWith(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
