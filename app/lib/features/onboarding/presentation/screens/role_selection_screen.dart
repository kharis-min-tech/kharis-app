import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kharis_app/shared/providers/onboarding_provider.dart';
import 'package:kharis_app/core/constants/app_assets.dart';
import 'package:kharis_app/core/theme/app_colors.dart';
import 'package:kharis_app/core/theme/app_radius.dart';
import 'package:kharis_app/core/theme/app_typography.dart';
import 'package:kharis_app/features/onboarding/presentation/widgets/role_card.dart';
import 'package:kharis_app/shared/widgets/language_bottom_sheet.dart';

/// Role selection (design-handoff v3) — light screen. Pick how the user relates
/// to Kharis; every role continues to branch selection.
class RoleSelectionScreen extends ConsumerStatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  ConsumerState<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends ConsumerState<RoleSelectionScreen> {
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

  void _select(String role) {
    ref.read(onboardingRepositoryProvider).saveRole(role);
    context.go('/branch-selection');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Image.asset(AppAssets.dovePurple, width: 34, height: 34),
              const SizedBox(height: 18),
              Text(
                'Welcome home',
                style: AppTypography.display(size: 30, weight: FontWeight.w700)
                    .copyWith(color: AppColors.textPrimary),
              ),
              const SizedBox(height: 6),
              Text(
                'How do you journey with Kharis?',
                style: AppTypography.serif(size: 17, italic: true)
                    .copyWith(color: AppColors.textMutedLight),
              ),
              const SizedBox(height: 22),

              // Community photo banner with gradient caption.
              const _CommunityBanner(),
              const SizedBox(height: 22),

              RoleCard(
                icon: Icons.home_outlined,
                title: 'Member',
                description: 'I call Kharis my church home',
                accent: AppColors.primary,
                onTap: () => _select('member'),
              ),
              const SizedBox(height: 12),
              RoleCard(
                icon: Icons.auto_awesome_outlined,
                title: 'New here',
                description: 'First time — help me settle in',
                accent: AppColors.secondary,
                onTap: () => _select('new_here'),
              ),
              const SizedBox(height: 12),
              RoleCard(
                icon: Icons.explore_outlined,
                title: 'Visitor',
                description: 'Just exploring for now',
                accent: AppColors.primary,
                onTap: () => _select('visitor'),
              ),
              const SizedBox(height: 12),
              RoleCard(
                icon: Icons.volunteer_activism_outlined,
                title: 'Partner',
                description: 'I support Kharis in ministry',
                accent: AppColors.secondary,
                onTap: () => _select('partner'),
              ),

              const SizedBox(height: 26),
              Center(
                child: _LanguagePill(
                  label: _selectedLanguage,
                  onTap: _openLanguageSheet,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _FooterLink(label: 'Privacy Policy', onTap: () {}),
                  const SizedBox(width: 22),
                  _FooterLink(label: 'Terms of Service', onTap: () {}),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CommunityBanner extends StatelessWidget {
  const _CommunityBanner();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: AppRadius.cardBorder,
      child: SizedBox(
        height: 118,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(AppAssets.communityRole, fit: BoxFit.cover),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [Color(0xB3000000), Color(0x00000000)],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Text(
                  'One family, many stories',
                  style: AppTypography.ui(size: 14, weight: FontWeight.w700)
                      .copyWith(color: Colors.white),
                ),
              ),
            ),
          ],
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
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.pillBorder,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: AppColors.cardWhite,
          borderRadius: AppRadius.pillBorder,
          border: Border.all(color: AppColors.dividerLight),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.language_rounded,
                size: 16, color: AppColors.textMutedLight),
            const SizedBox(width: 8),
            Text(
              label,
              style: AppTypography.ui(size: 13, weight: FontWeight.w600)
                  .copyWith(color: AppColors.textPrimary),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.keyboard_arrow_down_rounded,
                size: 18, color: AppColors.textMutedLight),
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
    return InkWell(
      onTap: onTap,
      child: Text(
        label,
        style: AppTypography.ui(size: 12, weight: FontWeight.w500)
            .copyWith(color: AppColors.textMutedLight),
      ),
    );
  }
}
