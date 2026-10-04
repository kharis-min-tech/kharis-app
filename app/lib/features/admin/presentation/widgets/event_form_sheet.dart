import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/features/admin/presentation/widgets/studio_form_kit.dart';
import 'package:kharis_app/features/calendar/data/event_repository.dart';

/// True for events mirrored from the church website (`web_` ids).
bool isWebsiteEvent(Event event) => event.id.startsWith('web_');

/// Small 'From website' marker for events mirrored from the church website.
class FromWebsiteChip extends StatelessWidget {
  const FromWebsiteChip({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.surfaceSubtle,
        borderRadius: AppRadius.pillBorder,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.public_rounded,
            size: 12,
            color: AppColors.textMuted,
          ),
          const SizedBox(width: 4),
          Text(
            'From website',
            style: AppTypography.labelMd.copyWith(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet that creates or edits an [Event].
///
/// Two variants:
///  * the Studio events list ([scopeBranch] null): campus dropdown, banner
///    image and featured switch;
///  * a branch page ([scopeBranch] set): new events belong to that campus, and
///    there is no campus, image or featured control.
///
/// Edits write only what the form edits ([EventRepository.updateEvent] is a
/// partial update), so a branch page can never re-scope an all-campus event or
/// wipe a banner and featured flag it does not show.
class EventFormSheet extends ConsumerStatefulWidget {
  const EventFormSheet({
    super.key,
    this.event,
    this.scopeBranch,
    required this.eventRepo,
    required this.onSuccess,
    required this.onError,
  });

  final Event? event;

  /// Campus a branch page creates events for; `null` on the Studio list.
  final String? scopeBranch;
  final EventRepository eventRepo;
  final void Function(String) onSuccess;
  final void Function(String) onError;

  @override
  ConsumerState<EventFormSheet> createState() => _EventFormSheetState();
}

class _EventFormSheetState extends ConsumerState<EventFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _locationCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _imageUrlCtrl;

  String? _branch;
  DateTime? _startTime;
  DateTime? _endTime;
  bool _isFeatured = false;
  bool _saving = false;
  bool _submitted = false;

  bool get _isBranchPage => widget.scopeBranch != null;

  @override
  void initState() {
    super.initState();
    final ev = widget.event;
    _titleCtrl = TextEditingController(text: ev?.title ?? '');
    _descCtrl = TextEditingController(text: ev?.description ?? '');
    _locationCtrl = TextEditingController(text: ev?.location ?? '');
    _addressCtrl = TextEditingController(text: ev?.address ?? '');
    _imageUrlCtrl = TextEditingController(text: ev?.imageUrl ?? '');
    // A campus admin may not post church-wide, so a new Studio event starts
    // on one of their campuses.
    _branch = ev == null && !_isBranchPage
        ? studioDefaultCampus(ref)
        : ev?.branch;
    _startTime = ev?.startTime;
    _endTime = ev?.endTime;
    _isFeatured = ev?.isFeatured ?? false;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _locationCtrl.dispose();
    _addressCtrl.dispose();
    _imageUrlCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    final isEdit = event != null;
    final dtFmt = DateFormat('MMM d, y h:mm a');
    final campusesReady = _isBranchPage || studioCampusesReady(ref);
    // On a branch page the campus is fixed: the page's own for a new event,
    // the event's own (possibly all-campus) for an edit.
    final shownScope = isEdit ? event.branch : widget.scopeBranch;

    return StudioSheet(
      formKey: _formKey,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                isEdit ? 'Edit Event' : 'New Event',
                style: AppTypography.titleMd.copyWith(color: AppColors.heading),
              ),
            ),
            if (event != null && isWebsiteEvent(event)) const FromWebsiteChip(),
          ],
        ),
        if (_isBranchPage) ...[
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              const Icon(
                Icons.location_on_outlined,
                size: 14,
                color: AppColors.secondary,
              ),
              const SizedBox(width: 4),
              Text(
                shownScope ?? 'All campuses',
                style: AppTypography.labelMd.copyWith(
                  color: AppColors.secondary,
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: AppSpacing.md),

        const StudioFieldLabel('Title'),
        TextFormField(
          controller: _titleCtrl,
          style: AppTypography.bodyLg.copyWith(color: AppColors.onSurface),
          decoration: studioInputDecoration(hint: 'Event title'),
          textInputAction: TextInputAction.next,
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Title is required' : null,
        ),
        const SizedBox(height: AppSpacing.sm),

        const StudioFieldLabel('Description (optional)'),
        TextFormField(
          controller: _descCtrl,
          style: AppTypography.bodyLg.copyWith(color: AppColors.onSurface),
          decoration: studioInputDecoration(hint: 'Optional description'),
          maxLines: 3,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: AppSpacing.sm),

        const StudioFieldLabel('Venue name (optional)'),
        TextFormField(
          controller: _locationCtrl,
          style: AppTypography.bodyLg.copyWith(color: AppColors.onSurface),
          decoration: studioInputDecoration(hint: 'e.g. Main Auditorium'),
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: AppSpacing.sm),

        const StudioFieldLabel('Address (optional)'),
        TextFormField(
          controller: _addressCtrl,
          style: AppTypography.bodyLg.copyWith(color: AppColors.onSurface),
          decoration: studioInputDecoration(hint: 'Street, town, postcode'),
          keyboardType: TextInputType.streetAddress,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: AppSpacing.sm),

        if (!_isBranchPage) ...[
          const StudioFieldLabel('Branch (optional)'),
          StudioCampusField(
            value: _branch,
            allLabel: 'All branches',
            onChanged: (v) => setState(() => _branch = v),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],

        const StudioFieldLabel('Start time'),
        StudioPickerButton(
          label: _startTime != null
              ? dtFmt.format(_startTime!)
              : 'Pick start date and time',
          hasValue: _startTime != null,
          onTap: () => _pickDateTime(isStart: true),
        ),
        if (_startTime == null && _submitted)
          const StudioHint('Start time is required', color: AppColors.error),
        const SizedBox(height: AppSpacing.sm),

        const StudioFieldLabel('End time'),
        StudioPickerButton(
          label: _endTime != null
              ? dtFmt.format(_endTime!)
              : 'Pick end date and time',
          hasValue: _endTime != null,
          onTap: () => _pickDateTime(isStart: false),
        ),
        if (_endTime == null && _submitted)
          const StudioHint('End time is required', color: AppColors.error),
        const SizedBox(height: AppSpacing.sm),

        if (!_isBranchPage) ...[
          const StudioFieldLabel('Image URL (optional)'),
          TextFormField(
            controller: _imageUrlCtrl,
            style: AppTypography.bodyLg.copyWith(color: AppColors.onSurface),
            decoration: studioInputDecoration(hint: 'https://...'),
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.done,
          ),
          const SizedBox(height: AppSpacing.sm),
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
          const SizedBox(height: AppSpacing.sm),
        ],
        const SizedBox(height: AppSpacing.xs),

        StudioSaveButton(
          label: isEdit ? 'Save changes' : 'Add event',
          saving: _saving,
          onPressed: campusesReady ? _submit : null,
        ),
        if (!campusesReady) const StudioHint(kLoadingCampusesHint),
      ],
    );
  }

  Future<void> _pickDateTime({required bool isStart}) async {
    final now = DateTime.now();
    final initial = isStart
        ? (_startTime ?? now)
        : (_endTime ?? (_startTime ?? now).add(const Duration(hours: 1)));

    final date = await pickStudioDate(
      context,
      initial: initial,
      first: now.subtract(const Duration(days: 365)),
      last: now.add(const Duration(days: 365 * 5)),
    );
    if (date == null || !mounted) return;

    final time = await pickStudioTime(
      context,
      initial: TimeOfDay.fromDateTime(initial),
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

  Future<void> _submit() async {
    setState(() => _submitted = true);
    final valid = _formKey.currentState!.validate();
    if (!valid || _startTime == null || _endTime == null) return;
    setState(() => _saving = true);

    final title = _titleCtrl.text.trim();
    final desc = _descCtrl.text.trim();
    final location = _locationCtrl.text.trim();
    final address = _addressCtrl.text.trim();
    final image = _imageUrlCtrl.text.trim();
    final event = widget.event;

    try {
      if (event == null) {
        await widget.eventRepo.addEvent(
          title: title,
          description: desc,
          location: location,
          address: address,
          // A branch page creates for its own campus; blank is all-campus.
          branch: widget.scopeBranch ?? _branch,
          startTime: _startTime!,
          endTime: _endTime!,
          imageUrl: _isBranchPage ? null : image,
          isFeatured: !_isBranchPage && _isFeatured,
        );
        widget.onSuccess('Event added.');
      } else {
        // Partial update: '' clears an optional field, null keeps it. Campus,
        // banner and featured flag are only written from the Studio list and
        // only when the admin changed them.
        await widget.eventRepo.updateEvent(
          event.id,
          title: title,
          description: desc,
          location: location,
          address: address,
          startTime: _startTime,
          endTime: _endTime,
          branch: !_isBranchPage && _branch != event.branch
              ? (_branch ?? '')
              : null,
          imageUrl: !_isBranchPage && image != (event.imageUrl ?? '')
              ? image
              : null,
          isFeatured: !_isBranchPage && _isFeatured != event.isFeatured
              ? _isFeatured
              : null,
        );
        widget.onSuccess('Event updated.');
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      widget.onError('Save failed: $e');
      if (mounted) setState(() => _saving = false);
    }
  }
}
