import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/core/utils/service_time.dart';
import 'package:kharis_app/features/admin/presentation/widgets/announcement_form_sheet.dart';
import 'package:kharis_app/features/admin/presentation/widgets/branch_contact_form_sheet.dart';
import 'package:kharis_app/features/admin/presentation/widgets/branch_service_form_sheet.dart';
import 'package:kharis_app/features/admin/presentation/widgets/branch_venue_form_sheet.dart';
import 'package:kharis_app/features/admin/presentation/widgets/event_form_sheet.dart';
import 'package:kharis_app/features/admin/presentation/widgets/giving_editor.dart';
import 'package:kharis_app/features/admin/presentation/widgets/home_layout_editor.dart';
import 'package:kharis_app/features/admin/presentation/widgets/studio_form_kit.dart';
import 'package:kharis_app/features/admin/providers/content_config_providers.dart';
import 'package:kharis_app/features/calendar/data/event_repository.dart';
import 'package:kharis_app/features/home/data/news_repository.dart';
import 'package:kharis_app/features/onboarding/data/branch_repository.dart';
import 'package:kharis_app/shared/models/campus_config.dart';
import 'package:kharis_app/shared/providers/admin_provider.dart';
import 'package:kharis_app/shared/providers/auth_provider.dart';
import 'package:kharis_app/shared/providers/sermon_provider.dart';

// Announcement categories live on the model — see [NewsItem.types]. There is
// deliberately no 'Event' category: events are dated, located, RSVP-able and
// live in the `events` collection.

// ── Main screen ───────────────────────────────────────────────────────────────

/// A campus's own settings, read from the raw `branches/{id}` doc.
typedef _CampusSettings = ({
  GivingDetails? giving,
  HomeLayout? home,
  CampusContact contact,
  List<CampusService> services,
  List<CampusVenue> venues,
});

_CampusSettings _settingsFrom(Map<String, dynamic> doc) => (
  giving: GivingDetails.fromJson(doc['giving']),
  home: HomeLayout.fromJson(doc['home']),
  contact: CampusContact.fromBranchJson(doc),
  services: allCampusServices(doc['services']),
  venues: [
    if (doc['venues'] is List)
      for (final v in doc['venues'] as List) ?CampusVenue.fromJson(v),
  ],
);

void _snack(
  ScaffoldMessengerState messenger,
  String msg, {
  bool error = false,
}) => messenger.showSnackBar(
  SnackBar(
    content: Text(msg),
    backgroundColor: error
        ? AppColors.errorContainer
        : AppColors.surfaceElevated,
  ),
);

