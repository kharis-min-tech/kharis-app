import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/core/utils/service_time.dart';
import 'package:kharis_app/features/admin/presentation/widgets/announcement_form_sheet.dart';
import 'package:kharis_app/features/admin/presentation/widgets/branch_venue_form_sheet.dart';
import 'package:kharis_app/features/admin/presentation/widgets/event_form_sheet.dart';
import 'package:kharis_app/features/calendar/data/event_repository.dart';
import 'package:kharis_app/features/home/data/news_repository.dart';
import 'package:kharis_app/features/onboarding/data/branch_repository.dart';
import 'package:kharis_app/shared/providers/admin_provider.dart';
import 'package:kharis_app/shared/providers/sermon_provider.dart';

// Announcement categories live on the model — see [NewsItem.types]. There is
// deliberately no 'Event' category: events are dated, located, RSVP-able and
// live in the `events` collection.

// ── Main screen ───────────────────────────────────────────────────────────────

/// Drill-down screen for a single branch. Shows branch info, events scoped
/// to this branch, and announcements scoped to this branch.
class AdminBranchDetailScreen extends ConsumerWidget {
  const AdminBranchDetailScreen({
    super.key,
    required this.branchId,
    required this.branchName,
  });

  final String branchId;
  final String branchName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branchesAsync = ref.watch(branchesProvider);
    final eventsAsync = ref.watch(upcomingEventsProvider(branchName));
    final newsAsync = ref.watch(adminNewsProvider);

    final branch = branchesAsync.valueOrNull
        ?.where((b) => b.id == branchId)
        .firstOrNull;

