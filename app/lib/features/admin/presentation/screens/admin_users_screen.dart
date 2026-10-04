import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/features/onboarding/data/user_admin_repository.dart';
import 'package:kharis_app/shared/models/campus_config.dart';
import 'package:kharis_app/shared/models/user.dart';
import 'package:kharis_app/shared/providers/admin_provider.dart';

// ── Role metadata ──────────────────────────────────────────────────────────────

const _campusAdmin = AdminScope.campusAdminRole;

const _roles = ['member', 'guest', 'new_here', _campusAdmin, 'admin'];

String _roleLabel(String role) {
  switch (role) {
    case 'member':
      return 'Member';
    case 'guest':
      return 'Guest';
    case 'new_here':
      return 'New Here';
    case _campusAdmin:
      return 'Campus admin';
    case 'admin':
      return 'Admin';
    default:
      return role;
  }
}

Color _roleColor(String role) {
  switch (role) {
    case 'admin':
    case _campusAdmin:
      return AppColors.secondary;
    case 'member':
      return AppColors.primary;
    case 'new_here':
      return AppColors.accentPink;
    case 'guest':
    default:
      return AppColors.onSurfaceVariant;
  }
}

// ── Main screen ───────────────────────────────────────────────────────────────

/// Admin screen: view all users and manage their roles. A campus admin is
/// assigned 1+ campuses here (`adminBranchIds` + `adminBranchNames`, written
/// together with the role); any other role clears them.
class AdminUsersScreen extends ConsumerWidget {
  const AdminUsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(allUsersProvider);

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Users',
          style: AppTypography.titleMd.copyWith(color: AppColors.heading),
        ),
        iconTheme: const IconThemeData(color: AppColors.heading),
      ),
      body: usersAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.secondary),
        ),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.lock_outline_rounded,
                size: 48,
                color: AppColors.textFaint,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Admins only',
                style: AppTypography.titleMd.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'You do not have permission to view all users.',
                style: AppTypography.bodySm.copyWith(
                  color: AppColors.textMuted,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        data: (users) {
          if (users.isEmpty) {
            return Center(
              child: Text(
                'No users found.',
                style: AppTypography.bodyLg.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.gutter,
              AppSpacing.sm,
              AppSpacing.gutter,
              AppSpacing.lg,
            ),
            itemCount: users.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.xs),
            itemBuilder: (_, i) => _UserTile(
              entry: users[i],
              onTap: () => _showRolePicker(context, ref, users[i]),
            ),
          );
        },
      ),
    );
  }

  void _showRolePicker(BuildContext context, WidgetRef ref, AdminUser entry) {
    final messenger = ScaffoldMessenger.of(context);
    final repo = ref.read(userAdminRepositoryProvider);
    final user = entry.user;

    void report(String text, {bool error = false}) => messenger.showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: error
            ? AppColors.errorContainer
            : AppColors.surfaceElevated,
      ),
    );

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _RolePickerSheet(
        user: user,
        onRoleSelected: (newRole) async {
          var ids = const <String>[];
          var names = const <String>[];
          if (newRole == _campusAdmin) {
            final picked = await showModalBottomSheet<Map<String, String>>(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => _CampusPickerSheet(
                user: user,
                initial: {
                  for (var i = 0; i < entry.adminBranchIds.length; i++)
                    entry.adminBranchIds[i]: i < entry.adminBranchNames.length
                        ? entry.adminBranchNames[i]
                        : entry.adminBranchIds[i],
                },
              ),
            );
            if (picked == null || picked.isEmpty) return;
            ids = picked.keys.toList();
            names = picked.values.toList();
          }

          final isAdminChange = newRole == 'admin' || user.role == 'admin';
          if (isAdminChange && context.mounted) {
            final confirmed = await _confirmAdminChange(context, user, newRole);
            if (!confirmed) return;
          }

          try {
            await repo.setRole(
              user.id,
              newRole,
              branchIds: ids,
              branchNames: names,
            );
            report(
              newRole == _campusAdmin
                  ? '${user.displayName} now manages ${names.join(', ')}.'
                  : 'Role updated to ${_roleLabel(newRole)} for '
                        '${user.displayName}.',
            );
          } catch (e) {
            report('Update failed: $e', error: true);
          }
        },
      ),
    );
  }

  Future<bool> _confirmAdminChange(
    BuildContext context,
    User user,
    String newRole,
  ) async {
    final isPromotion = newRole == 'admin';
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        title: Text(
          isPromotion ? 'Grant admin access?' : 'Remove admin access?',
          style: AppTypography.titleMd.copyWith(color: AppColors.heading),
        ),
        content: Text(
          isPromotion
              ? 'This will give ${user.displayName} full admin privileges.'
              : 'This will remove full admin access from ${user.displayName}.',
          style: AppTypography.bodySm.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: AppTypography.bodySm.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              isPromotion ? 'Grant' : 'Remove',
              style: AppTypography.bodySm.copyWith(
                color: isPromotion ? AppColors.secondary : AppColors.error,
              ),
            ),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}

