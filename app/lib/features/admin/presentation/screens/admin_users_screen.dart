import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/shared/models/user.dart';
import 'package:kharis_app/shared/providers/admin_provider.dart';

// ── Role metadata ──────────────────────────────────────────────────────────────

const _roles = ['member', 'guest', 'new_here', 'admin'];

String _roleLabel(String role) {
  switch (role) {
    case 'member':
      return 'Member';
    case 'guest':
      return 'Guest';
    case 'new_here':
      return 'New Here';
    case 'admin':
      return 'Admin';
    default:
      return role;
  }
}

Color _roleColor(String role) {
  switch (role) {
    case 'admin':
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

/// Admin screen: view all users and manage their roles.
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
                style: AppTypography.bodySm.copyWith(color: AppColors.textMuted),
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
                style: AppTypography.bodyLg.copyWith(color: AppColors.textMuted),
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
              user: users[i],
              onTap: () => _showRolePicker(context, ref, users[i]),
            ),
          );
        },
      ),
    );
  }

  void _showRolePicker(BuildContext context, WidgetRef ref, User user) {
    final messenger = ScaffoldMessenger.of(context);
    final repo = ref.read(userAdminRepositoryProvider);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _RolePickerSheet(
        user: user,
        onRoleSelected: (newRole) async {
          final isAdminChange =
              newRole == 'admin' || user.role == 'admin';

          if (isAdminChange) {
            final confirmed = await _confirmAdminChange(context, user, newRole);
            if (!confirmed) return;
          }

          try {
            await repo.setRole(user.id, newRole);
            messenger.showSnackBar(
              SnackBar(
                content: Text(
                  'Role updated to ${_roleLabel(newRole)} for ${user.displayName}.',
                ),
                backgroundColor: AppColors.surfaceElevated,
              ),
            );
          } catch (e) {
            messenger.showSnackBar(
              SnackBar(
                content: Text('Update failed: $e'),
                backgroundColor: AppColors.errorContainer,
              ),
            );
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
              : 'This will remove admin access from ${user.displayName}.',
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
  const _UserTile({required this.user, required this.onTap});

  final User user;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final initial = user.displayName.isNotEmpty
        ? user.displayName[0].toUpperCase()
        : '?';

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
                onForegroundImageError:
                    user.photoUrl != null ? (_, _) {} : null,
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
  const _RolePickerSheet({
    required this.user,
    required this.onRoleSelected,
  });

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
              onTap: () async {
                Navigator.pop(context);
                await onRoleSelected(role);
              },
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    );
  }
}

class _RoleOption extends StatelessWidget {
  const _RoleOption({
    required this.role,
    required this.isCurrentRole,
    required this.onTap,
  });

  final String role;
  final bool isCurrentRole;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = _roleColor(role);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.defaultRadius),
        onTap: isCurrentRole ? null : onTap,
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
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                _roleLabel(role),
                style: AppTypography.bodyLg.copyWith(
                  color: isCurrentRole
                      ? AppColors.textMuted
                      : AppColors.onSurface,
                ),
              ),
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
