import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/shared/models/user.dart';
import 'package:kharis_app/shared/providers/auth_provider.dart';

import 'notifications_settings_screen.dart';

/// The profile hub (design-handoff v3): a light "More" screen with the
/// signed-in identity card, a grouped app list, and the sign-out action. All
/// routing, providers, and auth logic are preserved — presentation only.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    final isAdmin = ref.watch(isAdminProvider).valueOrNull ?? false;
    final signedIn = user != null && user.role != 'guest' && user.email.isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.lightBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 150),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'More',
                style: AppTypography.display(size: 30, weight: FontWeight.w700)
                    .copyWith(color: AppColors.textPrimary),
              ),
              const SizedBox(height: 18),

              if (signedIn)
                _ProfileCard(
                  user: user,
                  onEdit: () => context.push('/profile/edit'),
                )
              else
                const _SignedOutCard(),

              const SizedBox(height: 22),

              if (isAdmin) ...[
                const _SectionLabel('Manage'),
                const SizedBox(height: 8),
                _MenuCard(
                  children: [
                    _MoreMenuItem(
                      icon: Icons.shield_outlined,
                      label: 'Admin Console',
                      accent: AppColors.secondary,
                      onTap: () => context.push('/admin'),
                      isLast: true,
                    ),
                  ],
                ),
                const SizedBox(height: 22),
              ],

              const _SectionLabel('App'),
              const SizedBox(height: 8),
              _MenuCard(
                children: [
                  _MoreMenuItem(
                    icon: Icons.auto_stories,
                    label: 'Daily Reading',
                    onTap: () => context.push('/reading'),
                  ),
                  _MoreMenuItem(
                    icon: Icons.volunteer_activism,
                    label: 'My Giving History',
                    accent: AppColors.success,
                    onTap: () => context.go('/giving'),
                  ),
                  _MoreMenuItem(
                    icon: Icons.sync_alt,
                    label: 'Switch Branch',
                    onTap: () => context.push('/branch-selection'),
                  ),
                  _MoreMenuItem(
                    icon: Icons.notifications_none,
                    label: 'Notifications',
                    accent: AppColors.accentPink,
                    onTap: () => Navigator.of(context, rootNavigator: true).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const NotificationsSettingsScreen(),
                      ),
                    ),
                  ),
                  _MoreMenuItem(
                    icon: Icons.help_outline,
                    label: 'Help & Support',
                    isLast: true,
                    onTap: () => unawaited(
                      launchUrl(
                        Uri.parse('https://kharis.org/help'),
                        mode: LaunchMode.externalApplication,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 22),

              if (signedIn)
                _MenuCard(
                  children: [
                    _MoreMenuItem(
                      icon: Icons.logout,
                      label: 'Sign out',
                      accent: AppColors.danger,
                      danger: true,
                      isLast: true,
                      onTap: () => _confirmSignOut(context, ref),
                    ),
                  ],
                )
              else
                _MenuCard(
                  children: [
                    _MoreMenuItem(
                      icon: Icons.login,
                      label: 'Sign in',
                      accent: AppColors.secondary,
                      isLast: true,
                      onTap: () => context.push('/login'),
                    ),
                  ],
                ),

              const SizedBox(height: 22),
              Center(
                child: Text(
                  'Kharis Church v2.0.0',
                  style: AppTypography.ui(size: 11)
                      .copyWith(color: AppColors.textMutedLight),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardWhite,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.cardBorder),
        title: Text(
          'Sign Out',
          style: AppTypography.ui(size: 16, weight: FontWeight.w700)
              .copyWith(color: AppColors.textPrimary),
        ),
        content: Text(
          'Are you sure you want to sign out?',
          style:
              AppTypography.ui(size: 14).copyWith(color: AppColors.textMutedLight),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Cancel',
              style: AppTypography.ui(size: 14, weight: FontWeight.w600)
                  .copyWith(color: AppColors.textMutedLight),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Sign Out',
              style: AppTypography.ui(size: 14, weight: FontWeight.w700)
                  .copyWith(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(authRepositoryProvider).logout();
      // currentUserProvider emits null, so the hub rebuilds to the signed-out
      // state automatically. No navigation needed (browsing stays open).
    }
  }
}

// ── Signed-in profile card ────────────────────────────────────────────────────

String _roleLabel(String role) {
  switch (role) {
    case 'admin':
      return 'Admin';
    case 'guest':
      return 'Guest';
    case 'new_here':
      return 'New here';
    default:
      return 'Member';
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.user, required this.onEdit});

  final User user;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final initial = user.displayName.trim().isNotEmpty
        ? user.displayName.trim()[0].toUpperCase()
        : 'K';
    final subtitle = [
      _roleLabel(user.role),
      if (user.branch != null && user.branch!.isNotEmpty) user.branch!,
    ].join(' \u00b7 ');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: AppRadius.cardBorder,
        boxShadow: AppShadows.card,
      ),
      child: Row(
        children: [
          _Avatar(initial: initial, photoUrl: user.photoUrl),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.ui(size: 17, weight: FontWeight.w700)
                      .copyWith(color: AppColors.textPrimary),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.ui(size: 13)
                      .copyWith(color: AppColors.textMutedLight),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _EditButton(onTap: onEdit),
        ],
      ),
    );
  }
}

