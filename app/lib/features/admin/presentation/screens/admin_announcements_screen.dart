import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/features/home/data/news_repository.dart';
import 'package:kharis_app/features/admin/presentation/widgets/announcement_form_sheet.dart';
import 'package:kharis_app/features/admin/presentation/widgets/announcement_home_status.dart';
import 'package:kharis_app/shared/providers/auth_provider.dart';
import 'package:kharis_app/shared/providers/sermon_provider.dart';

// ── News type options ─────────────────────────────────────────────────────────
//
// The vocabulary lives on the model — see [NewsItem.types]. There is
// deliberately no 'Event' category: an announcement is a message, while an
// event is a dated, located, RSVP-able occurrence managed on the Events
// screen and stored in the `events` collection.

// ── Main screen ───────────────────────────────────────────────────────────────

/// Admin screen: list + CRUD for [NewsItem]. A campus admin sees (and may
/// only manage) their own campuses' announcements.
class AdminAnnouncementsScreen extends ConsumerWidget {
  const AdminAnnouncementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final newsAsync = ref.watch(adminNewsProvider);
    final scope = ref.watch(adminScopeProvider).valueOrNull;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Announcements',
          style: AppTypography.titleMd.copyWith(color: AppColors.heading),
        ),
        iconTheme: const IconThemeData(color: AppColors.heading),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.secondary,
        foregroundColor: AppColors.onSecondary,
        onPressed: () => _openForm(context, ref),
        child: const Icon(Icons.add),
      ),
      body: newsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.secondary),
        ),
        error: (e, _) => Center(
          child: Text(
            'Could not load announcements.',
            style: AppTypography.bodyLg.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ),
        data: (all) {
          final items = [
            for (final n in all)
              if (scope?.canManageCampusNamed(n.branch) ?? false) n,
          ];
          if (items.isEmpty) {
            return Center(
              child: Text(
                'No announcements yet.',
                style: AppTypography.bodyLg.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
            );
          }
          return Column(
            children: [
              const AnnouncementHomeRulesBanner(),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.gutter,
                    AppSpacing.sm,
                    AppSpacing.gutter,
                    AppSpacing.lg + AppSpacing.lg,
                  ),
                  itemCount: items.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (_, index) => _NewsCard(
                    item: items[index],
                    onEdit: () => _openForm(context, ref, item: items[index]),
                    onDelete: () => _confirmDelete(context, ref, items[index]),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _openForm(BuildContext context, WidgetRef ref, {NewsItem? item}) {
    final messenger = ScaffoldMessenger.of(context);
    final repo = ref.read(newsRepositoryProvider);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AnnouncementFormSheet(
        item: item,
        repo: repo,
        onSuccess: (msg) => messenger.showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: AppColors.surfaceElevated,
          ),
        ),
        onError: (msg) => messenger.showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: AppColors.errorContainer,
          ),
        ),
      ),
    );
  }

  void _confirmDelete(
      BuildContext context, WidgetRef ref, NewsItem item) {
    final messenger = ScaffoldMessenger.of(context);
    final repo = ref.read(newsRepositoryProvider);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        title: Text(
          'Delete announcement?',
          style: AppTypography.titleMd.copyWith(color: AppColors.heading),
        ),
        content: Text(
          'This will permanently remove "${item.title}". This cannot be undone.',
          style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: AppTypography.bodySm.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await repo.deleteNews(item.id);
                messenger.showSnackBar(const SnackBar(
                  content: Text('Announcement deleted.'),
                ));
              } catch (e) {
                messenger.showSnackBar(SnackBar(
                  content: Text('Delete failed: $e'),
                  backgroundColor: AppColors.errorContainer,
                ));
              }
            },
            child: Text(
              'Delete',
              style: AppTypography.bodySm.copyWith(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}

// ── List card ─────────────────────────────────────────────────────────────────

class _NewsCard extends StatelessWidget {
  const _NewsCard({
    required this.item,
    required this.onEdit,
    required this.onDelete,
  });

  final NewsItem item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: AppRadius.cardBorder,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (item.imageUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.defaultRadius),
                child: Image.network(
                  item.imageUrl!,
                  width: 64,
                  height: 64,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            if (item.imageUrl != null) const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _TypeChip(type: item.type),
                      const Spacer(),
                      Text(
                        item.expiresAt == null
                            ? _formatDate(item.publishedAt)
                            : '${_formatDate(item.publishedAt)} → '
                                '${_formatDate(item.expiresAt!)}',
                        style: AppTypography.labelMd.copyWith(
                          color: AppColors.textFaint,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  AnnouncementHomeStatusChip(
                    visibility: AnnouncementHomeVisibility.of(item),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    item.title,
                    style: AppTypography.bodyLg.copyWith(
                      color: AppColors.heading,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (item.body != null && item.body!.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      item.body!,
                      style: AppTypography.bodySm.copyWith(
                        color: AppColors.textMuted,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            Column(
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  color: AppColors.onSurfaceVariant,
                  onPressed: onEdit,
                  tooltip: 'Edit',
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18),
                  color: AppColors.error,
                  onPressed: onDelete,
                  tooltip: 'Delete',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final months = [
      'Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec',
    ];
    return '${months[dt.month - 1]} ${dt.day}';
  }
}

// ── Type chip ─────────────────────────────────────────────────────────────────

/// Category pill for an announcement. The megaphone is the announcement mark
/// throughout the app — events carry a calendar mark instead — so an admin can
/// tell the two content kinds apart at a glance.
class _TypeChip extends StatelessWidget {
  const _TypeChip({required this.type});

  final String type;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.secondary.withValues(alpha: 0.15),
        borderRadius: AppRadius.pillBorder,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.campaign_rounded,
            size: 12,
            color: AppColors.secondary,
          ),
          const SizedBox(width: 4),
          Text(
            type,
            style: AppTypography.labelMd.copyWith(color: AppColors.secondary),
          ),
        ],
      ),
    );
  }
}
