import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kharis_app/ui/components/components.dart';
import 'package:kharis_app/features/onboarding/presentation/widgets/branch_tile.dart';
import 'package:kharis_app/features/onboarding/data/branch_repository.dart';
import 'package:kharis_app/shared/providers/admin_provider.dart';
import 'package:kharis_app/shared/providers/branch_provider.dart';
import 'package:kharis_app/shared/providers/onboarding_provider.dart';
import 'package:kharis_app/shared/widgets/branch_picker_sheet.dart';

/// Branch selection. Search across cities,
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
      subtitle.toLowerCase().contains(RegExp('main (campus|branch)'));

  @override
  Widget build(BuildContext context) {
    final branchesAsync = ref.watch(branchesProvider);
    final branches = branchesAsync.valueOrNull ?? const <Branch>[];

    final q = _query.trim().toLowerCase();
    final filtered = q.isEmpty
        ? branches
        : branches
              .where(
                (b) =>
                    b.name.toLowerCase().contains(q) ||
                    b.subtitle.toLowerCase().contains(q),
              )
              .toList();
    final current = ref.watch(currentBranchProvider).valueOrNull;
    final canPop = context.canPop();

    return PopScope(
      // With nothing beneath (first run), system back returns to the role
      // step instead of leaving the app.
      canPop: canPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go('/role-selection');
      },
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: KSize.maxContentWidth,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: KSpace.gutter),
                  const KScreenHeader(title: 'Find your branch'),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      KSpace.gutter,
                      KSpace.md,
                      KSpace.gutter,
                      KSpace.x3,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Kharis is one family across many cities.',
                          style: KharisText.body.copyWith(
                            color: context.k.muted,
                          ),
                        ),
                        const SizedBox(height: KSpace.x3),
                        KSearchField(
                          hint: 'Search cities, KP2, Ghana, Sierra Leone',
                          controller: _searchCtrl,
                          onChanged: (v) => setState(() => _query = v),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: EdgeInsets.fromLTRB(
                        KSpace.gutter,
                        0,
                        KSpace.gutter,
                        KSpace.section + MediaQuery.paddingOf(context).bottom,
                      ),
                      children: [
                        if (branches.isEmpty)
                          _BranchesStatus(
                            failed:
                                branchesAsync.hasError ||
                                branchesAsync.hasValue,
                            onRetry: () => ref.invalidate(branchesProvider),
                          )
                        else ...[
                          KListGroup(
                            children: [
                              UseMyLocationTile(
                                onNearest: (b) => _confirm(context, ref, b),
                              ),
                            ],
                          ),
                          if (filtered.isEmpty)
                            const KEmptyState(
                              icon: KIcons.search,
                              title: 'No branches match',
                              hint: 'Try a city or a country.',
                            ),
                        ],
                        ..._section(
                          context,
                          ref,
                          'Branches',
                          current,
                          filtered.where(
                            (b) => b.group != Branch.phaseTwoGroup,
                          ),
                        ),
                        ..._section(
                          context,
                          ref,
                          'Kharis Phase Two',
                          current,
                          filtered.where(
                            (b) => b.group == Branch.phaseTwoGroup,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Persists the chosen campus through the one shared path, so prefs, the
  /// FCM topic and the profile cannot disagree. First-run onboarding is also
  /// marked complete here; a member switching campus from More is already
  /// onboarded, so their saved role is left untouched.
  Future<void> _confirm(
    BuildContext context,
    WidgetRef ref,
    Branch branch,
  ) async {
    final onboardingRepo = ref.read(onboardingRepositoryProvider);
    if (!onboardingRepo.isCompleted) {
      await onboardingRepo.completeOnboarding(
        role: onboardingRepo.selectedRole ?? 'member',
        branch: branch.name,
      );
    }

    final result = await setActiveBranch(ref, branch.name);

    if (!context.mounted) return;
    if (result.syncFailed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Switched to ${branch.name} on this device. We could not reach '
            'your profile, so it will sync automatically.',
          ),
        ),
      );
    }
    // Reached from More -> Switch Branch (pop back there) as well as from
    // onboarding, where there is nothing underneath to pop to.
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  /// Section header and its branches in one group; an empty group renders
  /// nothing.
  List<Widget> _section(
    BuildContext context,
    WidgetRef ref,
    String label,
    String? current,
    Iterable<Branch> branches,
  ) {
    final list = branches.toList();
    if (list.isEmpty) return const [];
    return [
      const SizedBox(height: KSpace.section),
      KSectionHeader(title: label),
      KListGroup(
        children: [
          for (final b in list)
            BranchTile(
              name: b.name.startsWith('KP2 ') ? b.name.substring(4) : b.name,
              region: _region(b.subtitle),
              isHq: _isHq(b.subtitle),
              selected: b.name == current,
              onTap: () => _confirm(context, ref, b),
            ),
        ],
      ),
    ];
  }
}

/// Stands in for the list until branches arrive: row-shaped blocks while
/// loading, a retry once loading has failed (no connection and nothing
/// saved).
class _BranchesStatus extends StatelessWidget {
  const _BranchesStatus({required this.failed, required this.onRetry});

  final bool failed;
  final VoidCallback onRetry;

  static const int _placeholderRows = 5;

  @override
  Widget build(BuildContext context) {
    if (failed) {
      return KErrorState(
        message: 'Branches could not load. Check your connection.',
        onRetry: onRetry,
      );
    }
    return Semantics(
      label: 'Loading branches',
      child: Column(
        children: [
          for (var i = 0; i < _placeholderRows; i++) ...[
            if (i > 0) const SizedBox(height: KSpace.md),
            const KSkeleton(height: KSize.listRow, radius: KRadius.card),
          ],
        ],
      ),
    );
  }
}
