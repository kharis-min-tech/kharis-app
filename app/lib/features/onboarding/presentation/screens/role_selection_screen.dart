import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kharis_app/core/theme/app_colors.dart';
import 'package:kharis_app/core/theme/app_typography.dart';
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
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 40),

              // ── Logo circle ───────────────────────────────────────────────
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.surfaceElevated,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                    width: 1,
                  ),
                  boxShadow: [
                    // Subtle gold inner glow
                    BoxShadow(
                      color: AppColors.secondary.withValues(alpha: 0.15),
                      blurRadius: 24,
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: Center(
                  child: Image.asset(
                    'assets/figma/dove_logo.png',
                    width: 52,
                    height: 52,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Church name — gold
              Text(
                'Kharis Church',
                style: AppTypography.titleMd.copyWith(
                  color: AppColors.secondary,
                ),
              ),
              const SizedBox(height: 4),

              // Tagline
              Text(
                'Experience Grace. Embody Faith.',
                style: AppTypography.bodyLg.copyWith(
                  color: AppColors.onSurfaceVariant.withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 40),

              // ── Welcome heading ───────────────────────────────────────────
              Text(
                'Welcome to Kharis Church',
                style: AppTypography.headlineLgMobile.copyWith(
                  color: AppColors.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                "We are thrilled to have you join our digital sanctuary. "
                "Please select how you'd like to experience our community today.",
                style: AppTypography.bodySm.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 32),

              // ── Role cards ────────────────────────────────────────────────
              RoleCard(
                icon: Icons.account_circle_outlined,
                title: 'I am a Member',
                description:
                    'Access your personalized dashboard, giving history, and community groups.',
                iconColor: AppColors.secondary,
                onTap: () => context.go('/branch-selection'),
              ),
              const SizedBox(height: 12),
              RoleCard(
                icon: Icons.explore_outlined,
                title: 'I am a Visitor',
                description:
                    'Explore our sermons, events, and find out what Kharis is all about.',
                iconColor: AppColors.primary,
                onTap: () => context.go('/branch-selection'),
              ),

              const SizedBox(height: 40),

              // ── Language selector ─────────────────────────────────────────
              TextButton(
                onPressed: _openLanguageSheet,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.onSurfaceVariant,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.language,
                        color: AppColors.onSurfaceVariant, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      _selectedLanguage,
                      style: AppTypography.bodySm.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.keyboard_arrow_down,
                        color: AppColors.onSurfaceVariant, size: 16),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // ── Footer links ──────────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: () {},
                    style: TextButton.styleFrom(
                      minimumSize: Size.zero,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'Privacy Policy',
                      style: AppTypography.labelMd.copyWith(
                        color: AppColors.onSurface.withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                  Text(
                    '·',
                    style: AppTypography.labelMd.copyWith(
                      color: AppColors.onSurface.withValues(alpha: 0.3),
                    ),
                  ),
                  TextButton(
                    onPressed: () {},
                    style: TextButton.styleFrom(
                      minimumSize: Size.zero,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'Terms of Service',
                      style: AppTypography.labelMd.copyWith(
                        color: AppColors.onSurface.withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