// ── User tile ─────────────────────────────────────────────────────────────────

class _UserTile extends StatelessWidget {
  const _UserTile({required this.entry, required this.onTap});

  final AdminUser entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final user = entry.user;
    final initial = user.displayName.isNotEmpty
        ? user.displayName[0].toUpperCase()
        : '?';
    final campuses = user.role == _campusAdmin ? entry.adminBranchNames : null;

    return Material(
      color: AppColors.surfaceDark,
      borderRadius: AppRadius.cardBorder,
      child: InkWell(
        borderRadius: AppRadius.cardBorder,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.surfaceSubtle,
                foregroundImage: user.photoUrl != null
                    ? NetworkImage(user.photoUrl!)
                    : null,
                onForegroundImageError: user.photoUrl != null
                    ? (_, _) {}
                    : null,
                child: Text(
                  initial,
                  style: AppTypography.bodyLg.copyWith(
                    color: AppColors.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.displayName,
                      style: AppTypography.bodyLg.copyWith(
                        color: AppColors.heading,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      user.email,
                      style: AppTypography.bodySm.copyWith(
                        color: AppColors.textMuted,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (campuses != null)
                      Text(
                        campuses.isEmpty
                            ? 'No campuses assigned'
                            : 'Manages ${campuses.join(', ')}',
                        style: AppTypography.labelMd.copyWith(
                          color: AppColors.secondary,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              _RoleChip(role: user.role),
              const SizedBox(width: AppSpacing.xs),
              const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: AppColors.textFaint,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Role chip ─────────────────────────────────────────────────────────────────

class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.role});
  final String role;

  @override
  Widget build(BuildContext context) {
    final color = _roleColor(role);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: AppRadius.pillBorder,
      ),
      child: Text(
        _roleLabel(role),
        style: AppTypography.labelMd.copyWith(color: color),
      ),
    );
  }
}

// ── Role picker sheet ─────────────────────────────────────────────────────────

class _RolePickerSheet extends StatelessWidget {
  const _RolePickerSheet({required this.user, required this.onRoleSelected});

  final User user;
  final Future<void> Function(String role) onRoleSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.outlineVariant,
                  borderRadius: AppRadius.pillBorder,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Set role for ${user.displayName}',
              style: AppTypography.titleMd.copyWith(color: AppColors.heading),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Current: ${_roleLabel(user.role)}',
              style: AppTypography.bodySm.copyWith(color: AppColors.textMuted),
            ),
            const SizedBox(height: AppSpacing.sm),
            ..._roles.map(
              (role) => _RoleOption(
                role: role,
                isCurrentRole: role == user.role,
                // A campus admin's campuses can be changed by picking the role
                // again.
                selectable: role != user.role || role == _campusAdmin,
                onTap: () async {
                  Navigator.pop(context);
                  await onRoleSelected(role);
                },
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
  }
}

class _RoleOption extends StatelessWidget {
  const _RoleOption({
    required this.role,
    required this.isCurrentRole,
    required this.selectable,
    required this.onTap,
  });

  final String role;
  final bool isCurrentRole;
  final bool selectable;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = _roleColor(role);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.defaultRadius),
        onTap: selectable ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.sm,
            horizontal: AppSpacing.xs,
          ),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                _roleLabel(role),
                style: AppTypography.bodyLg.copyWith(
                  color: selectable ? AppColors.onSurface : AppColors.textMuted,
                ),
              ),
              if (isCurrentRole && role == _campusAdmin) ...[
                const SizedBox(width: AppSpacing.xs),
                Text(
                  'Change campuses',
                  style: AppTypography.labelMd.copyWith(
                    color: AppColors.secondary,
                  ),
                ),
              ],
              const Spacer(),
              if (isCurrentRole)
                const Icon(
                  Icons.check_rounded,
                  size: 18,
                  color: AppColors.secondary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Campus picker sheet ───────────────────────────────────────────────────────

/// Picks the campuses a campus admin manages. Pops `{branchId: name}` (1+
/// entries, in branch order), or nothing when dismissed.
class _CampusPickerSheet extends ConsumerStatefulWidget {
  const _CampusPickerSheet({required this.user, required this.initial});

  final User user;

  /// The campuses already assigned, `{id: name}`.
  final Map<String, String> initial;

  @override
  ConsumerState<_CampusPickerSheet> createState() => _CampusPickerSheetState();
}

class _CampusPickerSheetState extends ConsumerState<_CampusPickerSheet> {
  late final Map<String, String> _selected = {...widget.initial};

  @override
  Widget build(BuildContext context) {
    final branchesAsync = ref.watch(branchesProvider);
    final branches = branchesAsync.valueOrNull;

    // Every branch, plus any assigned campus missing from the list so it can
    // still be unticked.
    final options = <String, String>{
      if (branches != null)
        for (final b in [
          ...branches,
        ]..sort((a, b) => a.order.compareTo(b.order)))
          b.id: b.name,
      for (final e in widget.initial.entries)
        if (!(branches ?? const []).any((b) => b.id == e.key)) e.key: e.value,
    };

    // A Material (not a decorated box) so the checkbox tiles' ink shows.
    return Material(
      color: AppColors.surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Campuses for ${widget.user.displayName}',
                style: AppTypography.titleMd.copyWith(color: AppColors.heading),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'They manage these campuses’ announcements, events and campus '
                'details. Pick at least one.',
                style: AppTypography.bodySm.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              if (branchesAsync.isLoading && branches == null)
                const Padding(
                  padding: EdgeInsets.all(AppSpacing.md),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: AppColors.secondary,
                    ),
                  ),
                )
              else
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final e in options.entries)
                        CheckboxListTile(
                          value: _selected.containsKey(e.key),
                          title: Text(
                            e.value,
                            style: AppTypography.bodyLg.copyWith(
                              color: AppColors.onSurface,
                            ),
                          ),
                          activeColor: AppColors.secondary,
                          contentPadding: EdgeInsets.zero,
                          onChanged: (v) => setState(() {
                            if (v ?? false) {
                              _selected[e.key] = e.value;
                            } else {
                              _selected.remove(e.key);
                            }
                          }),
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _selected.isEmpty
                      ? null
                      : () => Navigator.pop(context, {
                          for (final id in options.keys)
                            if (_selected.containsKey(id)) id: _selected[id]!,
                        }),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.secondary,
                    foregroundColor: AppColors.onSecondary,
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.buttonBorder,
                    ),
                  ),
                  child: Text(
                    'Make campus admin',
                    style: AppTypography.bodyLg.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.onSecondary,
                    ),
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
