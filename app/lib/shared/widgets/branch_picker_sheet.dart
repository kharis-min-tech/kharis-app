import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/features/onboarding/data/branch_repository.dart';
import 'package:kharis_app/shared/providers/admin_provider.dart';
import 'package:kharis_app/shared/providers/branch_provider.dart';
import 'package:kharis_app/shared/providers/location_provider.dart';

/// Label of the Events tab's "every branch" browse filter. Never a member's
/// branch.
const String kAllCampusesLabel = 'All branches';

/// What the branch chip says while the member has not chosen a branch.
const String kChooseBranchLabel = 'Choose your branch';

/// A row picked from [BranchPickerSheet]. Wraps the name so the Events
/// tab's "All branches" (`name == null`, only offered with `allowAll`) is
/// distinguishable from dismissing the sheet.
@immutable
class BranchChoice {
  const BranchChoice(this.name);
  final String? name;
}

/// Opens the branch list. [current] is ticked; [allowAll] adds the Events
/// tab's "All branches" row. Null when dismissed.
Future<BranchChoice?> showBranchPicker(
  BuildContext context, {
  required String? current,
  bool allowAll = false,
}) => showModalBottomSheet<BranchChoice>(
  context: context,
  useRootNavigator: true,
  backgroundColor: Colors.transparent,
  isScrollControlled: true,
  builder: (_) => BranchPickerSheet(current: current, allowAll: allowAll),
);

/// Makes [branch] the member's branch through [setActiveBranch] (unless it
/// already is) and confirms it in a snack bar.
Future<void> applyBranchChoice(
  BuildContext context,
  WidgetRef ref,
  String branch,
) async {
  if (branch == ref.read(currentBranchProvider).valueOrNull) return;
  final messenger = ScaffoldMessenger.of(context);
  final result = await setActiveBranch(ref, branch);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(
          result.syncFailed
              ? 'Your branch is now $branch on this device. We could not '
                    'reach your profile, so it will sync automatically.'
              : 'Your branch is now $branch.',
        ),
      ),
    );
}

/// Lets the member change their branch from anywhere (Home, Giving "Giving
/// to", Edit profile, the launch prompt) and persists it through
/// [setActiveBranch], the one path that keeps SharedPreferences, the FCM
/// topic and `users/{uid}.branch` in agreement.
///
/// Works for guests and signed-out sessions too: [setActiveBranch] skips the
/// profile write when there is no member profile.
Future<void> pickActiveBranch(BuildContext context, WidgetRef ref) async {
  final choice = await showBranchPicker(
    context,
    current: ref.read(currentBranchProvider).valueOrNull,
  );
  final name = choice?.name;
  if (name == null || !context.mounted) return;
  await applyBranchChoice(context, ref, name);
}

/// The branch list, led by "Use my location". Pops a [BranchChoice]; it
/// never writes anything itself.
class BranchPickerSheet extends ConsumerWidget {
  const BranchPickerSheet({
    super.key,
    required this.current,
    this.allowAll = false,
  });

  /// The ticked row: a branch name, or null for "All branches" (with
  /// [allowAll]) or nothing chosen.
  final String? current;

  /// Offer the Events tab's "All branches" browse filter.
  final bool allowAll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kc = context.kc;
    final branches =
        ref.watch(branchesProvider).valueOrNull ?? const <Branch>[];
    final maxHeight = MediaQuery.sizeOf(context).height * 0.75;

    Widget row(String? name, {String? subtitle}) {
      final selected = name == current;
      return ListTile(
        key: ValueKey('branch-choice-${name ?? 'all'}'),
        onTap: () => Navigator.of(context).pop(BranchChoice(name)),
        leading: _RowIcon(
          name == null ? Icons.public_rounded : Icons.location_on_outlined,
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
                  kChooseBranchLabel,
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
                    UseMyLocationTile(
                      onNearest: (b) =>
                          Navigator.of(context).pop(BranchChoice(b.name)),
                    ),
                    if (allowAll)
                      row(null, subtitle: 'Browse events at every branch'),
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

class _RowIcon extends StatelessWidget {
  const _RowIcon(this.icon);

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final kc = context.kc;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: kc.chipBg,
        borderRadius: AppRadius.tileBorder,
      ),
      child: Icon(icon, color: kc.onChip, size: 20),
    );
  }
}

/// How long "Nearest: Bristol · 2.3 mi" stays up before the choice is made,
/// so the member sees which branch their location picked.
const Duration kNearestBranchHold = Duration(milliseconds: 900);

/// "Use my location": asks for approximate location only when tapped, finds
/// the branch whose venue is nearest and hands it to [onNearest] exactly
/// like tapping that branch. Denied or unavailable location leaves a short
/// message in the row; the list below stays usable.
class UseMyLocationTile extends ConsumerStatefulWidget {
  const UseMyLocationTile({
    super.key,
    required this.onNearest,
    this.contentPadding,
  });

  final ValueChanged<Branch> onNearest;
  final EdgeInsetsGeometry? contentPadding;

  @override
  ConsumerState<UseMyLocationTile> createState() => _UseMyLocationTileState();
}

class _UseMyLocationTileState extends ConsumerState<UseMyLocationTile> {
  bool _busy = false;
  String? _status;

  Future<void> _locate() async {
    setState(() {
      _busy = true;
      _status = 'Finding your location…';
    });
    final location = ref.read(locationServiceProvider);
    final allowed =
        await location.isGranted() || await location.requestPermission();
    if (!mounted) return;
    if (!allowed) {
      return _fail('Location is off for Kharis. Choose your branch below.');
    }
    final here = await location.position();
    final branches = ref.read(branchesProvider).valueOrNull ?? const [];
    final nearest = here == null ? null : nearestBranch(branches, here);
    if (!mounted) return;
    if (nearest == null) {
      return _fail('We couldn\u2019t find your location. Choose below.');
    }
    setState(() => _status = nearest.label);
    await Future<void>.delayed(kNearestBranchHold);
    if (!mounted) return;
    setState(() => _busy = false);
    widget.onNearest(nearest.branch);
  }

  void _fail(String message) => setState(() {
    _busy = false;
    _status = message;
  });

  @override
  Widget build(BuildContext context) {
    final kc = context.kc;
    return ListTile(
      key: const ValueKey('branch-use-location'),
      contentPadding: widget.contentPadding,
      onTap: _busy ? null : _locate,
      leading: const _RowIcon(Icons.my_location_rounded),
      title: Text(
        'Use my location',
        style: AppTypography.ui(
          size: 15,
          weight: FontWeight.w600,
          color: kc.onBg,
        ),
      ),
      subtitle: Text(
        _status ?? 'Find the branch nearest you',
        key: const ValueKey('branch-location-status'),
        style: AppTypography.ui(size: 12.5, color: kc.muted),
      ),
      trailing: _busy
          ? SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: kc.accentInk,
              ),
            )
          : null,
    );
  }
}
