import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/shared/models/campus_config.dart';
import 'package:kharis_app/shared/providers/auth_provider.dart';

/// Hub screen for the in-app admin console.
/// Driven by [adminScopeProvider]: a spinner while checking, a denial message
/// for non-admins, every section for a super admin, and only their campuses'
/// announcements, events and branch pages for a campus admin (whose
/// campuses are named in the header).
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
      const _HubCard(
        icon: Icons.campaign_rounded,
        title: 'Announcements',
        subtitle: 'Manage news, notices, and ministry updates',
        route: '/admin/announcements',
      ),
      const _HubCard(
        icon: Icons.event_rounded,
        title: 'Events',
        subtitle: 'Schedule and edit upcoming church events',
        route: '/admin/events',
      ),
      _HubCard(
        icon: Icons.location_city_rounded,
        title: superAdmin ? 'Branches' : 'Your branch',
        subtitle: superAdmin
            ? 'Add, edit, and reorder branches'
            : 'Giving, contact, service times and Home layout',
        route: '/admin/branches',
      ),
      _HubCard(
        icon: Icons.notifications_rounded,
        title: 'Notifications',
        subtitle: superAdmin
            ? 'Send a push to everyone, one branch or staff phones'
            : 'Send a push to your branch or staff phones',
        route: '/admin/notifications',
      ),
      if (superAdmin) ...const [
        _HubCard(
          icon: Icons.tune_rounded,
          title: 'App settings',
          subtitle: 'Church-wide giving details and Home layout',
          route: '/admin/settings',
        ),
        _HubCard(
          icon: Icons.group_rounded,
          title: 'Users',
          subtitle: 'View members, manage roles and branch admins',
          route: '/admin/users',
        ),
        _HubCard(
          icon: Icons.menu_book_rounded,
          title: 'Bible Reading',
          subtitle: 'Set daily scripture readings and prayers',
          route: '/admin/bible-reading',
        ),
        _HubCard(
          icon: Icons.auto_stories_rounded,
          title: 'Reading Plans',
          subtitle: 'Schedule a month of readings that advance on their own',
          route: '/admin/reading-plans',
        ),
        _HubCard(
          icon: Icons.mic_rounded,
          title: 'Sermons',
          subtitle: 'Add, edit, feature, and manage preached messages',
          route: '/admin/sermons',
        ),
      ],
    ];
  }
}

/// Names the campuses a campus admin manages, so it is clear whose content
/// the hub's sections cover.
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
          'You manage announcements, events, notifications and branch '
          'details for '
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
