import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kharis_app/core/theme/app_colors.dart';
import 'package:kharis_app/core/theme/app_radius.dart';
import 'package:kharis_app/core/theme/app_typography.dart';
import 'package:kharis_app/features/onboarding/presentation/widgets/branch_tile.dart';
import 'package:kharis_app/features/onboarding/data/branch_repository.dart';
import 'package:kharis_app/shared/providers/admin_provider.dart';
import 'package:kharis_app/shared/providers/branch_provider.dart';
import 'package:kharis_app/shared/providers/auth_provider.dart';
import 'package:kharis_app/shared/providers/onboarding_provider.dart';
import 'package:kharis_app/shared/providers/notification_provider.dart';

/// Branch selection (design-handoff v3) — light screen. Search across cities,
/// then tap a branch to set it as home and enter the app.
class BranchSelectionScreen extends ConsumerStatefulWidget {
  const BranchSelectionScreen({super.key});

  @override
  ConsumerState<BranchSelectionScreen> createState() =>
      _BranchSelectionScreenState();
}

class _BranchSelectionScreenState extends ConsumerState<BranchSelectionScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  static String _region(String subtitle) => subtitle.split('·').first.trim();
  static bool _isHq(String subtitle) =>
      subtitle.toLowerCase().contains('main campus');

  @override
  Widget build(BuildContext context) {
    final branches =
        ref.watch(branchesProvider).valueOrNull ?? BranchRepository.seedBranches;

    final q = _query.trim().toLowerCase();
    final filtered = q.isEmpty
        ? branches
        : branches
            .where((b) =>
                b.name.toLowerCase().contains(q) ||
                b.subtitle.toLowerCase().contains(q))
            .toList();

    return Scaffold(
      backgroundColor: AppColors.lightBg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 6, 22, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _BackRow(onTap: () => context.go('/role-selection')),
                  const SizedBox(height: 14),
                  Text(
                    'Find your branch',
                    style:
                        AppTypography.display(size: 30, weight: FontWeight.w700)
                            .copyWith(color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Kharis is one family across many cities.',
                    style: AppTypography.serif(size: 17, italic: true)
                        .copyWith(color: AppColors.textMutedLight),
                  ),
                  const SizedBox(height: 18),
                  _SearchField(
                    controller: _searchCtrl,
                    onChanged: (v) => setState(() => _query = v),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(22, 0, 22, 28),
                children: [
                  ..._section(context, ref, 'BRANCHES',
                      filtered.where((b) => b.group != 'KP2')),
                  ..._section(context, ref, 'KHARIS PHASE TWO',
                      filtered.where((b) => b.group == 'KP2')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Persists the chosen branch to the signed-in profile (best effort), then
  /// continues into the app.
  Future<void> _confirm(
      BuildContext context, WidgetRef ref, Branch branch) async {
    final user = ref.read(currentUserProvider).valueOrNull;
    final repo = ref.read(firebaseAuthRepositoryProvider);
    if (user != null && user.email.isNotEmpty) {
      try {
        await repo.updateProfile(branch: branch.name);
      } catch (_) {}
    }
    final onboardingRepo = ref.read(onboardingRepositoryProvider);
    // Switch this device's branch FCM topic so it gets branch-scoped pushes.
    // Same code path as Edit Profile.
    await ref.read(notificationServiceProvider).switchBranchTopic(
          from: onboardingRepo.selectedBranch,
          to: branch.name,
        );
    await onboardingRepo.completeOnboarding(
      role: onboardingRepo.selectedRole ?? 'member',
      branch: branch.name,
    );
    // Guests have no Firestore profile doc for [currentBranchProvider] to
    // stream, so the locally persisted choice is their only source — force a
    // re-read here or their switch never reaches any content provider.
    ref.invalidate(currentBranchProvider);
    if (context.mounted) context.go('/home');
  }

  /// Section header + branch tiles; an empty group renders nothing.
  List<Widget> _section(
    BuildContext context,
    WidgetRef ref,
    String label,
    Iterable<Branch> branches,
  ) {
    final list = branches.toList();
    if (list.isEmpty) return const [];
    return [
      Padding(
        padding: const EdgeInsets.only(top: 6, bottom: 10),
        child: Text(
          label,
          style:
              AppTypography.labelMd.copyWith(color: AppColors.textMutedLight),
        ),
      ),
      for (final b in list)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: BranchTile(
            name: b.name.startsWith('KP2 ') ? b.name.substring(4) : b.name,
            region: _region(b.subtitle),
            gradientColors: b.gradient,
            imageUrl: b.imageUrl,
            isHq: _isHq(b.subtitle),
            onTap: () => _confirm(context, ref, b),
          ),
        ),
    ];
  }
}

class _BackRow extends StatelessWidget {
  const _BackRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.pillBorder,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.chevron_left_rounded,
                size: 24, color: AppColors.textPrimary),
            Text(
              'Back',
              style: AppTypography.ui(size: 15, weight: FontWeight.w600)
                  .copyWith(color: AppColors.textPrimary),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: AppTypography.ui(size: 15).copyWith(color: AppColors.textPrimary),
      cursorColor: AppColors.primary,
      decoration: InputDecoration(
        hintText: 'Search cities, KP2, Ghana, Sierra Leone',
        hintStyle:
            AppTypography.ui(size: 15).copyWith(color: AppColors.textMutedLight),
        prefixIcon: const Icon(Icons.search_rounded,
            size: 20, color: AppColors.textMutedLight),
        filled: true,
        fillColor: AppColors.cardWhite,
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
      ),
    );
  }
}
