import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/features/connect/presentation/screens/new_here_screen.dart';
import 'package:kharis_app/features/connect/presentation/screens/testimony_screen.dart';
import 'package:kharis_app/features/feedback/data/app_feedback_repository.dart';
import 'package:kharis_app/features/feedback/presentation/feedback_sheet.dart';
import 'package:kharis_app/shared/models/user.dart';
import 'package:kharis_app/shared/providers/auth_provider.dart';
import 'package:kharis_app/shared/providers/branch_provider.dart';
import 'package:kharis_app/shared/providers/theme_provider.dart';
import 'package:kharis_app/shared/widgets/branch_picker_sheet.dart';

import 'notifications_settings_screen.dart';

/// Church contact page (verified 200). The old `/help` path is a 404.
const String kHelpUrl = 'https://kharis.org/contact-us/';

/// Church privacy policy (verified 200). kharis.org publishes no terms of
/// service page, so none is linked.
const String kPrivacyPolicyUrl = 'https://kharis.org/privacy-policy/';

/// The installed build, e.g. `1.0.0 (1)`, read from the platform bundle so
/// More always reports what is actually running.
final appVersionProvider = FutureProvider<String>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return '${info.version} (${info.buildNumber})';
});

/// Opens [url] in the system browser.
Future<void> _openExternal(String url) =>
    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

/// Pushes a full-screen page above the tab shell.
void _pushPage(BuildContext context, Widget page) {
  unawaited(
    Navigator.of(
      context,
      rootNavigator: true,
    ).push(MaterialPageRoute<void>(builder: (_) => page)),
  );
}