    final events = eventsAsync.valueOrNull ?? [];
    final branchNews = (newsAsync.valueOrNull ?? [])
        .where((n) => n.branch == branchName)
        .toList();

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        bottom: branch != null
            ? PreferredSize(
                preferredSize: const Size.fromHeight(2),
                child: Container(
                  height: 2,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: branch.gradient),
                  ),
                ),
              )
            : null,
        title: Text(
          branchName,
          style: AppTypography.titleMd.copyWith(color: AppColors.heading),
        ),
        iconTheme: const IconThemeData(color: AppColors.heading),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.gutter,
          AppSpacing.sm,
          AppSpacing.gutter,
          AppSpacing.lg + AppSpacing.lg,
        ),
        children: [
          _InfoCard(
            branch: branch,
            onEdit: branch == null
                ? null
                : () => _openVenueForm(context, ref, branch),
          ),
          const SizedBox(height: AppSpacing.sm),
          _EventsCard(
            branchName: branchName,
            events: events,
            isLoading: eventsAsync.isLoading,
            onAdd: () => _openEventForm(context, ref),
            onEdit: (e) => _openEventForm(context, ref, event: e),
            onDelete: (e) => _confirmDeleteEvent(context, ref, e),
          ),
          const SizedBox(height: AppSpacing.sm),
          _AnnouncementsCard(
            branchName: branchName,
            items: branchNews,
            isLoading: newsAsync.isLoading,
            onAdd: () => _openNewsForm(context, ref),
            onEdit: (n) => _openNewsForm(context, ref, item: n),
            onDelete: (n) => _confirmDeleteNews(context, ref, n),
          ),
        ],
      ),
    );
  }

  /// Opens the venue editor for this branch. Writes `address`,
  /// `meetingDays` and `meetingTime` through [BranchRepository.updateBranch],
  /// preserving every other field so a venue edit cannot blank the branch's
  /// name, gradient, image, order or group.
  void _openVenueForm(BuildContext context, WidgetRef ref, Branch branch) {
    final messenger = ScaffoldMessenger.of(context);
    final repo = ref.read(branchRepositoryProvider);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BranchVenueFormSheet(
        branch: branch,
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

  void _openEventForm(BuildContext context, WidgetRef ref, {Event? event}) {
    final messenger = ScaffoldMessenger.of(context);
    final eventRepo = ref.read(eventRepositoryProvider);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EventFormSheet(
        event: event,
        scopeBranch: branchName,
        eventRepo: eventRepo,
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

  void _openNewsForm(BuildContext context, WidgetRef ref, {NewsItem? item}) {
    final messenger = ScaffoldMessenger.of(context);
    final repo = ref.read(newsRepositoryProvider);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AnnouncementFormSheet(
        item: item,
        scopeBranch: branchName,
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

  void _confirmDeleteEvent(
      BuildContext context, WidgetRef ref, Event event) {
    final messenger = ScaffoldMessenger.of(context);
    final eventRepo = ref.read(eventRepositoryProvider);
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        title: Text(
          'Delete Event',
          style: AppTypography.titleMd.copyWith(color: AppColors.heading),
        ),
        content: Text(
          'Remove "${event.title}" from this branch?',
          style: AppTypography.bodyLg.copyWith(color: AppColors.onSurface),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: AppTypography.bodyLg
                  .copyWith(color: AppColors.onSurfaceVariant),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await eventRepo.deleteEvent(event.id);
                messenger.showSnackBar(const SnackBar(
                  content: Text('Event deleted.'),
                  backgroundColor: AppColors.surfaceElevated,
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
              style: AppTypography.bodyLg.copyWith(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteNews(
      BuildContext context, WidgetRef ref, NewsItem item) {
    final messenger = ScaffoldMessenger.of(context);
    final newsRepo = ref.read(newsRepositoryProvider);
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        title: Text(
          'Delete Announcement',
          style: AppTypography.titleMd.copyWith(color: AppColors.heading),
        ),
        content: Text(
          'Remove "${item.title}"?',
          style: AppTypography.bodyLg.copyWith(color: AppColors.onSurface),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: AppTypography.bodyLg
                  .copyWith(color: AppColors.onSurfaceVariant),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await newsRepo.deleteNews(item.id);
                messenger.showSnackBar(const SnackBar(
                  content: Text('Announcement deleted.'),
                  backgroundColor: AppColors.surfaceElevated,
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
              style: AppTypography.bodyLg.copyWith(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section card wrapper ──────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.label,
    required this.child,
    this.trailing,
  });

  final String label;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: AppRadius.cardBorder,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.sm, AppSpacing.sm, AppSpacing.xs, 0,
            ),
            child: Row(
              children: [
                Text(
                  label,
                  style: AppTypography.labelMd
                      .copyWith(color: AppColors.onSurfaceVariant),
                ),
                const Spacer(),
                ?trailing,
              ],
            ),
          ),
          const Divider(
            color: AppColors.outlineVariant,
            height: AppSpacing.sm,
            thickness: 0.5,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.sm, 0, AppSpacing.sm, AppSpacing.sm,
            ),
            child: child,
          ),
        ],
      ),
    );
  }
}

// ── Branch info section ───────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.branch, required this.onEdit});

  final Branch? branch;

  /// `null` until the branch has loaded — no edit affordance before there is
  /// something to edit.
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final b = branch;
    return _SectionCard(
      label: 'BRANCH INFO',
      trailing: TextButton.icon(
        onPressed: onEdit,
        icon: const Icon(
          Icons.edit_outlined,
          size: 14,
          color: AppColors.secondary,
        ),
        label: Text(
          'Edit venue',
          style: AppTypography.bodySm.copyWith(color: AppColors.secondary),
        ),
      ),
      child: b == null
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Text(
                'Loading branch info...',
                style: AppTypography.bodySm.copyWith(color: AppColors.textMuted),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InfoRow(label: 'Name', value: b.name),
                _InfoRow(label: 'Subtitle', value: b.subtitle),
                _InfoRow(label: 'Group', value: b.group),
                _InfoRow(label: 'Address', value: b.address ?? 'Not set'),
                _InfoRow(
                  label: 'Meeting days',
                  value: b.meetingDays ?? 'Not set',
                ),
                // Normalised: the web portal writes 24-hour '14:00', the
                // Flutter admin and seed data write '2:00 PM'.
                _InfoRow(
                  label: 'Meeting time',
                  value: formatServiceTime(b.meetingTime) ?? 'Not set',
                ),
              ],
            ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style:
                  AppTypography.labelMd.copyWith(color: AppColors.textMuted),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTypography.bodySm.copyWith(color: AppColors.onSurface),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Branch events section ─────────────────────────────────────────────────────

class _EventsCard extends StatelessWidget {
  const _EventsCard({
    required this.branchName,
    required this.events,
    required this.isLoading,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });

  final String branchName;
  final List<Event> events;
  final bool isLoading;
  final VoidCallback onAdd;
  final void Function(Event) onEdit;
  final void Function(Event) onDelete;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      label: 'BRANCH EVENTS',
      trailing: IconButton(
        icon: const Icon(Icons.add_circle_outline,
            size: 20, color: AppColors.secondary),
        onPressed: onAdd,
        tooltip: 'Add Event',
      ),
      child: isLoading
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Center(
                child: CircularProgressIndicator(color: AppColors.secondary),
              ),
            )
          : events.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  child: Text(
                    'No events for this branch yet.',
                    style: AppTypography.bodySm
                        .copyWith(color: AppColors.textMuted),
                  ),
                )
              : Column(
                  children: [
                    for (int i = 0; i < events.length; i++) ...[
                      if (i > 0)
                        const Divider(
                          color: AppColors.outlineVariant,
                          height: 1,
                          thickness: 0.5,
                        ),
                      _EventRow(
                        event: events[i],
                        onEdit: () => onEdit(events[i]),
                        onDelete: () => onDelete(events[i]),
                      ),
                    ],
                  ],
                ),
    );
  }
}

class _EventRow extends StatelessWidget {
  const _EventRow({
    required this.event,
    required this.onEdit,
    required this.onDelete,
  });

  final Event event;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('MMM d, y');
    final timeFmt = DateFormat('h:mm a');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        event.title,
                        style: AppTypography.bodySm.copyWith(
                          color: AppColors.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (isWebsiteEvent(event)) ...[
                      const SizedBox(width: AppSpacing.xs),
                      const FromWebsiteChip(),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${dateFmt.format(event.startTime)}, ${timeFmt.format(event.startTime)}'
                  '${event.branch == null ? ' · All campuses' : ''}',
                  style: AppTypography.labelMd
                      .copyWith(color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 16),
            color: AppColors.onSurfaceVariant,
            onPressed: onEdit,
            tooltip: 'Edit',
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 16),
            color: AppColors.error,
            onPressed: onDelete,
            tooltip: 'Delete',
          ),
        ],
      ),
    );
  }
}

