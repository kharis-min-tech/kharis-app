import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/features/admin/data/london_time.dart';
import 'package:kharis_app/features/admin/presentation/widgets/announcement_home_status.dart';
import 'package:kharis_app/features/admin/presentation/widgets/studio_form_kit.dart';
import 'package:kharis_app/features/calendar/data/event_repository.dart';
import 'package:kharis_app/features/home/data/news_repository.dart';
import 'package:kharis_app/shared/providers/sermon_provider.dart';

/// Longest button label the home card fits on one line.
const int kAnnouncementCtaMaxLength = 24;

/// Validates an optional button link: blank, or a full http(s) address.
///
/// A link is refused while an event is linked ([eventId]): tapping such an
/// announcement opens the event, so the button would never be reachable.
String? validateAnnouncementLink(String? value, {String? eventId}) {
  final link = value?.trim() ?? '';
  if (link.isEmpty) return null;
  if (eventId != null && eventId.trim().isNotEmpty) {
    return 'Choose a linked event or a button link, not both';
  }
  final lower = link.toLowerCase();
  if (!lower.startsWith('http://') && !lower.startsWith('https://')) {
    return 'Links must start with http:// or https://';
  }
  final uri = Uri.tryParse(link);
  if (uri == null || uri.host.isEmpty) return 'Enter a full web address';
  return null;
}

/// [link] trimmed, with its scheme lower-cased. [validateAnnouncementLink]
/// accepts `HTTPS://x`; storing it as `https://x` keeps it within the `news`
/// rule and every reader's scheme check.
String normaliseAnnouncementLink(String link) => link.trim().replaceFirstMapped(
  RegExp(r'^[A-Za-z][A-Za-z0-9+.-]*:'),
  (m) => m[0]!.toLowerCase(),
);

/// `Title · Sat 12 Oct`, the label for a linkable event.
String linkedEventLabel(Event event) =>
    '${event.title} · ${studioDayLabel(event.startTime)}';

/// Bottom sheet that creates or edits a [NewsItem].
///
/// Two variants:
///  * the Studio announcements list ([scopeBranch] null): a campus dropdown
///    backed by the Firestore branch list;
///  * a branch page ([scopeBranch] set): new announcements belong to that
///    campus and an edit keeps the item's own scope.
///
/// Publish and expiry are Europe/London wall-clock times whatever timezone the
/// admin's device is in (see `london_time.dart`).
class AnnouncementFormSheet extends ConsumerStatefulWidget {
  const AnnouncementFormSheet({
    super.key,
    this.item,
    this.scopeBranch,
    required this.repo,
    required this.onSuccess,
    required this.onError,
  });

  final NewsItem? item;

  /// Campus a branch page creates announcements for; `null` on the Studio list.
  final String? scopeBranch;
  final NewsRepository repo;
  final void Function(String) onSuccess;
  final void Function(String) onError;

  @override
  ConsumerState<AnnouncementFormSheet> createState() =>
      _AnnouncementFormSheetState();
}

