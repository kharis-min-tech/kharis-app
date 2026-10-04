import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/features/onboarding/data/branch_repository.dart';
import 'package:kharis_app/shared/providers/admin_provider.dart';
import 'package:kharis_app/shared/providers/branch_provider.dart';

/// Label for the unscoped choice (`branch == null`).
const String kAllCampusesLabel = 'All campuses';

/// A campus picked from [BranchPickerSheet]. Wraps the name so "All campuses"
/// (`name == null`) is distinguishable from dismissing the sheet.
@immutable
class BranchChoice {
  const BranchChoice(this.name);
  final String? name;
}

/// Lets the member change their campus from anywhere (Home campus card,
/// Giving "Giving to", Edit profile) and persists it through
/// [setActiveBranch], the one path that keeps SharedPreferences, the FCM
/// topic and `users/{uid}.branch` in agreement.
///
/// Works for guests and signed-out sessions too: [setActiveBranch] skips the
/// profile write when there is no member profile.
Future<void> pickActiveBranch(BuildContext context, WidgetRef ref) async {
  final current = ref.read(currentBranchProvider).valueOrNull;
  final choice = await showModalBottomSheet<BranchChoice>(
    context: context,
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => BranchPickerSheet(current: current),
  );
  if (choice == null || choice.name == current || !context.mounted) return;

  final messenger = ScaffoldMessenger.of(context);
  final label = choice.name ?? kAllCampusesLabel;
  final result = await setActiveBranch(ref, choice.name);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(
          result.syncFailed
              ? 'Your campus is now $label on this device. We could not '
                    'reach your profile, so it will sync automatically.'
              : 'Your campus is now $label.',
        ),
      ),
    );
}

/// The campus list. Pops a [BranchChoice]; it never writes anything itself.
class BranchPickerSheet extends ConsumerWidget {
  const BranchPickerSheet({super.key, required this.current});

  /// The active campus, ticked in the list. `null` ticks All campuses.
  final String? current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kc = context.kc;
    final branches =
        ref.watch(branchesProvider).valueOrNull ??
        BranchRepository.seedBranches;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.75;

    Widget row(String? name, {String? subtitle}) {
      final selected = name == current;
      return ListTile(
        key: ValueKey('branch-choice-${name ?? 'all'}'),
        onTap: () => Navigator.of(context).pop(BranchChoice(name)),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: kc.chipBg,
            borderRadius: AppRadius.tileBorder,
          ),
          child: Icon(
            name == null ? Icons.public_rounded : Icons.location_on_outlined,
            color: kc.onChip,
            size: 20,
          ),
        ),
        title: Text(
          name ?? kAllCampusesLabel,
          style: AppTypography.ui(
            size: 15,
            weight: FontWeight.w600,
            color: kc.onBg,
          ),
        ),
        subtitle: subtitle == null || subtitle.isEmpty
            ? null
            : Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.ui(size: 12.5, color: kc.muted),
              ),
        trailing: selected
            ? Icon(Icons.check_circle_rounded, color: kc.accentInk, size: 22)
            : null,
      );
    }

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        constraints: BoxConstraints(maxHeight: maxHeight),
        // Material (not a decorated box) so the ListTile ink is visible.
        child: Material(
          color: kc.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 10),
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: kc.outline,
                    borderRadius: AppRadius.pillBorder,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 2),
                child: Text(
                  'Choose your campus',
                  style: AppTypography.display(
                    size: 18,
                    weight: FontWeight.w700,
                    color: kc.onBg,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(
                  'Events, announcements and giving follow this choice.',
                  style: AppTypography.ui(size: 13, color: kc.muted),
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.only(bottom: 12),
                  children: [
                    row(null, subtitle: 'See every Kharis branch'),
                    for (final b in branches) row(b.name, subtitle: b.subtitle),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
