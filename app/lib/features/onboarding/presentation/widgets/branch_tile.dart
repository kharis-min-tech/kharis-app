import 'package:flutter/material.dart';
import 'package:kharis_app/ui/components/components.dart';

/// A branch row: the branch name and region, an **HQ** badge for the
/// headquarters and a check on the member's current branch. Tapping the row
/// selects and proceeds. No photo: most branches share one placeholder image
/// in the Content Studio, so a thumbnail only repeated the same picture down
/// the list.
class BranchTile extends StatelessWidget {
  const BranchTile({
    super.key,
    required this.name,
    required this.region,
    required this.onTap,
    this.isHq = false,
    this.selected = false,
  });

  final String name;
  final String region;
  final VoidCallback onTap;
  final bool isHq;

  /// The member's current branch.
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      child: KListRow(
        title: name,
        meta: region.isEmpty ? null : region,
        trailing: isHq || selected
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isHq) const KBadge('HQ', variant: KBadgeVariant.newItem),
                  if (isHq && selected) const SizedBox(width: KSpace.md),
                  if (selected)
                    KIcon(KIcons.check, color: context.k.primaryText),
                ],
              )
            : null,
        onTap: onTap,
      ),
    );
  }
}
