import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/shared/models/campus_config.dart';
import 'package:kharis_app/shared/providers/auth_provider.dart';
import 'package:url_launcher/url_launcher.dart';

/// Where branches, events, announcements and live are managed now.
const String kContentStudioUrl =
    'https://kharis-content.itadmin-a94.workers.dev';

/// Hub screen for the in-app Studio.
/// Driven by [adminScopeProvider]: a spinner while checking, a denial message
/// for non-admins, Notifications for every Studio user and Team access for a
/// super admin. A branch admin's branches are named in the header. App
/// content lives in the Kharis Content Studio, which the note links to.
class AdminHubScreen extends ConsumerWidget {
  const AdminHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scopeAsync = ref.watch(adminScopeProvider);

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Admin',
          style: AppTypography.titleMd.copyWith(color: AppColors.heading),
        ),
        iconTheme: const IconThemeData(color: AppColors.heading),
      ),
      body: scopeAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.secondary),
        ),
        error: (_, _) => Center(
          child: Text(
            'You do not have admin access.',
            style: AppTypography.bodyLg.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        data: (scope) {
          if (!scope.canUseStudio) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Text(
                  'You do not have admin access.',
                  style: AppTypography.bodyLg.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final cards = _cardsFor(scope);
          return ListView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.gutter,
              vertical: AppSpacing.md,
            ),
            children: [
              const _ContentStudioNote(),
              const SizedBox(height: AppSpacing.md),
              if (scope.isCampusAdmin) ...[
                _CampusHeader(scope: scope),
                const SizedBox(height: AppSpacing.md),
              ],
              for (var i = 0; i < cards.length; i++) ...[
                if (i > 0) const SizedBox(height: AppSpacing.sm),
                cards[i],
              ],
            ],
          );
        },
      ),
    );
  }

  /// The sections [scope] may open, in hub order.
  static List<_HubCard> _cardsFor(AdminScope scope) {
    final superAdmin = scope.isSuperAdmin;
    return [
      _HubCard(
        icon: Icons.notifications_rounded,
        title: 'Notifications',
        subtitle: superAdmin
            ? 'Send a push to everyone, one branch or staff phones'
            : 'Send a push to your branch or staff phones',
        route: '/admin/notifications',
      ),
      if (superAdmin)
        const _HubCard(
          icon: Icons.group_rounded,
          title: 'Team access',
          subtitle: 'Manage roles and branch admins',
          route: '/admin/users',
        ),
    ];
  }
}

/// Points admins at the Kharis Content Studio for app content.
class _ContentStudioNote extends StatelessWidget {
  const _ContentStudioNote();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceDark,
      borderRadius: AppRadius.cardBorder,
      child: InkWell(
        borderRadius: AppRadius.cardBorder,
        onTap: () => unawaited(
          launchUrl(
            Uri.parse(kContentStudioUrl),
            mode: LaunchMode.externalApplication,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Row(
            children: [
              const Icon(
                Icons.info_outline_rounded,
                color: AppColors.secondary,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Content (branches, events, announcements, live) is managed '
                  'in the Kharis Content Studio.',
                  style: AppTypography.bodySm.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              const Icon(
                Icons.open_in_new_rounded,
                color: AppColors.textFaint,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Names the branches a branch admin manages, so it is clear whose
/// notifications they send.
class _CampusHeader extends StatelessWidget {
  const _CampusHeader({required this.scope});

  final AdminScope scope;

  @override
  Widget build(BuildContext context) {
    final names = scope.branchNames.toList()..sort();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'BRANCH ADMIN',
          style: AppTypography.labelMd.copyWith(color: AppColors.textMuted),
        ),
        const SizedBox(height: 2),
        Text(
          names.isEmpty ? 'Your branch' : names.join(' · '),
          style: AppTypography.titleMd.copyWith(color: AppColors.heading),
        ),
        const SizedBox(height: 2),
        Text(
          'You send notifications for '
          '${names.length == 1 ? 'this branch' : 'these branches'}.',
          style: AppTypography.bodySm.copyWith(color: AppColors.textMuted),
        ),
      ],
    );
  }
}

class _HubCard extends StatelessWidget {
  const _HubCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.route,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String route;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceDark,
      borderRadius: AppRadius.cardBorder,
      child: InkWell(
        borderRadius: AppRadius.cardBorder,
        onTap: () => context.push(route),
        splashColor: AppColors.secondary.withValues(alpha: 0.08),
        highlightColor: AppColors.secondary.withValues(alpha: 0.04),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm + AppSpacing.xs,
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(icon, color: AppColors.secondary, size: 26),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.titleMd.copyWith(
                        color: AppColors.heading,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: AppTypography.bodySm.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textFaint,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