/// Drill-down screen for a single branch: branch info, the campus's own
/// settings (contact, service times, giving, Home layout), and the events
/// and announcements scoped to it.
///
/// A campus admin may only open their own campuses (the router guard sends
/// them back to the hub otherwise), never sees identity fields (name, group)
/// and cannot edit church-wide items listed here. Campus settings are
/// partial `update()`s of their own fields (see [BranchSettingsRepository]).
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
    final scope = ref.watch(adminScopeProvider).valueOrNull;
    final branchesAsync = ref.watch(branchesProvider);
    final eventsAsync = ref.watch(upcomingEventsProvider(branchName));
    final newsAsync = ref.watch(adminNewsProvider);
    final docAsync = ref.watch(adminBranchDocProvider(branchId));
    final churchHome =
        ref.watch(adminChurchHomeProvider).valueOrNull ?? HomeLayout.fallback;

    final branch = branchesAsync.valueOrNull
        ?.where((b) => b.id == branchId)
        .firstOrNull;
    final doc = docAsync.valueOrNull;
    final settings = doc == null ? null : _settingsFrom(doc);

    bool canManage(String? campus) =>
        scope?.canManageCampusNamed(campus) ?? false;
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
      body: scope != null && !scope.canManageBranchId(branchId)
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Text(
                  'You can only manage your own campuses.',
                  style: AppTypography.bodyLg.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.gutter,
                AppSpacing.sm,
                AppSpacing.gutter,
                AppSpacing.lg + AppSpacing.lg,
              ),
              children: [
                _InfoCard(
                  branch: branch,
                  showIdentity: scope?.isSuperAdmin ?? false,
                  onEdit: branch == null || doc == null
                      ? null
                      : () => _openVenueForm(context, ref, branch),
                ),
                const SizedBox(height: AppSpacing.sm),
                if (settings == null)
                  _SectionCard(
                    label: 'CAMPUS SETTINGS',
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.sm,
                      ),
                      child: Text(
                        docAsync.isLoading
                            ? 'Loading campus settings...'
                            : docAsync.hasError
                            ? 'Could not load campus settings.'
                            : 'Campus settings are available once this '
                                  'branch has been saved in Studio.',
                        style: AppTypography.bodySm.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  )
                else ...[
                  _ContactCard(
                    contact: settings.contact,
                    onEdit: () => _openContactForm(context, ref, settings),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _ServicesCard(
                    services: settings.services,
                    venues: settings.venues,
                    onAdd: () => _openServiceForm(context, ref, settings),
                    onEdit: (s) =>
                        _openServiceForm(context, ref, settings, service: s),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _GivingCard(
                    giving: settings.giving,
                    onEdit: () => _openGivingEditor(context, ref, settings),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _HomeLayoutCard(
                    home: settings.home,
                    churchHome: churchHome,
                    onEdit: () =>
                        _openHomeEditor(context, ref, settings, churchHome),
                  ),
                ],
                const SizedBox(height: AppSpacing.sm),
                _EventsCard(
                  branchName: branchName,
                  events: events,
                  isLoading: eventsAsync.isLoading,
                  canManage: (e) => canManage(e.branch),
                  onAdd: () => _openEventForm(context, ref),
                  onEdit: (e) => _openEventForm(context, ref, event: e),
                  onDelete: (e) => _confirmDeleteEvent(context, ref, e),
                ),
                const SizedBox(height: AppSpacing.sm),
                _AnnouncementsCard(
                  branchName: branchName,
                  items: branchNews,
                  isLoading: newsAsync.isLoading,
                  canManage: (n) => canManage(n.branch),
                  onAdd: () => _openNewsForm(context, ref),
                  onEdit: (n) => _openNewsForm(context, ref, item: n),
                  onDelete: (n) => _confirmDeleteNews(context, ref, n),
                ),
              ],
            ),
    );
  }

  /// A campus-settings editor in a bottom sheet.
  void _openEditorSheet(
    BuildContext context, {
    required String title,
    required String subtitle,
    required Widget editor,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StudioSheet(
        children: [
          Text(
            title,
            style: AppTypography.titleMd.copyWith(color: AppColors.heading),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            subtitle,
            style: AppTypography.labelMd.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: AppSpacing.md),
          editor,
        ],
      ),
    );
  }

  void _openContactForm(
    BuildContext context,
    WidgetRef ref,
    _CampusSettings settings,
  ) {
    final messenger = ScaffoldMessenger.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BranchContactFormSheet(
        branchId: branchId,
        branchName: branchName,
        contact: settings.contact,
        repo: ref.read(branchSettingsRepositoryProvider),
        onSuccess: (msg) => _snack(messenger, msg),
        onError: (msg) => _snack(messenger, msg, error: true),
      ),
    );
  }

  void _openServiceForm(
    BuildContext context,
    WidgetRef ref,
    _CampusSettings settings, {
    CampusService? service,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BranchServiceFormSheet(
        branchId: branchId,
        services: settings.services,
        venues: settings.venues,
        service: service,
        repo: ref.read(branchSettingsRepositoryProvider),
        onSuccess: (msg) => _snack(messenger, msg),
        onError: (msg) => _snack(messenger, msg, error: true),
      ),
    );
  }

  void _openGivingEditor(
    BuildContext context,
    WidgetRef ref,
    _CampusSettings settings,
  ) {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final repo = ref.read(branchSettingsRepositoryProvider);
    _openEditorSheet(
      context,
      title: 'Giving',
      subtitle:
          'Where $branchName members give. Leave blank to use the '
          'church-wide details.',
      editor: GivingEditor(
        initial: settings.giving,
        clearLabel: 'Use church-wide giving',
        fallbackHint: 'Not set: members give to the church-wide account.',
        onSave: (giving) async {
          try {
            await repo.setGiving(branchId, giving);
          } catch (e) {
            _snack(messenger, 'Save failed: $e', error: true);
            rethrow;
          }
          _snack(
            messenger,
            giving == null
                ? '$branchName now uses the church-wide giving details.'
                : 'Giving details updated.',
          );
          navigator.pop();
        },
      ),
    );
  }

  void _openHomeEditor(
    BuildContext context,
    WidgetRef ref,
    _CampusSettings settings,
    HomeLayout churchHome,
  ) {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final repo = ref.read(branchSettingsRepositoryProvider);
    _openEditorSheet(
      context,
      title: 'Home layout',
      subtitle: 'The blocks $branchName members see on Home, top to bottom.',
      editor: HomeLayoutEditor(
        initial: settings.home,
        inherited: churchHome,
        inheritedHint:
            'Using the church-wide default. Saving makes a '
            'layout just for this campus.',
        clearLabel: 'Use church-wide default',
        onSave: (home) async {
          try {
            await repo.setHome(branchId, home);
          } catch (e) {
            _snack(messenger, 'Save failed: $e', error: true);
            rethrow;
          }
          _snack(
            messenger,
            home == null
                ? '$branchName now uses the church-wide Home layout.'
                : 'Home layout updated.',
          );
          navigator.pop();
        },
      ),
    );
  }

  /// Opens the venue summary editor for this branch: a partial update of
  /// `address`, `meetingDays` and `meetingTime` only, so a venue edit cannot
  /// touch the branch's name, gradient, image, order or group.
  void _openVenueForm(BuildContext context, WidgetRef ref, Branch branch) {
    final messenger = ScaffoldMessenger.of(context);
    final repo = ref.read(branchSettingsRepositoryProvider);
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

  void _confirmDeleteEvent(BuildContext context, WidgetRef ref, Event event) {
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
              style: AppTypography.bodyLg.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await eventRepo.deleteEvent(event.id);
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Event deleted.'),
                    backgroundColor: AppColors.surfaceElevated,
                  ),
                );
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('Delete failed: $e'),
                    backgroundColor: AppColors.errorContainer,
                  ),
                );
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

  void _confirmDeleteNews(BuildContext context, WidgetRef ref, NewsItem item) {
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
              style: AppTypography.bodyLg.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await newsRepo.deleteNews(item.id);
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Announcement deleted.'),
                    backgroundColor: AppColors.surfaceElevated,
                  ),
                );
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('Delete failed: $e'),
                    backgroundColor: AppColors.errorContainer,
                  ),
                );
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
  const _SectionCard({required this.label, required this.child, this.trailing});

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
              AppSpacing.sm,
              AppSpacing.sm,
              AppSpacing.xs,
              0,
            ),
            child: Row(
              children: [
                Text(
                  label,
                  style: AppTypography.labelMd.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
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
              AppSpacing.sm,
              0,
              AppSpacing.sm,
              AppSpacing.sm,
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
  const _InfoCard({
    required this.branch,
    required this.showIdentity,
    required this.onEdit,
  });

  final Branch? branch;

  /// Name and group are super-admin territory; campus admins don't see them.
  final bool showIdentity;

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
                style: AppTypography.bodySm.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showIdentity) _InfoRow(label: 'Name', value: b.name),
                _InfoRow(label: 'Subtitle', value: b.subtitle),
                if (showIdentity) _InfoRow(label: 'Group', value: b.group),
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
              style: AppTypography.labelMd.copyWith(color: AppColors.textMuted),
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
    required this.canManage,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });

  final String branchName;
  final List<Event> events;
  final bool isLoading;

  /// False for events this admin may not change (a campus admin and an
  /// all-campus event); their edit and delete controls are hidden.
  final bool Function(Event) canManage;
  final VoidCallback onAdd;
  final void Function(Event) onEdit;
  final void Function(Event) onDelete;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      label: 'BRANCH EVENTS',
      trailing: IconButton(
        icon: const Icon(
          Icons.add_circle_outline,
          size: 20,
          color: AppColors.secondary,
        ),
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
                style: AppTypography.bodySm.copyWith(
                  color: AppColors.textMuted,
                ),
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
                    onEdit: canManage(events[i])
                        ? () => onEdit(events[i])
                        : null,
                    onDelete: canManage(events[i])
                        ? () => onDelete(events[i])
                        : null,
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
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

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
                  style: AppTypography.labelMd.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          if (onEdit != null)
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 16),
              color: AppColors.onSurfaceVariant,
              onPressed: onEdit,
              tooltip: 'Edit',
            ),
          if (onDelete != null)
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
    required this.canManage,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });

  final String branchName;
  final List<NewsItem> items;
  final bool isLoading;

  /// False for announcements this admin may not change; their edit and
  /// delete controls are hidden.
  final bool Function(NewsItem) canManage;
  final VoidCallback onAdd;
  final void Function(NewsItem) onEdit;
  final void Function(NewsItem) onDelete;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      label: 'BRANCH ANNOUNCEMENTS',
      trailing: IconButton(
        icon: const Icon(
          Icons.add_circle_outline,
          size: 20,
          color: AppColors.secondary,
        ),
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
                style: AppTypography.bodySm.copyWith(
                  color: AppColors.textMuted,
                ),
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
                    onEdit: canManage(items[i]) ? () => onEdit(items[i]) : null,
                    onDelete: canManage(items[i])
                        ? () => onDelete(items[i])
                        : null,
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
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

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
                        horizontal: AppSpacing.xs,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceSubtle,
                        borderRadius: AppRadius.pillBorder,
                      ),
                      child: Text(
                        item.type,
                        style: AppTypography.labelMd.copyWith(
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      dateFmt.format(item.publishedAt),
                      style: AppTypography.labelMd.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (onEdit != null)
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 16),
              color: AppColors.onSurfaceVariant,
              onPressed: onEdit,
              tooltip: 'Edit',
            ),
          if (onDelete != null)
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

