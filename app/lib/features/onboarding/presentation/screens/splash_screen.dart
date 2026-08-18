import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kharis_app/core/constants/app_assets.dart';
import 'package:kharis_app/core/theme/theme.dart';

/// Splash / brand entry (design-handoff v3).
///
/// Full-bleed worship photo in its own colours under a neutral legibility
/// scrim, centred dove
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
      // Deliberately theme-invariant: the splash is a full-bleed photo, so this
      // is only the base beneath the image — a light scaffold would flash white
      // before the asset decodes. Everything on top of the photo stays
      // white/light in both themes for the same reason.
      backgroundColor: AppColors.ink,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Full-bleed congregation photo, natural colours, no tint. Same
          // pre-cropped asset the native splash uses, so launch hands over to
          // this screen without a visible change.
          Image.asset(AppAssets.splashBg, fit: BoxFit.cover),

          // Neutral scrim only — no purple tint. The congregation photo is the
          // splash, so it reads in its own colours; these stops exist purely so
          // the dove, wordmark and CTAs stay legible over it. This also matches
          // the native splash, which is the same photo with no wash, making the
          // handover to Flutter invisible.
          DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x730B0A10), // ink ~45% behind status bar + wordmark
                  Color(0x260B0A10), // ink ~15%, fading out
                  Color(0x00000000), // clear — the photo's own colours
                  Color(0x9E0B0A10), // ink ~62% anchoring the CTA block
                ],
                stops: [0.0, 0.26, 0.5, 1.0],
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
