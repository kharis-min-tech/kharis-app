import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kharis_app/ui/components/components.dart';
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
}) => showKBottomSheet<BranchChoice>(
  // Above the tab shell, so the floating nav is covered while it is open.
  context: Navigator.of(context, rootNavigator: true).context,
  title: kChooseBranchLabel,
  builder: (_) => BranchPickerSheet(current: current, allowAll: allowAll),
);

/// The most of the screen height the branch list takes.
const double _kSheetHeightShare = 0.6;

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
    final k = context.k;
    final branches =
        ref.watch(branchesProvider).valueOrNull ?? const <Branch>[];
    final maxHeight = MediaQuery.sizeOf(context).height * _kSheetHeightShare;

    Widget row(String? name, {String? subtitle}) {
      final selected = name == current;
      return Semantics(
        selected: selected,
        child: KListRow(
          key: ValueKey('branch-choice-${name ?? 'all'}'),
          onTap: () => Navigator.of(context).pop(BranchChoice(name)),
          title: name ?? kAllCampusesLabel,
          meta: subtitle == null || subtitle.isEmpty ? null : subtitle,
          trailing: selected ? KIcon(KIcons.check, color: k.primaryText) : null,
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Events, announcements and giving follow this choice.',
                style: KharisText.meta.copyWith(color: k.muted),
              ),
            ),
            const SizedBox(width: KSpace.md),
            KIconButton(
              icon: KIcons.close,
              label: 'Close',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
        const SizedBox(height: KSpace.xl),
        ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: SingleChildScrollView(
            child: KListGroup(
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
        ),
      ],
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
  const UseMyLocationTile({super.key, required this.onNearest});

  final ValueChanged<Branch> onNearest;

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

  // Laid out like a [KListRow]; built here because the status line carries
  // its own key and changes while the row is busy.
  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return MergeSemantics(
      child: Semantics(
        button: true,
        enabled: !_busy,
        child: InkWell(
          key: const ValueKey('branch-use-location'),
          onTap: _busy ? null : _locate,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: KSize.listRow),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: KSpace.x3,
                vertical: KSpace.md,
              ),
              child: Row(
                children: [
                  const KIconTile(KIcons.pin),
                  const SizedBox(width: KSpace.xl),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Use my location',
                          style: KharisText.itemTitle.copyWith(color: k.text),
                        ),
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            _status ?? 'Find the branch nearest you',
                            key: const ValueKey('branch-location-status'),
                            style: KharisText.meta.copyWith(color: k.muted),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_busy) ...[
                    const SizedBox(width: KSpace.md),
                    SizedBox.square(
                      dimension: KSize.iconMd,
                      child: CircularProgressIndicator(
                        strokeWidth: KSize.outline,
                        color: k.primaryText,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
