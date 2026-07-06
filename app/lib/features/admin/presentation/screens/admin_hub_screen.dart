import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/shared/providers/auth_provider.dart';

/// Hub screen for the in-app admin console.
/// Guarded by [isAdminProvider]: shows a spinner while checking, a denial
/// message when the user is not admin, and four navigation cards otherwise.
class AdminHubScreen extends ConsumerWidget {
  const AdminHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdminAsync = ref.watch(isAdminProvider);

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
      body: isAdminAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.secondary),
        ),
        error: (_, _) => Center(
          child: Text(
            'You do not have admin access.',
            style: AppTypography.bodyLg.copyWith(color: AppColors.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ),
        data: (isAdmin) {
          if (!isAdmin) {
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

          return ListView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.gutter,
              vertical: AppSpacing.md,
            ),
            children: const [
              _HubCard(
                icon: Icons.campaign_rounded,
                title: 'Announcements',
                subtitle: 'Manage news, notices, and ministry updates',
                route: '/admin/announcements',
              ),
              SizedBox(height: AppSpacing.sm),
              _HubCard(
                icon: Icons.event_rounded,
                title: 'Events',
                subtitle: 'Schedule and edit upcoming church events',
                route: '/admin/events',
              ),
              SizedBox(height: AppSpacing.sm),
              _HubCard(
                icon: Icons.location_city_rounded,
                title: 'Branches',
                subtitle: 'Add, edit, and reorder campus branches',
                route: '/admin/branches',
              ),
              SizedBox(height: AppSpacing.sm),
              _HubCard(
                icon: Icons.group_rounded,
                title: 'Users',
                subtitle: 'View members and manage roles',
                route: '/admin/users',
              ),
              SizedBox(height: AppSpacing.sm),
              _HubCard(
                icon: Icons.menu_book_rounded,
                title: 'Bible Reading',
                subtitle: 'Set daily scripture readings and prayers',
                route: '/admin/bible-reading',
              ),
              SizedBox(height: AppSpacing.sm),
              _HubCard(
                icon: Icons.mic_rounded,
                title: 'Sermons',
                subtitle: 'Add, edit, feature, and manage preached messages',
                route: '/admin/sermons',
              ),
            ],
          );
        },
      ),
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
