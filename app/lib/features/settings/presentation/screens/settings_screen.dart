import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/shared/models/user.dart';
import 'package:kharis_app/shared/providers/auth_provider.dart';

import 'notifications_settings_screen.dart';

/// The profile hub: identity, account actions, admin entry (when admin), and
/// the gateway between the signed-in user and the rest of the platform.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    final isAdmin = ref.watch(isAdminProvider).valueOrNull ?? false;
    final signedIn = user != null && user.role != 'guest' && user.email.isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.surfaceDark,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 150),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Profile',
                style: AppTypography.headlineLg.copyWith(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: AppColors.heading,
                ),
              ),
              const SizedBox(height: 20),

              if (signedIn)
                _ProfileCard(
                  user: user,
                  onTap: () => context.push('/profile/edit'),
                )
              else
                const _SignedOutCard(),

              const SizedBox(height: 20),

              if (isAdmin) ...[
                const _SectionLabel('Manage'),
                _MoreMenuItem(
                  icon: Icons.shield_outlined,
                  label: 'Admin Console',
                  accent: AppColors.secondary,
                  onTap: () => context.push('/admin'),
                  isLast: true,
                ),
                const SizedBox(height: 22),
              ],

              const _SectionLabel('Account'),
              _MoreMenuItem(
                icon: Icons.auto_stories,
                label: 'Daily Reading',
                onTap: () => context.push('/reading'),
              ),
              _MoreMenuItem(
                icon: Icons.volunteer_activism,
                label: 'My Giving History',
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

              const SizedBox(height: 32),

              if (signedIn)
                _AuthAction(
                  label: 'SIGN OUT',
                  color: AppColors.error,
                  onTap: () => _confirmSignOut(context, ref),
                )
              else
                _AuthAction(
                  label: 'SIGN IN',
                  color: AppColors.secondary,
                  onTap: () => context.push('/login'),
                ),

              const SizedBox(height: 24),
              Center(
                child: Text(
                  'Kharis Church v2.0.0',
                  style: AppTypography.bodySm.copyWith(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
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
        backgroundColor: AppColors.surfaceElevated,
        title: Text(
          'Sign Out',
          style: AppTypography.bodySm.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.onSurface,
          ),
        ),
        content: Text(
          'Are you sure you want to sign out?',
          style: AppTypography.bodySm.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Cancel',
              style: AppTypography.bodySm.copyWith(color: AppColors.textMuted),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Sign Out',
              style: AppTypography.bodySm.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.error,
              ),
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
  const _ProfileCard({required this.user, required this.onTap});

  final User user;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final initial = user.displayName.trim().isNotEmpty
        ? user.displayName.trim()[0].toUpperCase()
        : 'K';
    final subtitle = [
      _roleLabel(user.role),
      if (user.branch != null && user.branch!.isNotEmpty) user.branch!,
    ].join(' \u00b7 ');

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.secondary.withValues(alpha: 0.22),
              AppColors.accentPink.withValues(alpha: 0.14),
            ],
          ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
          borderRadius: BorderRadius.circular(18),
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
                    style: AppTypography.bodySm.copyWith(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.heading,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: AppTypography.bodySm.copyWith(
                      fontSize: 12.5,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                  if (user.email.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      user.email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodySm.copyWith(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textFaint, size: 20),
          ],
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
          colors: [AppColors.secondary, AppColors.accentPink],
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
          style: AppTypography.bodySm.copyWith(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      );
}

// ── Signed-out card ───────────────────────────────────────────────────────────

class _SignedOutCard extends StatelessWidget {
  const _SignedOutCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.secondary.withValues(alpha: 0.22),
            AppColors.accentPink.withValues(alpha: 0.14),
          ],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Join the Kharis family',
            style: AppTypography.bodyLg.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.heading,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Sign in to save your branch, follow along, and personalize your experience.',
            style: AppTypography.bodySm.copyWith(
              fontSize: 13,
              height: 1.5,
              color: AppColors.onSurfaceVariant,
            ),
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
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: filled ? AppColors.secondary : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: filled
              ? null
              : Border.all(color: Colors.white.withValues(alpha: 0.18)),
        ),
        child: Text(
          label,
          style: AppTypography.labelMd.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: filled ? AppColors.onSecondary : AppColors.onSurface,
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
      padding: const EdgeInsets.only(left: 2, bottom: 4),
      child: Text(
        label.toUpperCase(),
        style: AppTypography.labelMd.copyWith(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          color: AppColors.textMuted,
        ),
      ),
    );
  }
}

// ── Auth action (sign in / sign out) ──────────────────────────────────────────

class _AuthAction extends StatelessWidget {
  const _AuthAction({
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Center(
        child: Text(
          label,
          style: AppTypography.labelMd.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: color,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }
}

// ── Menu row ───────────────────────────────────────────────────────────────────

class _MoreMenuItem extends StatelessWidget {
  const _MoreMenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.accent,
    this.isLast = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? accent;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: isLast
            ? null
            : const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Color(0x0DFFFFFF), width: 1),
                ),
              ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(11),
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: accent ?? AppColors.primary, size: 19),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: AppTypography.bodySm.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.onSurface,
                ),
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textFaint, size: 20),
          ],
        ),
      ),
    );
  }
}