/// The profile hub ("More"): identity card, grouped app list, sign in or
/// out, and the installed version.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    final isAdmin = ref.watch(isAdminProvider).valueOrNull ?? false;
    final branch = ref.watch(currentBranchProvider).valueOrNull;
    final version = ref.watch(appVersionProvider).valueOrNull;
    final signedIn =
        user != null && user.role != 'guest' && user.email.isNotEmpty;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 150),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'More',
                style: AppTypography.display(
                  size: 30,
                  weight: FontWeight.w700,
                ).copyWith(color: context.kc.onBg),
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
                      accent: context.kc.accentInk,
                      onTap: () => context.push('/admin'),
                      isLast: true,
                    ),
                  ],
                ),
                const SizedBox(height: 22),
              ],

              const _SectionLabel('Appearance'),
              const SizedBox(height: 8),
              const _ThemeCard(),

              const SizedBox(height: 22),

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
                    icon: Icons.edit_note_rounded,
                    label: 'My Notes',
                    onTap: () => context.push('/notes'),
                  ),
                  _MoreMenuItem(
                    icon: Icons.favorite_border_rounded,
                    label: 'Favorites',
                    onTap: () => context.push('/favorites'),
                  ),
                  _MoreMenuItem(
                    icon: Icons.queue_music_rounded,
                    label: 'My Playlists',
                    onTap: () => context.push('/playlists'),
                  ),
                  _MoreMenuItem(
                    icon: Icons.sync_alt,
                    label: 'Switch Branch',
                    value: branch ?? kAllCampusesLabel,
                    onTap: () => context.push('/branch-selection'),
                  ),
                  _MoreMenuItem(
                    icon: Icons.notifications_none,
                    label: 'Notifications',
                    accent: AppColors.accentPink,
                    onTap: () =>
                        _pushPage(context, const NotificationsSettingsScreen()),
                  ),
                  _MoreMenuItem(
                    icon: Icons.volunteer_activism,
                    label: 'Give',
                    accent: context.kc.accentInk,
                    isLast: true,
                    onTap: () => context.go('/giving'),
                  ),
                ],
              ),

              const SizedBox(height: 22),

              const _SectionLabel('Connect'),
              const SizedBox(height: 8),
              _MenuCard(
                children: [
                  _MoreMenuItem(
                    icon: Icons.waving_hand_outlined,
                    label: "I'm new here",
                    onTap: () => _pushPage(context, const NewHereScreen()),
                  ),
                  _MoreMenuItem(
                    icon: Icons.record_voice_over_outlined,
                    label: 'Share a testimony',
                    isLast: true,
                    onTap: () => _pushPage(context, const TestimonyScreen()),
                  ),
                ],
              ),

              const SizedBox(height: 22),

              const _SectionLabel('Support'),
              const SizedBox(height: 8),
              _MenuCard(
                children: [
                  _MoreMenuItem(
                    icon: Icons.star_border_rounded,
                    label: 'Rate & Feedback',
                    accent: context.kc.accentInk,
                    onTap: () => unawaited(
                      showFeedbackSheet(
                        context,
                        ref,
                        source: FeedbackSource.settings,
                      ),
                    ),
                  ),
                  _MoreMenuItem(
                    icon: Icons.help_outline,
                    label: 'Help & Support',
                    external: true,
                    onTap: () => unawaited(_openExternal(kHelpUrl)),
                  ),
                  _MoreMenuItem(
                    icon: Icons.privacy_tip_outlined,
                    label: 'Privacy Policy',
                    external: true,
                    isLast: true,
                    onTap: () => unawaited(_openExternal(kPrivacyPolicyUrl)),
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
                      accent: context.kc.accentInk,
                      isLast: true,
                      onTap: () => context.push('/login'),
                    ),
                  ],
                ),

              const SizedBox(height: 22),
              Center(
                child: Text(
                  version == null ? 'Kharis Church' : 'Kharis Church $version',
                  key: const ValueKey('app-version'),
                  style: AppTypography.ui(
                    size: 11,
                  ).copyWith(color: context.kc.muted),
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
        backgroundColor: context.kc.surface,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.cardBorder),
        title: Text(
          'Sign out',
          style: AppTypography.ui(
            size: 16,
            weight: FontWeight.w700,
          ).copyWith(color: context.kc.onBg),
        ),
        content: Text(
          'Are you sure you want to sign out?',
          style: AppTypography.ui(size: 14).copyWith(color: context.kc.muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Cancel',
              style: AppTypography.ui(
                size: 14,
                weight: FontWeight.w600,
              ).copyWith(color: context.kc.muted),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Sign out',
              style: AppTypography.ui(
                size: 14,
                weight: FontWeight.w700,
              ).copyWith(color: AppColors.danger),
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
        color: context.kc.surface,
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
                  style: AppTypography.ui(
                    size: 17,
                    weight: FontWeight.w700,
                  ).copyWith(color: context.kc.onBg),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.ui(
                    size: 13,
                  ).copyWith(color: context.kc.muted),
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
          color: context.kc.chipBg,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Text(
          'Edit',
          style: AppTypography.ui(
            size: 13,
            weight: FontWeight.w700,
          ).copyWith(color: context.kc.onChip),
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
        color: AppColors.primary,
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
      style: AppTypography.display(
        size: 22,
        weight: FontWeight.w700,
      ).copyWith(color: AppColors.onPrimary),
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
        color: context.kc.surface,
        borderRadius: AppRadius.cardBorder,
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Join the Kharis family',
            style: AppTypography.display(
              size: 18,
              weight: FontWeight.w700,
            ).copyWith(color: context.kc.onBg),
          ),
          const SizedBox(height: 6),
          Text(
            'Sign in to keep your notes, playlists and branch on every device.',
            style: AppTypography.ui(
              size: 13,
              height: 1.5,
            ).copyWith(color: context.kc.muted),
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
          color: filled ? context.kc.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.button),
          border: filled
              ? null
              : Border.all(color: context.kc.outline, width: 1.5),
        ),
        child: Text(
          label,
          style: AppTypography.ui(
            size: 14,
            weight: FontWeight.w700,
          ).copyWith(color: filled ? context.kc.onAccent : context.kc.onBg),
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
        style: AppTypography.ui(
          size: 11,
          weight: FontWeight.w700,
          letterSpacing: 1.2,
        ).copyWith(color: context.kc.muted),
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
        color: context.kc.surface,
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
    this.value,
    this.external = false,
    this.danger = false,
    this.isLast = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? accent;

  /// Current setting shown before the chevron (e.g. the active campus).
  final String? value;

  /// Opens outside the app; shows an external-link glyph instead of a
  /// chevron so the hand-off is not a surprise.
  final bool external;
  final bool danger;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final kc = context.kc;
    final tint = accent ?? kc.onChip;
    return Semantics(
      button: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: isLast
              ? null
              : BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: kc.divider, width: 1),
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
                  style: AppTypography.ui(
                    size: 15,
                    weight: FontWeight.w600,
                  ).copyWith(color: danger ? AppColors.danger : kc.onBg),
                ),
              ),
              if (value != null) ...[
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    value!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: AppTypography.ui(size: 13).copyWith(color: kc.muted),
                  ),
                ),
              ],
              const SizedBox(width: 4),
              Icon(
                external
                    ? Icons.open_in_new_rounded
                    : Icons.chevron_right_rounded,
                color: kc.muted,
                size: external ? 18 : 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Appearance / theme mode ───────────────────────────────────────────────────

/// Light / Dark / System selector. The whole app follows one brightness — this
/// is the single place a member changes it, and the choice is persisted by
/// [themeModeProvider].
class _ThemeCard extends ConsumerWidget {
  const _ThemeCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kc = context.kc;
    final mode = ref.watch(themeModeProvider);

    return Container(
      decoration: BoxDecoration(
        color: kc.surface,
        borderRadius: AppRadius.cardBorder,
        boxShadow: AppShadows.card,
      ),
      clipBehavior: Clip.antiAlias,
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: kc.onChip.withValues(alpha: 0.12),
                  borderRadius: AppRadius.tileBorder,
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.brightness_6_outlined,
                  color: kc.onChip,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  'Theme',
                  style: AppTypography.ui(
                    size: 15,
                    weight: FontWeight.w600,
                  ).copyWith(color: kc.onBg),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _ThemeOption(
                  icon: Icons.light_mode_outlined,
                  label: 'Light',
                  selected: mode == ThemeMode.light,
                  onTap: () =>
                      ref.read(themeModeProvider.notifier).set(ThemeMode.light),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ThemeOption(
                  icon: Icons.dark_mode_outlined,
                  label: 'Dark',
                  selected: mode == ThemeMode.dark,
                  onTap: () =>
                      ref.read(themeModeProvider.notifier).set(ThemeMode.dark),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ThemeOption(
                  icon: Icons.phone_iphone_rounded,
                  label: 'System',
                  selected: mode == ThemeMode.system,
                  onTap: () => ref
                      .read(themeModeProvider.notifier)
                      .set(ThemeMode.system),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  const _ThemeOption({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final kc = context.kc;
    final fg = selected ? kc.onAccent : kc.muted;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? kc.accent : kc.surfaceMuted,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: fg),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.ui(
                  size: 13,
                  weight: FontWeight.w700,
                ).copyWith(color: fg),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
