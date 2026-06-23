import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/features/calendar/data/event_repository.dart';
import 'package:kharis_app/features/onboarding/data/branch_repository.dart';
import 'package:kharis_app/shared/providers/admin_provider.dart';
import 'package:kharis_app/shared/providers/sermon_provider.dart';

// ── Main screen ───────────────────────────────────────────────────────────────

/// Admin screen: list + CRUD for [Event].
class AdminEventsScreen extends ConsumerWidget {
  const AdminEventsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(upcomingEventsProvider(null));

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Events',
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
      body: eventsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.secondary),
        ),
        error: (e, _) => Center(
          child: Text(
            'Could not load events.',
            style: AppTypography.bodyLg.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ),
        data: (events) {
          if (events.isEmpty) {
            return Center(
              child: Text(
                'No upcoming events.',
                style: AppTypography.bodyLg.copyWith(color: AppColors.textMuted),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.gutter,
              AppSpacing.sm,
              AppSpacing.gutter,
              AppSpacing.lg + AppSpacing.lg,
            ),
            itemCount: events.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (_, index) => _EventCard(
              event: events[index],
              onEdit: () => _openForm(context, ref, event: events[index]),
              onDelete: () => _confirmDelete(context, ref, events[index]),
            ),
          );
        },
      ),
    );
  }

  void _openForm(BuildContext context, WidgetRef ref, {Event? event}) {
    final messenger = ScaffoldMessenger.of(context);
    final eventRepo = ref.read(eventRepositoryProvider);
    final branches = ref.read(branchesProvider).valueOrNull ?? [];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EventFormSheet(
        event: event,
        eventRepo: eventRepo,
        branches: branches,
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

  void _confirmDelete(BuildContext context, WidgetRef ref, Event event) {
    final messenger = ScaffoldMessenger.of(context);
    final repo = ref.read(eventRepositoryProvider);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        title: Text(
          'Delete event?',
          style: AppTypography.titleMd.copyWith(color: AppColors.heading),
        ),
        content: Text(
          'This will permanently remove "${event.title}". This cannot be undone.',
          style: AppTypography.bodySm.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
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
                await repo.deleteEvent(event.id);
                messenger.showSnackBar(
                  const SnackBar(content: Text('Event deleted.')),
                );
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

// ── Event card ────────────────────────────────────────────────────────────────

class _EventCard extends StatelessWidget {
  const _EventCard({
    required this.event,
    required this.onEdit,
    required this.onDelete,
  });

  final Event event;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('MMM d, y').format(event.startTime);
    final timeStr = DateFormat('h:mm a').format(event.startTime);

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
            if (event.imageUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.defaultRadius),
                child: Image.network(
                  event.imageUrl!,
                  width: 64,
                  height: 64,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            if (event.imageUrl != null) const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '$dateStr at $timeStr',
                        style: AppTypography.labelMd.copyWith(
                          color: AppColors.secondary,
                        ),
                      ),
                      if (event.isFeatured) ...[
                        const SizedBox(width: AppSpacing.xs),
                        const Icon(
                          Icons.star_rounded,
                          size: 14,
                          color: AppColors.secondary,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    event.title,
                    style: AppTypography.bodyLg.copyWith(
                      color: AppColors.heading,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (event.location != null && event.location!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(
                          Icons.place_outlined,
                          size: 12,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          event.location!,
                          style: AppTypography.bodySm.copyWith(
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (event.branch != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    _BranchChip(branch: event.branch!),
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
}

class _BranchChip extends StatelessWidget {
  const _BranchChip({required this.branch});
  final String branch;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.15),
        borderRadius: AppRadius.pillBorder,
      ),
      child: Text(
        branch,
        style: AppTypography.labelMd.copyWith(color: AppColors.primary),
      ),
    );
  }
}

// ── Add / Edit form sheet ─────────────────────────────────────────────────────

class _EventFormSheet extends StatefulWidget {
  const _EventFormSheet({
    this.event,
    required this.eventRepo,
    required this.branches,
    required this.onSuccess,
    required this.onError,
  });

  final Event? event;
  final EventRepository eventRepo;
  final List<Branch> branches;
  final void Function(String) onSuccess;
  final void Function(String) onError;

  @override
  State<_EventFormSheet> createState() => _EventFormSheetState();
}

class _EventFormSheetState extends State<_EventFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _locationCtrl;
  late final TextEditingController _imageUrlCtrl;

  String? _selectedBranch;
  DateTime? _startTime;
  DateTime? _endTime;
  bool _isFeatured = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final ev = widget.event;
    _titleCtrl = TextEditingController(text: ev?.title ?? '');
    _descCtrl = TextEditingController(text: ev?.description ?? '');
    _locationCtrl = TextEditingController(text: ev?.location ?? '');
    _imageUrlCtrl = TextEditingController(text: ev?.imageUrl ?? '');
    _selectedBranch = ev?.branch;
    _startTime = ev?.startTime;
    _endTime = ev?.endTime;
    _isFeatured = ev?.isFeatured ?? false;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _locationCtrl.dispose();
    _imageUrlCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.event != null;
    final dtFmt = DateFormat('MMM d, y h:mm a');

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
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
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: AppSpacing.sm),

              // Branch
              _label('Branch (optional)'),
              const SizedBox(height: AppSpacing.xs),
              DropdownButtonFormField<String?>(
                initialValue: _selectedBranch,
                dropdownColor: AppColors.surfaceContainer,
                style: AppTypography.bodyLg.copyWith(color: AppColors.onSurface),
                decoration: _deco(),
                items: [
                  DropdownMenuItem<String?>(
                    value: null,
                    child: Text(
                      'All branches',
                      style: AppTypography.bodyLg.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                  ...widget.branches.map(
                    (b) => DropdownMenuItem<String?>(
                      value: b.name,
                      child: Text(b.name),
                    ),
                  ),
                ],
                onChanged: (v) => setState(() => _selectedBranch = v),
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
              const SizedBox(height: AppSpacing.sm),

              // Image URL
              _label('Image URL (optional)'),
              const SizedBox(height: AppSpacing.xs),
              TextFormField(
                controller: _imageUrlCtrl,
                style: AppTypography.bodyLg.copyWith(color: AppColors.onSurface),
                decoration: _deco(hint: 'https://...'),
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.done,
              ),
              const SizedBox(height: AppSpacing.sm),

              // Featured switch
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceSubtle,
                  borderRadius: AppRadius.inputBorder,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                child: Row(
                  children: [
                    Text(
                      'Featured event',
                      style: AppTypography.bodyLg.copyWith(
                        color: AppColors.onSurface,
                      ),
                    ),
                    const Spacer(),
                    Switch(
                      value: _isFeatured,
                      onChanged: (v) => setState(() => _isFeatured = v),
                      activeThumbColor: AppColors.secondary,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Save
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
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    setState(() {
      if (isStart) {
        _startTime = combined;
      } else {
        _endTime = combined;
      }
    });
  }

  ThemeData _datePickerTheme() {
    return ThemeData.dark().copyWith(
      colorScheme: const ColorScheme.dark(
        primary: AppColors.secondary,
        onPrimary: AppColors.onSecondary,
        surface: AppColors.surfaceDark,
        onSurface: AppColors.onSurface,
      ),
    );
  }

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
      final desc = _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim();
      final loc =
          _locationCtrl.text.trim().isEmpty ? null : _locationCtrl.text.trim();
      final img = _imageUrlCtrl.text.trim().isEmpty
          ? null
          : _imageUrlCtrl.text.trim();

      if (widget.event == null) {
        await widget.eventRepo.addEvent(
          title: title,
          description: desc,
          location: loc,
          branch: _selectedBranch,
          startTime: _startTime!,
          endTime: _endTime!,
          imageUrl: img,
          isFeatured: _isFeatured,
        );
        widget.onSuccess('Event added.');
      } else {
        await widget.eventRepo.updateEvent(
          widget.event!.id,
          title: title,
          description: desc,
          location: loc,
          branch: _selectedBranch,
          startTime: _startTime!,
          endTime: _endTime!,
          imageUrl: img,
          isFeatured: _isFeatured,
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
        style: AppTypography.labelMd.copyWith(
          color: AppColors.onSurfaceVariant,
        ),
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

// ── Date time button ──────────────────────────────────────────────────────────

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
              Icons.calendar_today_rounded,
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
