import 'package:flutter/material.dart';
import 'package:kharis_app/ui/components/components.dart';

/// One onboarding choice: an icon tile, a title, a supporting line and a
/// chevron. Sits in a [KListGroup] with the other roles.
class RoleCard extends StatelessWidget {
  const RoleCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  /// One of the [KIcons] paths.
  final String icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return KListRow(
      leading: KIconTile(icon),
      title: title,
      meta: description,
      showChevron: true,
      onTap: onTap,
    );
  }
}
