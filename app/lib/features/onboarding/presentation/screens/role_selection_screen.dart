import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kharis_app/core/theme/app_colors.dart';
import 'package:kharis_app/core/theme/app_radius.dart';
import 'package:kharis_app/core/theme/app_typography.dart';
import 'package:kharis_app/features/onboarding/presentation/widgets/onboarding_backdrop.dart';
import 'package:kharis_app/features/onboarding/presentation/widgets/role_card.dart';
import 'package:kharis_app/shared/widgets/language_bottom_sheet.dart';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  String _selectedLanguage = 'English (UK)';

  Future<void> _openLanguageSheet() async {
    final result = await showLanguageBottomSheet(
      context,
      selected: _selectedLanguage,
    );
    if (result != null && mounted) {
      setState(() => _selectedLanguage = result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceDark,
      body: OnboardingBackdrop(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(26, 8, 26, 30),
                      child: Column(
                        children: [
                          // Centered hero: logo, wordmark, headline, choices.
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const _LogoHalo(),
                                const SizedBox(height: 18),
                                Text(
                                  'KHARIS CHURCH',
                                  style: AppTypography.labelMd.copyWith(
                                    fontSize: 13,
                                    letterSpacing: 4.16,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.secondary,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Experience Grace. Embody Faith.',
                                  style: AppTypography.bodySm.copyWith(
                                    color: AppColors.onSurfaceVariant,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 34),
                                Text(
                                  'Welcome to\nKharis Church',
                                  style: AppTypography.displayLg.copyWith(
                                    fontSize: 30,
                                    height: 1.18,
                                    letterSpacing: -0.6,
                                    color: AppColors.heading,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 12),
                                ConstrainedBox(
                                  constraints:
                                      const BoxConstraints(maxWidth: 290),
                                  child: Text(
                                    'A digital sanctuary for sermons, worship '
                                    "and community. Tell us how you'd like to "
                                    'begin.',
                                    style: AppTypography.bodySm.copyWith(
                                      fontSize: 14,
                                      height: 1.6,
                                      color: AppColors.onSurfaceVariant,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                const SizedBox(height: 30),
                                RoleCard(
                                  icon: Icons.person_outline_rounded,
                                  title: 'I am a Member',
                                  description: 'Personalized dashboard, giving '
                                      '& groups',
                                  accent: AppColors.secondary,
                                  onTap: () => context.go('/branch-selection'),
                                ),
                                const SizedBox(height: 12),
                                RoleCard(
                                  icon: Icons.explore_outlined,
                                  title: 'I am a Visitor',
                                  description:
                                      'Explore sermons, events & community',
                                  accent: AppColors.primary,
                                  onTap: () => context.go('/branch-selection'),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),
                          _LanguagePill(
                            label: _selectedLanguage,
                            onTap: _openLanguageSheet,
                          ),
                          const SizedBox(height: 14),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _FooterLink(label: 'Privacy Policy', onTap: () {}),
                              const SizedBox(width: 22),
                              _FooterLink(
                                  label: 'Terms of Service', onTap: () {}),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _LogoHalo extends StatelessWidget {
  const _LogoHalo();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 104,
      height: 104,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          center: Alignment(0, -0.3),
          colors: [Color(0x2ED4AF37), Color(0x99141416)],
        ),
        border: Border.all(
          color: AppColors.secondary.withValues(alpha: 0.25),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.secondary.withValues(alpha: 0.12),
            blurRadius: 50,
          ),
        ],
      ),
      child: Center(
        child: Image.asset(
          'assets/figma/dove_logo.png',
          width: 64,
          height: 64,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _LanguagePill extends StatelessWidget {
  const _LanguagePill({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.language_rounded,
                color: Color(0xFFB8B1BD), size: 15),
            const SizedBox(width: 8),
            Text(
              label,
              style: AppTypography.labelMd.copyWith(
                fontSize: 12,
                letterSpacing: 0,
                color: const Color(0xFFB8B1BD),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.keyboard_arrow_down_rounded,
                color: Color(0xFFB8B1BD), size: 16),
          ],
        ),
      ),
    );
  }
}

class _FooterLink extends StatelessWidget {
  const _FooterLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Text(
        label,
        style: AppTypography.labelMd.copyWith(
          fontSize: 11,
          letterSpacing: 0,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF5C5760),
        ),
      ),
    );
  }
}