class _AnnouncementFormSheetState extends ConsumerState<AnnouncementFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleCtrl;
  late final TextEditingController _bodyCtrl;
  late final TextEditingController _imageUrlCtrl;
  late final TextEditingController _linkCtrl;
  late final TextEditingController _ctaCtrl;
  late String _type;
  String? _branch;
  String? _eventId;

  /// London wall clock (UTC-flagged fields) the item publishes at; `null` is
  /// "now". Prefilled from an existing item so its date reads correctly.
  DateTime? _publishWall;
  bool _publishChanged = false;

  /// London calendar day the item expires at the end of; `null` = never.
  DateTime? _expiresDay;
  bool _expiresChanged = false;

  String? _scheduleError;
  bool _saving = false;

  bool get _isBranchPage => widget.scopeBranch != null;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _titleCtrl = TextEditingController(text: item?.title ?? '');
    _bodyCtrl = TextEditingController(text: item?.body ?? '');
    _imageUrlCtrl = TextEditingController(text: item?.imageUrl ?? '');
    _linkCtrl = TextEditingController(text: item?.linkUrl ?? '');
    _ctaCtrl = TextEditingController(text: item?.ctaLabel ?? '');
    // normaliseType guards the dropdown: a legacy doc saved as type 'Event'
    // would otherwise assert on a value outside `items`.
    _type = NewsItem.normaliseType(item?.type);
    // A campus admin may not post church-wide, so a new Studio item starts
    // on one of their campuses.
    _branch = item == null && !_isBranchPage
        ? studioDefaultCampus(ref)
        : item?.branch;
    _eventId = item?.eventId;
    if (item != null) {
      _publishWall = toLondonWallClock(item.publishedAt);
      final expires = item.expiresAt;
      if (expires != null) _expiresDay = _dayOf(toLondonWallClock(expires));
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    _imageUrlCtrl.dispose();
    _linkCtrl.dispose();
    _ctaCtrl.dispose();
    super.dispose();
  }

  static DateTime _dayOf(DateTime wall) =>
      DateTime(wall.year, wall.month, wall.day);

  DateTime get _londonToday => _dayOf(toLondonWallClock(DateTime.now()));

  /// The instant [_publishWall] names, or `null` for "now".
  DateTime? get _publishInstant {
    final wall = _publishWall;
    return wall == null ? null : londonWallTime(wall, wall.hour, wall.minute);
  }

  /// The expiry instant the save will write.
  DateTime? get _expiresInstant {
    if (!_expiresChanged && widget.item != null) return widget.item!.expiresAt;
    final day = _expiresDay;
    return day == null ? null : londonEndOfDay(day);
  }

  /// Campus the saved item will be scoped to; `null` is all-campus.
  String? get _audienceBranch {
    if (!_isBranchPage) return _branch;
    final item = widget.item;
    return item == null ? widget.scopeBranch : item.branch;
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.item != null;
    final campusesReady = _isBranchPage || studioCampusesReady(ref);
    final publishAt = _publishInstant;
    final scheduled = publishAt != null && publishAt.isAfter(DateTime.now());

    return StudioSheet(
      formKey: _formKey,
      children: [
        Row(
          children: [
            const Icon(
              Icons.campaign_rounded,
              size: 20,
              color: AppColors.secondary,
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              isEdit ? 'Edit Announcement' : 'New Announcement',
              style: AppTypography.titleMd.copyWith(color: AppColors.heading),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        if (_isBranchPage)
          Row(
            children: [
              const Icon(
                Icons.location_on_outlined,
                size: 14,
                color: AppColors.secondary,
              ),
              const SizedBox(width: 4),
              Text(
                AnnouncementHomeVisibility.audienceFor(_audienceBranch),
                style: AppTypography.labelMd.copyWith(
                  color: AppColors.secondary,
                ),
              ),
            ],
          )
        else
          Text(
            'A message to the church: headline, optional body and image. '
            'For anything with a date and a venue people RSVP to, use '
            'Events instead.',
            style: AppTypography.bodySm.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
        const SizedBox(height: AppSpacing.md),

        const StudioFieldLabel('Title'),
        TextFormField(
          controller: _titleCtrl,
          style: AppTypography.bodyLg.copyWith(color: AppColors.onSurface),
          decoration: studioInputDecoration(hint: 'Enter a title'),
          textInputAction: TextInputAction.next,
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Title is required' : null,
        ),
        const SizedBox(height: AppSpacing.sm),

        const StudioFieldLabel('Type'),
        DropdownButtonFormField<String>(
          initialValue: _type,
          dropdownColor: AppColors.surfaceContainer,
          style: AppTypography.bodyLg.copyWith(color: AppColors.onSurface),
          decoration: studioInputDecoration(),
          items: NewsItem.types
              .map((t) => DropdownMenuItem(value: t, child: Text(t)))
              .toList(),
          onChanged: (v) {
            if (v != null) setState(() => _type = v);
          },
        ),
        const SizedBox(height: AppSpacing.sm),

        if (!_isBranchPage) ...[
          const StudioFieldLabel('Branch Scope'),
          StudioCampusField(
            value: _branch,
            allLabel: 'All Branches (Church-wide)',
            onChanged: (v) => setState(() => _branch = v),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],

        const StudioFieldLabel('Body (optional)'),
        TextFormField(
          controller: _bodyCtrl,
          style: AppTypography.bodyLg.copyWith(color: AppColors.onSurface),
          decoration: studioInputDecoration(hint: 'Optional body text'),
          maxLines: 4,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: AppSpacing.sm),

        const StudioFieldLabel('Image URL (optional)'),
        TextFormField(
          controller: _imageUrlCtrl,
          style: AppTypography.bodyLg.copyWith(color: AppColors.onSurface),
          decoration: studioInputDecoration(hint: 'https://...'),
          keyboardType: TextInputType.url,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: AppSpacing.sm),

        const StudioFieldLabel('Publish'),
        StudioPickerButton(
          icon: Icons.schedule_rounded,
          label: _publishLabel(),
          hasValue: true,
          onTap: _pickPublish,
          clearTooltip: 'Publish now',
          onClear: _publishWall == null
              ? null
              : () => setState(() {
                  _publishWall = null;
                  _publishChanged = true;
                  _scheduleError = null;
                }),
        ),
        const StudioHint('Times are UK time.'),
        const SizedBox(height: AppSpacing.sm),

        const StudioFieldLabel('Expires (optional)'),
        StudioPickerButton(
          icon: Icons.event_busy_rounded,
          label: _expiresDay == null
              ? 'Never'
              : 'End of ${studioDayLabel(_expiresDay!)} ${_expiresDay!.year}',
          hasValue: _expiresDay != null,
          onTap: _pickExpiry,
          clearTooltip: 'Remove expiry',
          onClear: _expiresDay == null
              ? null
              : () => setState(() {
                  _expiresDay = null;
                  _expiresChanged = true;
                  _scheduleError = null;
                }),
        ),
        if (_scheduleError != null)
          StudioHint(_scheduleError!, color: AppColors.error),
        const SizedBox(height: AppSpacing.sm),

        const StudioFieldLabel('Linked event (optional)'),
        _linkedEventField(),
        const SizedBox(height: AppSpacing.sm),

        const StudioFieldLabel('Button link (optional)'),
        TextFormField(
          controller: _linkCtrl,
          style: AppTypography.bodyLg.copyWith(color: AppColors.onSurface),
          decoration: studioInputDecoration(hint: 'https://...'),
          keyboardType: TextInputType.url,
          textInputAction: TextInputAction.next,
          validator: (v) => validateAnnouncementLink(v, eventId: _eventId),
        ),
        if (_eventId != null)
          const StudioHint(
            'Linked to an event: tapping opens the event. Set Linked event '
            'to None to use a button link instead.',
          ),
        const SizedBox(height: AppSpacing.sm),

        const StudioFieldLabel('Button label (optional)'),
        TextFormField(
          controller: _ctaCtrl,
          maxLength: kAnnouncementCtaMaxLength,
          style: AppTypography.bodyLg.copyWith(color: AppColors.onSurface),
          decoration: studioInputDecoration(hint: 'Learn more'),
          textInputAction: TextInputAction.done,
          validator: (v) => (v ?? '').trim().length > kAnnouncementCtaMaxLength
              ? 'At most $kAnnouncementCtaMaxLength characters'
              : null,
        ),
        const SizedBox(height: AppSpacing.xs),

        AnnouncementWillAppearPanel(
          audience: AnnouncementHomeVisibility.audienceFor(_audienceBranch),
          publishAt: scheduled ? publishAt : null,
          expiresAt: _expiresInstant,
          isNew: !isEdit,
        ),
        const SizedBox(height: AppSpacing.md),

        StudioSaveButton(
          label: isEdit ? 'Save changes' : 'Add announcement',
          saving: _saving,
          onPressed: campusesReady ? _submit : null,
        ),
        if (!campusesReady) const StudioHint(kLoadingCampusesHint),
      ],
    );
  }

  String _publishLabel() {
    final wall = _publishWall;
    if (wall == null) return 'Now';
    final label = studioDateTimeLabel(wall);
    final instant = _publishInstant!;
    if (!_publishChanged && !instant.isAfter(DateTime.now())) {
      return 'Published $label';
    }
    return label;
  }

  Widget _linkedEventField() {
    final events =
        ref.watch(upcomingEventsProvider(null)).valueOrNull ?? const <Event>[];
    final current = _eventId;
    final missing =
        current != null && !events.any((event) => event.id == current);
    return DropdownButtonFormField<String?>(
      initialValue: current,
      isExpanded: true,
      dropdownColor: AppColors.surfaceContainer,
      style: AppTypography.bodyLg.copyWith(color: AppColors.onSurface),
      decoration: studioInputDecoration(),
      items: [
        const DropdownMenuItem<String?>(value: null, child: Text('None')),
        if (missing)
          DropdownMenuItem<String?>(
            value: current,
            child: const Text('Current event (no longer upcoming)'),
          ),
        for (final event in events)
          DropdownMenuItem<String?>(
            value: event.id,
            child: Text(
              linkedEventLabel(event),
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: (v) => setState(() => _eventId = v),
    );
  }

  Future<void> _pickPublish() async {
    final today = _londonToday;
    final current = _publishWall;
    final date = await pickStudioDate(
      context,
      initial: current == null ? today : _dayOf(current),
      first: today,
      last: DateTime(today.year + 1, today.month, today.day),
    );
    if (date == null || !mounted) return;

    final isToday = _dayOf(date) == today;
    final nowWall = toLondonWallClock(DateTime.now());
    final TimeOfDay initialTime;
    if (current != null && _publishChanged) {
      initialTime = TimeOfDay(hour: current.hour, minute: current.minute);
    } else if (isToday) {
      initialTime = TimeOfDay(hour: (nowWall.hour + 1).clamp(0, 23), minute: 0);
    } else {
      initialTime = const TimeOfDay(hour: 9, minute: 0);
    }
    final time = await pickStudioTime(context, initial: initialTime);
    if (time == null || !mounted) return;

    setState(() {
      _publishWall = DateTime.utc(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
      _publishChanged = true;
      _scheduleError = null;
    });
  }

  Future<void> _pickExpiry() async {
    final today = _londonToday;
    final publishWall = _publishWall;
    final publishDay = publishWall == null ? today : _dayOf(publishWall);
    final first = publishDay.isAfter(today) ? publishDay : today;
    final date = await pickStudioDate(
      context,
      initial: _expiresDay ?? first.add(const Duration(days: 7)),
      first: first,
      last: DateTime(today.year + 2, today.month, today.day),
    );
    if (date == null || !mounted) return;
    setState(() {
      _expiresDay = _dayOf(date);
      _expiresChanged = true;
      _scheduleError = null;
    });
  }

  /// Schedule sanity: a chosen publish time must be ahead, and the expiry
  /// must come after the item goes live. Only checks what the admin set, so
  /// an old item can still be edited as it stands.
  String? _validateSchedule() {
    final now = DateTime.now();
    final publishAt = _publishInstant;
    final isNew = widget.item == null;
    if ((isNew || _publishChanged) &&
        publishAt != null &&
        publishAt.isBefore(now)) {
      return 'That publish time has passed. Pick a later time, or Now.';
    }
    final expiresAt = _expiresInstant;
    if ((isNew || _expiresChanged || _publishChanged) &&
        expiresAt != null &&
        !expiresAt.isAfter(publishAt ?? now)) {
      return 'The expiry must be after the publish time.';
    }
    return null;
  }

  Future<void> _submit() async {
    final scheduleError = _validateSchedule();
    final valid = _formKey.currentState!.validate();
    setState(() => _scheduleError = scheduleError);
    if (!valid || scheduleError != null) return;
    setState(() => _saving = true);

    final item = widget.item;
    final title = _titleCtrl.text.trim();
    try {
      if (item == null) {
        await widget.repo.addNews(
          title: title,
          type: _type,
          body: _bodyCtrl.text,
          imageUrl: _imageUrlCtrl.text,
          branch: _audienceBranch,
          publishAt: _publishInstant,
          expiresAt: _expiresInstant,
          eventId: _eventId,
          linkUrl: normaliseAnnouncementLink(_linkCtrl.text),
          ctaLabel: _ctaCtrl.text,
        );
        widget.onSuccess(
          _publishInstant == null
              ? 'Announcement added.'
              : 'Announcement scheduled.',
        );
      } else {
        await widget.repo.updateNews(
          item.id,
          title: title,
          type: _type,
          body: _bodyCtrl.text,
          imageUrl: _imageUrlCtrl.text,
          branch: _audienceBranch,
          // Only re-dated when the admin changed it; "Now" means now.
          publishAt: _publishChanged
              ? (_publishInstant ?? DateTime.now())
              : null,
          // Always written: unchanged passes the stored value through.
          expiresAt: _expiresInstant,
          eventId: _eventId,
          linkUrl: normaliseAnnouncementLink(_linkCtrl.text),
          ctaLabel: _ctaCtrl.text,
        );
        widget.onSuccess('Announcement updated.');
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      widget.onError('Save failed: $e');
      if (mounted) setState(() => _saving = false);
    }
  }
}