// ── Branch announcements section ──────────────────────────────────────────────

class _AnnouncementsCard extends StatelessWidget {
  const _AnnouncementsCard({
    required this.branchName,
    required this.items,
    required this.isLoading,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });

  final String branchName;
  final List<NewsItem> items;
  final bool isLoading;
  final VoidCallback onAdd;
  final void Function(NewsItem) onEdit;
  final void Function(NewsItem) onDelete;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      label: 'BRANCH ANNOUNCEMENTS',
      trailing: IconButton(
        icon: const Icon(Icons.add_circle_outline,
            size: 20, color: AppColors.secondary),
        onPressed: onAdd,
        tooltip: 'Add Announcement',
      ),
      child: isLoading
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Center(
                child: CircularProgressIndicator(color: AppColors.secondary),
              ),
            )
          : items.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  child: Text(
                    'No announcements for this branch yet.',
                    style: AppTypography.bodySm
                        .copyWith(color: AppColors.textMuted),
                  ),
                )
              : Column(
                  children: [
                    for (int i = 0; i < items.length; i++) ...[
                      if (i > 0)
                        const Divider(
                          color: AppColors.outlineVariant,
                          height: 1,
                          thickness: 0.5,
                        ),
                      _NewsRow(
                        item: items[i],
                        onEdit: () => onEdit(items[i]),
                        onDelete: () => onDelete(items[i]),
                      ),
                    ],
                  ],
                ),
    );
  }
}

class _NewsRow extends StatelessWidget {
  const _NewsRow({
    required this.item,
    required this.onEdit,
    required this.onDelete,
  });

  final NewsItem item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('MMM d, y');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: AppTypography.bodySm.copyWith(
                    color: AppColors.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xs, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceSubtle,
                        borderRadius: AppRadius.pillBorder,
                      ),
                      child: Text(
                        item.type,
                        style: AppTypography.labelMd
                            .copyWith(color: AppColors.primary),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      dateFmt.format(item.publishedAt),
                      style: AppTypography.labelMd
                          .copyWith(color: AppColors.textMuted),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 16),
            color: AppColors.onSurfaceVariant,
            onPressed: onEdit,
            tooltip: 'Edit',
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 16),
            color: AppColors.error,
            onPressed: onDelete,
            tooltip: 'Delete',
          ),
        ],
      ),
    );
  }
}