// ── Campus settings sections ──────────────────────────────────────────────────

Widget _editButton(String label, VoidCallback onPressed) => TextButton.icon(
  onPressed: onPressed,
  icon: const Icon(Icons.edit_outlined, size: 14, color: AppColors.secondary),
  label: Text(
    label,
    style: AppTypography.bodySm.copyWith(color: AppColors.secondary),
  ),
);

Widget _mutedLine(String text) => Padding(
  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
  child: Text(
    text,
    style: AppTypography.bodySm.copyWith(color: AppColors.textMuted),
  ),
);

class _ContactCard extends StatelessWidget {
  const _ContactCard({required this.contact, required this.onEdit});

  final CampusContact contact;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      label: 'CONTACT',
      trailing: _editButton('Edit contact', onEdit),
      child: contact.isEmpty
          ? _mutedLine('No contact details yet.')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InfoRow(label: 'Email', value: contact.email ?? 'Not set'),
                _InfoRow(label: 'Phone', value: contact.phone ?? 'Not set'),
                _InfoRow(
                  label: 'Instagram',
                  value: contact.instagram ?? 'Not set',
                ),
              ],
            ),
    );
  }
}

class _ServicesCard extends StatelessWidget {
  const _ServicesCard({
    required this.services,
    required this.venues,
    required this.onAdd,
    required this.onEdit,
  });

