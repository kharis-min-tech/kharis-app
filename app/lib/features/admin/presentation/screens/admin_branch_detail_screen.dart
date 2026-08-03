import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/core/utils/service_time.dart';
import 'package:kharis_app/features/admin/presentation/widgets/branch_venue_form_sheet.dart';
import 'package:kharis_app/features/calendar/data/event_repository.dart';
import 'package:kharis_app/features/home/data/news_repository.dart';
import 'package:kharis_app/features/onboarding/data/branch_repository.dart';
import 'package:kharis_app/shared/providers/admin_provider.dart';
import 'package:kharis_app/shared/providers/sermon_provider.dart';

const _newsTypes = ['Announcement', 'Event', 'Ministry', 'Notice'];

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
      builder: (_) => _BranchEventFormSheet(
        event: event,
        branchName: branchName,
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
      builder: (_) => _BranchNewsFormSheet(
        item: item,
        branchName: branchName,
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
                Text(
                  event.title,
                  style: AppTypography.bodySm.copyWith(
                    color: AppColors.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${dateFmt.format(event.startTime)}, ${timeFmt.format(event.startTime)}',
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

// ── Branch event form sheet ───────────────────────────────────────────────────

class _BranchEventFormSheet extends StatefulWidget {
  const _BranchEventFormSheet({
    this.event,
    required this.branchName,
    required this.eventRepo,
    required this.onSuccess,
    required this.onError,
  });

  final Event? event;
  final String branchName;
  final EventRepository eventRepo;
  final void Function(String) onSuccess;
  final void Function(String) onError;

  @override
  State<_BranchEventFormSheet> createState() => _BranchEventFormSheetState();
}

class _BranchEventFormSheetState extends State<_BranchEventFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _locationCtrl;
  DateTime? _startTime;
  DateTime? _endTime;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final ev = widget.event;
    _titleCtrl = TextEditingController(text: ev?.title ?? '');
    _descCtrl = TextEditingController(text: ev?.description ?? '');
    _locationCtrl = TextEditingController(text: ev?.location ?? '');
    _startTime = ev?.startTime;
    _endTime = ev?.endTime;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.event != null;
    final dtFmt = DateFormat('MMM d, y h:mm a');

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      padding: EdgeInsets.only(
        left: AppSpacing.md,
        right: AppSpacing.md,
        top: AppSpacing.md,
        bottom: AppSpacing.md + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
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
                isEdit ? 'Edit Event' : 'New Event',
                style: AppTypography.titleMd.copyWith(color: AppColors.heading),
              ),
              const SizedBox(height: AppSpacing.xs),
              // Branch indicator (locked to this branch)
              Row(
                children: [
                  const Icon(Icons.location_on_outlined,
                      size: 14, color: AppColors.secondary),
                  const SizedBox(width: 4),
                  Text(
                    widget.branchName,
                    style: AppTypography.labelMd
                        .copyWith(color: AppColors.secondary),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),

              // Title
              _label('Title'),
              const SizedBox(height: AppSpacing.xs),
              TextFormField(
                controller: _titleCtrl,
                style: AppTypography.bodyLg.copyWith(color: AppColors.onSurface),
                decoration: _deco(hint: 'Event title'),
                textInputAction: TextInputAction.next,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Title is required' : null,
              ),
              const SizedBox(height: AppSpacing.sm),

              // Description
              _label('Description (optional)'),
              const SizedBox(height: AppSpacing.xs),
              TextFormField(
                controller: _descCtrl,
                style: AppTypography.bodyLg.copyWith(color: AppColors.onSurface),
                decoration: _deco(hint: 'Optional description'),
                maxLines: 3,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: AppSpacing.sm),

              // Location
              _label('Location (optional)'),
              const SizedBox(height: AppSpacing.xs),
              TextFormField(
                controller: _locationCtrl,
                style: AppTypography.bodyLg.copyWith(color: AppColors.onSurface),
                decoration: _deco(hint: 'e.g. Main Auditorium'),
                textInputAction: TextInputAction.done,
              ),
              const SizedBox(height: AppSpacing.sm),

              // Start time
              _label('Start time'),
              const SizedBox(height: AppSpacing.xs),
              _DateTimeButton(
                label: _startTime != null
                    ? dtFmt.format(_startTime!)
                    : 'Pick start date and time',
                hasValue: _startTime != null,
                onTap: () => _pickDateTime(isStart: true),
              ),
              if (_startTime == null && _saving)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Start time is required',
                    style: AppTypography.labelMd.copyWith(color: AppColors.error),
                  ),
                ),
              const SizedBox(height: AppSpacing.sm),

              // End time
              _label('End time'),
              const SizedBox(height: AppSpacing.xs),
              _DateTimeButton(
                label: _endTime != null
                    ? dtFmt.format(_endTime!)
                    : 'Pick end date and time',
                hasValue: _endTime != null,
                onTap: () => _pickDateTime(isStart: false),
              ),
              const SizedBox(height: AppSpacing.md),

              // Save button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _saving ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.secondary,
                    foregroundColor: AppColors.onSecondary,
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.buttonBorder,
                    ),
                  ),
                  child: _saving
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.onSecondary,
                          ),
                        )
                      : Text(
                          isEdit ? 'Save changes' : 'Add event',
                          style: AppTypography.bodyLg.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.onSecondary,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickDateTime({required bool isStart}) async {
    final now = DateTime.now();
    final initial = isStart
        ? (_startTime ?? now)
        : (_endTime ?? (_startTime ?? now).add(const Duration(hours: 1)));

    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 5)),
      builder: (ctx, child) => Theme(
        data: _datePickerTheme(),
        child: child!,
      ),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
      builder: (ctx, child) => Theme(
        data: _datePickerTheme(),
        child: child!,
      ),
    );
    if (time == null || !mounted) return;

    final combined = DateTime(
      date.year, date.month, date.day, time.hour, time.minute,
    );
    setState(() {
      if (isStart) {
        _startTime = combined;
      } else {
        _endTime = combined;
      }
    });
  }

  ThemeData _datePickerTheme() => ThemeData.dark().copyWith(
        colorScheme: const ColorScheme.dark(
          primary: AppColors.secondary,
          onPrimary: AppColors.onSecondary,
          surface: AppColors.surfaceDark,
          onSurface: AppColors.onSurface,
        ),
      );

  Future<void> _submit() async {
    setState(() => _saving = true);
    if (!_formKey.currentState!.validate() ||
        _startTime == null ||
        _endTime == null) {
      setState(() => _saving = false);
      return;
    }
    try {
      final title = _titleCtrl.text.trim();
      final desc =
          _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim();
      final loc = _locationCtrl.text.trim().isEmpty
          ? null
          : _locationCtrl.text.trim();

      if (widget.event == null) {
        await widget.eventRepo.addEvent(
          title: title,
          description: desc,
          location: loc,
          branch: widget.branchName,
          startTime: _startTime!,
          endTime: _endTime!,
        );
        widget.onSuccess('Event added.');
      } else {
        await widget.eventRepo.updateEvent(
          widget.event!.id,
          title: title,
          description: desc,
          location: loc,
          branch: widget.branchName,
          startTime: _startTime!,
          endTime: _endTime!,
        );
        widget.onSuccess('Event updated.');
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      widget.onError('Save failed: $e');
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _label(String text) => Text(
        text,
        style: AppTypography.labelMd.copyWith(color: AppColors.onSurfaceVariant),
      );

  InputDecoration _deco({String? hint}) => InputDecoration(
        hintText: hint,
        hintStyle: AppTypography.bodyLg.copyWith(color: AppColors.textFaint),
        filled: true,
        fillColor: AppColors.surfaceSubtle,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.sm,
        ),
        border: OutlineInputBorder(
          borderRadius: AppRadius.inputBorder,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.inputBorder,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.inputBorder,
          borderSide: const BorderSide(color: AppColors.secondary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.inputBorder,
          borderSide: const BorderSide(color: AppColors.error, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppRadius.inputBorder,
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
        errorStyle: AppTypography.labelMd.copyWith(color: AppColors.error),
      );
}

// ── Branch news form sheet ────────────────────────────────────────────────────

class _BranchNewsFormSheet extends StatefulWidget {
  const _BranchNewsFormSheet({
    this.item,
    required this.branchName,
    required this.repo,
    required this.onSuccess,
    required this.onError,
  });

  final NewsItem? item;
  final String branchName;
  final NewsRepository repo;
  final void Function(String) onSuccess;
  final void Function(String) onError;

  @override
  State<_BranchNewsFormSheet> createState() => _BranchNewsFormSheetState();
}

class _BranchNewsFormSheetState extends State<_BranchNewsFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleCtrl;
  late final TextEditingController _bodyCtrl;
  late final TextEditingController _imageUrlCtrl;
  late String _type;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.item?.title ?? '');
    _bodyCtrl = TextEditingController(text: widget.item?.body ?? '');
    _imageUrlCtrl = TextEditingController(text: widget.item?.imageUrl ?? '');
    _type = widget.item?.type ?? _newsTypes.first;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    _imageUrlCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.item != null;
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      padding: EdgeInsets.only(
        left: AppSpacing.md,
        right: AppSpacing.md,
        top: AppSpacing.md,
        bottom: AppSpacing.md + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
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
                isEdit ? 'Edit Announcement' : 'New Announcement',
                style: AppTypography.titleMd.copyWith(color: AppColors.heading),
              ),
              const SizedBox(height: AppSpacing.xs),
              // Branch indicator (locked to this branch)
              Row(
                children: [
                  const Icon(Icons.location_on_outlined,
                      size: 14, color: AppColors.secondary),
                  const SizedBox(width: 4),
                  Text(
                    widget.branchName,
                    style: AppTypography.labelMd
                        .copyWith(color: AppColors.secondary),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),

              // Title
              _inputLabel('Title'),
              const SizedBox(height: AppSpacing.xs),
              TextFormField(
                controller: _titleCtrl,
                style: AppTypography.bodyLg.copyWith(color: AppColors.onSurface),
                decoration: _inputDeco(hint: 'Enter a title'),
                textInputAction: TextInputAction.next,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Title is required' : null,
              ),
              const SizedBox(height: AppSpacing.sm),

              // Type
              _inputLabel('Type'),
              const SizedBox(height: AppSpacing.xs),
              DropdownButtonFormField<String>(
                initialValue: _type,
                dropdownColor: AppColors.surfaceContainer,
                style: AppTypography.bodyLg.copyWith(color: AppColors.onSurface),
                decoration: _inputDeco(),
                items: _newsTypes
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _type = v);
                },
              ),
              const SizedBox(height: AppSpacing.sm),

              // Body
              _inputLabel('Body (optional)'),
              const SizedBox(height: AppSpacing.xs),
              TextFormField(
                controller: _bodyCtrl,
                style: AppTypography.bodyLg.copyWith(color: AppColors.onSurface),
                decoration: _inputDeco(hint: 'Optional body text'),
                maxLines: 4,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: AppSpacing.sm),

              // Image URL
              _inputLabel('Image URL (optional)'),
              const SizedBox(height: AppSpacing.xs),
              TextFormField(
                controller: _imageUrlCtrl,
                style: AppTypography.bodyLg.copyWith(color: AppColors.onSurface),
                decoration: _inputDeco(hint: 'https://...'),
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.done,
              ),
              const SizedBox(height: AppSpacing.md),

              // Save button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _saving ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.secondary,
                    foregroundColor: AppColors.onSecondary,
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.buttonBorder,
                    ),
                  ),
                  child: _saving
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.onSecondary,
                          ),
                        )
                      : Text(
                          isEdit ? 'Save changes' : 'Add announcement',
                          style: AppTypography.bodyLg.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.onSecondary,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final title = _titleCtrl.text.trim();
      final body =
          _bodyCtrl.text.trim().isEmpty ? null : _bodyCtrl.text.trim();
      final imageUrl = _imageUrlCtrl.text.trim().isEmpty
          ? null
          : _imageUrlCtrl.text.trim();

      if (widget.item == null) {
        await widget.repo.addNews(
          title: title,
          type: _type,
          body: body,
          imageUrl: imageUrl,
          branch: widget.branchName,
        );
        widget.onSuccess('Announcement added.');
      } else {
        await widget.repo.updateNews(
          widget.item!.id,
          title: title,
          type: _type,
          body: body,
          imageUrl: imageUrl,
          branch: widget.branchName,
        );
        widget.onSuccess('Announcement updated.');
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      widget.onError('Save failed: $e');
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _inputLabel(String text) => Text(
        text,
        style: AppTypography.labelMd.copyWith(color: AppColors.onSurfaceVariant),
      );

  InputDecoration _inputDeco({String? hint}) => InputDecoration(
        hintText: hint,
        hintStyle: AppTypography.bodyLg.copyWith(color: AppColors.textFaint),
        filled: true,
        fillColor: AppColors.surfaceSubtle,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.sm,
        ),
        border: OutlineInputBorder(
          borderRadius: AppRadius.inputBorder,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.inputBorder,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.inputBorder,
          borderSide: const BorderSide(color: AppColors.secondary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.inputBorder,
          borderSide: const BorderSide(color: AppColors.error, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppRadius.inputBorder,
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
        errorStyle: AppTypography.labelMd.copyWith(color: AppColors.error),
      );
}

// ── Date / time button ────────────────────────────────────────────────────────

class _DateTimeButton extends StatelessWidget {
  const _DateTimeButton({
    required this.label,
    required this.hasValue,
    required this.onTap,
  });

  final String label;
  final bool hasValue;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: AppColors.surfaceSubtle,
          borderRadius: AppRadius.inputBorder,
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today_outlined,
              size: 16,
              color: hasValue ? AppColors.secondary : AppColors.textFaint,
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              label,
              style: AppTypography.bodyLg.copyWith(
                color: hasValue ? AppColors.onSurface : AppColors.textFaint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
