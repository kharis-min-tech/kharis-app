import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kharis_app/core/theme/app_colors.dart';
import 'package:kharis_app/core/theme/app_typography.dart';
import 'package:kharis_app/features/onboarding/presentation/widgets/branch_tile.dart';
import 'package:kharis_app/features/onboarding/data/branch_repository.dart';
import 'package:kharis_app/shared/providers/admin_provider.dart';
import 'package:kharis_app/shared/providers/auth_provider.dart';

// Scoped to the onboarding flow, discarded once the router pops this screen.
final _selectedBranchProvider = StateProvider<String?>((ref) => null);


class BranchSelectionScreen extends ConsumerWidget {
  const BranchSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(_selectedBranchProvider);
    final branches =
        ref.watch(branchesProvider).valueOrNull ?? BranchRepository.seedBranches;

    return Scaffold(
      backgroundColor: AppColors.surfaceDark,
      body: Stack(
        children: [
          SafeArea(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 6),
                        const _TopBar(),
                        const SizedBox(height: 20),
                        Text(
                          'Select Your Branch',
                          style: AppTypography.displayLg.copyWith(
                            fontSize: 28,
                            letterSpacing: -0.56,
                            color: AppColors.heading,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Choose your home church to get tailored updates, '
                          'event details and local community messages.',
                          style: AppTypography.bodySm.copyWith(
                            fontSize: 13.5,
                            height: 1.55,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 22),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  sliver: SliverList.separated(
                    itemCount: branches.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, i) {
                      final branch = branches[i];
                      return BranchTile(
                        name: branch.name,
                        subtitle: branch.subtitle,
                        gradientColors: branch.gradient,
                        imageUrl: branch.imageUrl,
                        isSelected: selected == branch.name,
                        onTap: () => ref
                            .read(_selectedBranchProvider.notifier)
                            .state = branch.name,
                      );
                    },
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 130)),
              ],
            ),
          ),

          // CTA slides up once a branch is chosen.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: IgnorePointer(
              ignoring: selected == null,
              child: AnimatedSlide(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                offset: selected == null ? const Offset(0, 1) : Offset.zero,
                child: _BottomCta(
                  onPressed: () => _confirm(context, ref, selected),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Persists the chosen branch to the signed-in profile (best effort), then
  /// continues into the app.
  Future<void> _confirm(
      BuildContext context, WidgetRef ref, String? branch) async {
    if (branch != null) {
      final user = ref.read(currentUserProvider).valueOrNull;
      final repo = ref.read(firebaseAuthRepositoryProvider);
      if (user != null && user.email.isNotEmpty) {
        try {
          await repo.updateProfile(branch: branch);
        } catch (_) {}
      }
    }
    if (context.mounted) context.go('/home');
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: GestureDetector(
            onTap: () => context.pop(),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.chevron_left_rounded,
                color: Color(0xFFCFC8D4),
                size: 24,
              ),
            ),
          ),
        ),
        Image.asset(
          'assets/figma/dove_logo.png',
          height: 30,
          color: Colors.white,
        ),
      ],
    );
  }
}

class _BottomCta extends StatelessWidget {
  const _BottomCta({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.surfaceDark.withValues(alpha: 0.0),
            AppColors.surfaceDark.withValues(alpha: 0.9),
            AppColors.surfaceDark,
          ],
          stops: const [0.0, 0.4, 1.0],
        ),
      ),
      padding: EdgeInsets.fromLTRB(22, 28, 22, 20 + bottomPadding),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.secondary,
            foregroundColor: AppColors.onSecondary,
            padding: const EdgeInsets.symmetric(vertical: 17),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 0,
            shadowColor: Colors.transparent,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Confirm & Continue',
                style: AppTypography.titleMd.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.onSecondary,
                ),
              ),
              const SizedBox(width: 9),
              const Icon(Icons.arrow_forward_rounded, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