  final List<CampusService> services;
  final List<CampusVenue> venues;
  final VoidCallback onAdd;
  final void Function(CampusService) onEdit;

  String _when(CampusService s) {
    final start = formatServiceTime(s.startTime);
    final end = formatServiceTime(s.endTime);
    final time = start == null ? null : (end == null ? start : '$start–$end');
    final venue = venues.where((v) => v.id == s.venueId).firstOrNull;
    return [?s.day, ?time, ?venue?.name].join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      label: 'SERVICE TIMES',
      trailing: IconButton(
        icon: const Icon(
          Icons.add_circle_outline,
          size: 20,
          color: AppColors.secondary,
        ),
        onPressed: onAdd,
        tooltip: 'Add service',
      ),
      child: services.isEmpty
          ? _mutedLine('No service times yet.')
          : Column(
              children: [
                for (final s in services)
                  InkWell(
                    onTap: () => onEdit(s),
                    borderRadius: AppRadius.inputBorder,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.xs,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  s.name,
                                  style: AppTypography.bodySm.copyWith(
                                    color: s.isActive
                                        ? AppColors.onSurface
                                        : AppColors.textMuted,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  [
                                    _when(s),
                                    if (!s.isActive) 'Hidden',
                                  ].where((t) => t.isNotEmpty).join(' · '),
                                  style: AppTypography.labelMd.copyWith(
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right_rounded,
                            size: 18,
                            color: AppColors.textFaint,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _GivingCard extends StatelessWidget {
  const _GivingCard({required this.giving, required this.onEdit});

  final GivingDetails? giving;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final g = giving;
    return _SectionCard(
      label: 'GIVING',
      trailing: _editButton('Edit giving', onEdit),
      child: g == null
          ? _mutedLine('Uses the church-wide giving details.')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (g.url != null) _InfoRow(label: 'Online', value: g.url!),
                if (g.bankName != null)
                  _InfoRow(label: 'Bank', value: g.bankName!),
                if (g.hasBankTransfer)
                  _InfoRow(
                    label: 'Account',
                    value: '${g.accountName} · ${g.accountNumber}',
                  ),
                if (g.sortCode != null)
                  _InfoRow(label: 'Sort code', value: g.sortCode!),
                if (g.swiftBic != null)
                  _InfoRow(label: 'SWIFT / BIC', value: g.swiftBic!),
                if (g.iban != null) _InfoRow(label: 'IBAN', value: g.iban!),
                if (g.reference != null)
                  _InfoRow(label: 'Reference', value: g.reference!),
              ],
            ),
    );
  }
}

class _HomeLayoutCard extends StatelessWidget {
  const _HomeLayoutCard({
    required this.home,
    required this.churchHome,
    required this.onEdit,
  });

  /// The campus's own layout; null uses [churchHome].
  final HomeLayout? home;
  final HomeLayout churchHome;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final visible = (home ?? churchHome).visible;
    return _SectionCard(
      label: 'HOME LAYOUT',
      trailing: _editButton('Edit layout', onEdit),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _mutedLine(
            home == null ? 'Uses the church-wide default.' : 'Custom layout.',
          ),
          for (var i = 0; i < visible.length; i++)
            Text(
              '${i + 1}. ${visible[i].label}',
              style: AppTypography.bodySm.copyWith(color: AppColors.onSurface),
            ),
        ],
      ),
    );
  }
}
