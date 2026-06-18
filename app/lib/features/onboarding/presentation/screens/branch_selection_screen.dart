import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kharis_app/core/theme/app_colors.dart';
import 'package:kharis_app/features/onboarding/presentation/widgets/branch_tile.dart';

// Scoped to the onboarding flow — discarded once the router pops this screen.
final _selectedBranchProvider = StateProvider<String?>((ref) => null);

// Branch name, subtitle, and per-branch gradient (purple → gold palette).
const _kBranches = <({
  String name,
  String subtitle,
  List<Color> gradient,
})>[
  (
    name: 'Kharis London',
    subtitle: 'United Kingdom - Main Campus',
    gradient: [Color(0xFF7B5EA7), Color(0xFFD6BAFF)],
  ),
  (
    name: 'Kharis Manchester',
    subtitle: 'United Kingdom - North Branch',
    gradient: [Color(0xFF4A3468), Color(0xFFAD8FD4)],
  ),
  (
    name: 'Kharis Birmingham',
    subtitle: 'United Kingdom - Midlands',
    gradient: [Color(0xFF5C3D7A), Color(0xFFBD92FF)],
  ),
  (
    name: 'Kharis Reading',
    subtitle: 'United Kingdom - South East',
    gradient: [Color(0xFF8A6E2F), Color(0xFFE9C349)],
  ),
  (
    name: 'Kharis Chatham',
    subtitle: 'United Kingdom - Kent',
    gradient: [Color(0xFF3D2B5C), Color(0xFFC4A0E8)],
  ),
  (
    name: 'Kharis Croydon',
    subtitle: 'United Kingdom - South London',
    gradient: [Color(0xFF6B4F8A), Color(0xFFD4B8F0)],
  ),
  (
    name: 'Kharis Medway',
    subtitle: 'United Kingdom - Kent',
    gradient: [Color(0xFF7A5C3A), Color(0xFFE0B84A)],
  ),
  (
    name: 'Kharis Accra',
    subtitle: 'Ghana - International Campus',
    gradient: [Color(0xFF9B7523), Color(0xFFEDD27B)],
  ),
  (
    name: 'Kharis Freetown',
    subtitle: 'Sierra Leone - West Africa',
    gradient: [Color(0xFF5A3E7A), Color(0xFFB89FE0)],
  ),
];

class BranchSelectionScreen extends ConsumerWidget {
  const BranchSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(_selectedBranchProvider);

    return Scaffold(
      backgroundColor: AppColors.surfaceDark,
      body: Stack(
        children: [
          // ── Scrollable content ─────────────────────────────────────────
          SafeArea(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        const SizedBox(height: 20),

                        // ── Top bar ──────────────────────────────────────
                        _TopBar(),

                        const SizedBox(height: 28),

                        // ── Title ────────────────────────────────────────
                        Text(
                          'Select Your Branch',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: AppColors.onSurface,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Choose your local home church to get customized updates, event details, and local community messages.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                            height: 1.5,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 28),
                      ],
                    ),
                  ),
                ),

                // ── Branch list ─────────────────────────────────────────
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  sliver: SliverList.separated(
                    itemCount: _kBranches.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final branch = _kBranches[i];
                      return BranchTile(
                        name: branch.name,
                        subtitle: branch.subtitle,
                        gradientColors: branch.gradient,
                        isSelected: selected == branch.name,
                        onTap: () => ref
                            .read(_selectedBranchProvider.notifier)
                            .state = branch.name,
                      );
                    },
                  ),
                ),

                // Bottom padding so last card clears the fixed CTA
                const SliverToBoxAdapter(child: SizedBox(height: 120)),
              ],
            ),
          ),

          // ── Fixed bottom CTA ───────────────────────────────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _BottomCta(
              enabled: selected != null,
              onPressed: () => context.go('/home'),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Back arrow — left
        Align(
          alignment: Alignment.centerLeft,
          child: GestureDetector(
            onTap: () => context.pop(),
            child: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: AppColors.surfaceElevated,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_back_rounded,
                color: AppColors.onSurface,
                size: 20,
              ),
            ),
          ),
        ),

        // Dove logo — centred
        Image.asset(
          'assets/figma/dove_logo.png',
          height: 32,
          color: Colors.white,
        ),
      ],
    );
  }
}

class _BottomCta extends StatelessWidget {
  const _BottomCta({
    required this.enabled,
    required this.onPressed,
  });

  final bool enabled;
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
            AppColors.surfaceDark.withValues(alpha: 0.85),
            AppColors.surfaceDark,
          ],
          stops: const [0.0, 0.35, 1.0],
        ),
      ),
      padding: EdgeInsets.fromLTRB(24, 24, 24, 20 + bottomPadding),
      child: SizedBox(
        width: double.infinity,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: enabled ? 1.0 : 0.45,
          child: ElevatedButton.icon(
            onPressed: enabled ? onPressed : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.secondary,
              disabledBackgroundColor: AppColors.surfaceElevated,
              foregroundColor: AppColors.onSecondary,
              disabledForegroundColor:
                  AppColors.onSurface.withValues(alpha: 0.4),
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
              shadowColor: Colors.transparent,
            ),
            icon: const SizedBox.shrink(),
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Confirm & Continue',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: enabled
                        ? AppColors.onSecondary
                        : AppColors.onSurface.withValues(alpha: 0.4),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.arrow_forward_rounded,
                  size: 18,
                  color: enabled
                      ? AppColors.onSecondary
                      : AppColors.onSurface.withValues(alpha: 0.4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
