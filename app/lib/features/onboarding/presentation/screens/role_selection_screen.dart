import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kharis_app/shared/providers/onboarding_provider.dart';
import 'package:kharis_app/core/constants/app_assets.dart';
import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/features/onboarding/presentation/widgets/role_card.dart';
import 'package:url_launcher/url_launcher.dart';

/// Church privacy policy (verified 200). kharis.org publishes no terms of
/// service, so none is linked.
const String _kPrivacyPolicyUrl = 'https://kharis.org/privacy-policy/';

/// Role selection (design-handoff v3), light screen. Pick how the user relates
/// to Kharis; every role continues to branch selection.
class RoleSelectionScreen extends ConsumerStatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  ConsumerState<RoleSelectionScreen> createState() =>
      _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends ConsumerState<RoleSelectionScreen> {
  void _select(String role) {
    ref.read(onboardingRepositoryProvider).saveRole(role);
    context.go('/branch-selection');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                style: AppTypography.display(
                  size: 30,
                  weight: FontWeight.w700,
                ).copyWith(color: context.kc.onBg),
              ),
              const SizedBox(height: 6),
              Text(
                'How are you connected to Kharis?',
                style: AppTypography.serif(
                  size: 17,
                  italic: true,
                ).copyWith(color: context.kc.muted),
              ),
              const SizedBox(height: 22),

              // Community photo banner with gradient caption.
              const _CommunityBanner(),
              const SizedBox(height: 22),

              RoleCard(
                icon: Icons.home_outlined,
                title: 'Member',
                description: 'I call Kharis my church home',
                accent: context.kc.onChip,
                onTap: () => _select('member'),
              ),
              const SizedBox(height: 12),
              RoleCard(
                icon: Icons.waving_hand_outlined,
                title: 'New here',
                description: 'First time? Help me settle in',
                accent: context.kc.accentInk,
                onTap: () => _select('new_here'),
              ),
              const SizedBox(height: 12),
              RoleCard(
                icon: Icons.explore_outlined,
                title: 'Visitor',
                description: 'Just exploring for now',
                accent: context.kc.onChip,
                onTap: () => _select('visitor'),
              ),
              const SizedBox(height: 12),
              RoleCard(
                icon: Icons.volunteer_activism_outlined,
                title: 'Partner',
                description: 'I support Kharis in ministry',
                accent: context.kc.accentInk,
                onTap: () => _select('partner'),
              ),

              const SizedBox(height: 22),
              Center(
                child: _FooterLink(
                  label: 'Privacy policy',
                  onTap: () => launchUrl(
                    Uri.parse(_kPrivacyPolicyUrl),
                    mode: LaunchMode.externalApplication,
                  ),
                ),
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
                // Sits on the photo's dark gradient, not on a themed surface —
                // stays white in both brightnesses.
                child: Text(
                  'One family, many stories',
                  style: AppTypography.ui(
                    size: 14,
                    weight: FontWeight.w700,
                  ).copyWith(color: Colors.white),
                ),
              ),
            ),
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
      borderRadius: AppRadius.pillBorder,
      // 14 + 16 line + 14: a 44 px target.
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
        child: Text(
          label,
          style: AppTypography.ui(
            size: 12,
            weight: FontWeight.w500,
          ).copyWith(color: context.kc.muted),
        ),
      ),
    );
  }
}