class _EditButton extends StatelessWidget {
  const _EditButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.chipLight,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Text(
          'Edit',
          style: AppTypography.ui(size: 13, weight: FontWeight.w700)
              .copyWith(color: AppColors.primary),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.initial, this.photoUrl});

  final String initial;
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 54,
      height: 54,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.secondary],
        ),
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: photoUrl != null && photoUrl!.isNotEmpty
          ? Image.network(
              photoUrl!,
              fit: BoxFit.cover,
              width: 54,
              height: 54,
              gaplessPlayback: true,
              errorBuilder: (_, _, _) => _initialText(),
            )
          : _initialText(),
    );
  }

  Widget _initialText() => Center(
        child: Text(
          initial,
          style: AppTypography.display(size: 22, weight: FontWeight.w700)
              .copyWith(color: AppColors.onPrimary),
        ),
      );
}

// ── Signed-out card ───────────────────────────────────────────────────────────

class _SignedOutCard extends StatelessWidget {
  const _SignedOutCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: AppRadius.cardBorder,
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Join the Kharis family',
            style: AppTypography.display(size: 18, weight: FontWeight.w700)
                .copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            'Sign in to save your branch, follow along, and personalize your experience.',
            style: AppTypography.ui(size: 13, height: 1.5)
                .copyWith(color: AppColors.textMutedLight),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _PillButton(
                  label: 'Sign In',
                  filled: true,
                  onTap: () => context.push('/login'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _PillButton(
                  label: 'Create Account',
                  filled: false,
                  onTap: () => context.push('/register'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.label,
    required this.filled,
    required this.onTap,
  });

  final String label;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: filled ? AppColors.secondary : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.button),
          border: filled
              ? null
              : Border.all(color: AppColors.dividerLight, width: 1.5),
        ),
        child: Text(
          label,
          style: AppTypography.ui(size: 14, weight: FontWeight.w700).copyWith(
            color: filled ? AppColors.onSecondary : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

// ── Section label ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        label.toUpperCase(),
        style: AppTypography.ui(size: 11, weight: FontWeight.w700, letterSpacing: 1.2)
            .copyWith(color: AppColors.textMutedLight),
      ),
    );
  }
}

// ── Menu card + rows ───────────────────────────────────────────────────────────

/// A grouped white card that wraps a set of [_MoreMenuItem] rows.
class _MenuCard extends StatelessWidget {
  const _MenuCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: AppRadius.cardBorder,
        boxShadow: AppShadows.card,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

class _MoreMenuItem extends StatelessWidget {
  const _MoreMenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.accent,
    this.danger = false,
    this.isLast = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? accent;
  final bool danger;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final tint = accent ?? AppColors.primary;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: isLast
            ? null
            : const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: AppColors.dividerLight, width: 1),
                ),
              ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: tint.withValues(alpha: 0.12),
                borderRadius: AppRadius.tileBorder,
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: tint, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: AppTypography.ui(size: 15, weight: FontWeight.w600)
                    .copyWith(
                  color: danger ? AppColors.danger : AppColors.textPrimary,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textMutedLight,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}
