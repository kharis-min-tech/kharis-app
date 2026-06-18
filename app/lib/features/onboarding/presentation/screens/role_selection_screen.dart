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
  String _selectedLanguage = 'English';

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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 32),
              Center(
                child: Image.asset(
                  'assets/figma/dove_logo.png',
                  height: 48,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 28),
              // Heading
              Text(
                'Welcome to Kharis',
                style: TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurface,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              // Subtitle
              Text(
                'How would you like to explore?',
                style: AppTypography.bodyLg.copyWith(
                  fontSize: 16,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 40),
              // Role cards
              RoleCard(
                icon: Icons.people_outline,
                title: 'Member',
                description: 'I attend Kharis Church',
                color: AppColors.primary,
                onTap: () => context.go('/branch-selection'),
              ),
              const SizedBox(height: 12),
              RoleCard(
                icon: Icons.waving_hand,
                title: 'New Here',
                description: 'This is my first time',
                color: AppColors.primary,
                onTap: () => context.go('/branch-selection'),
              ),
              const SizedBox(height: 12),
              RoleCard(
                icon: Icons.headphones,
                title: 'Guest',
                description: 'Just browsing sermons',
                color: AppColors.secondary,
                onTap: () => context.go('/branch-selection'),
              ),
              const Spacer(),
              // Language selector
              Center(
                child: TextButton.icon(
                  onPressed: _openLanguageSheet,
                  icon: Icon(
                    Icons.language,
                    color: AppColors.textMuted,
                    size: 18,
                  ),
                  label: Text(
                    _selectedLanguage,
                    style: AppTypography.bodySm.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textMuted,
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
