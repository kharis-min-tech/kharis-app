import 'package:flutter/material.dart';

import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/core/utils/service_time.dart';
import 'package:kharis_app/features/admin/data/branch_settings_repository.dart';
import 'package:kharis_app/features/admin/presentation/widgets/studio_form_kit.dart';
import 'package:kharis_app/shared/models/campus_config.dart';

/// Every entry of a raw `branches/{id}.services` list, hidden ones included,
/// in Studio order ([CampusService.listFromJson] keeps only active ones).
List<CampusService> allCampusServices(Object? raw) {
  if (raw is! List) return [];
  return raw.map(CampusService.fromJson).whereType<CampusService>().toList()
    ..sort((a, b) => a.order.compareTo(b.order));
}

/// A service id the way the web Studio makes them (a slug of the name),
/// suffixed until it is not in [taken].
String campusServiceId(String name, Iterable<String> taken) {
  final slug = name
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  final base = slug.isEmpty ? 'service' : slug;
  final used = taken.toSet();
  var id = base;
  for (var n = 2; used.contains(id); n++) {
    id = '$base-$n';
  }
  return id;
}

/// `HH:mm`, the 24-hour form the web Studio's time inputs store.
String _hhmm(TimeOfDay t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

/// Parses `HH:mm` / `h:mm AM`; null when unreadable.
TimeOfDay? _parseTime(String? raw) {
  final m = RegExp(
    r'^(\d{1,2}):(\d{2})\s*([AaPp][Mm])?$',
  ).firstMatch(raw?.trim() ?? '');
  if (m == null) return null;
  var h = int.parse(m[1]!);
  final min = int.parse(m[2]!);
  final ampm = m[3]?.toLowerCase();
  if (ampm == 'pm' && h < 12) h += 12;
  if (ampm == 'am' && h == 12) h = 0;
  if (h > 23 || min > 59) return null;
  return TimeOfDay(hour: h, minute: min);
}

/// Bottom sheet that adds, edits or removes one service time of a campus.
/// Saves the whole `services` list (the field is an array), keeping every
/// other entry as it was.
class BranchServiceFormSheet extends StatefulWidget {
  const BranchServiceFormSheet({
    super.key,
    required this.branchId,
    required this.services,
    required this.venues,
    this.service,
    required this.repo,
    required this.onSuccess,
    required this.onError,
  });

  final String branchId;

  /// The campus's current services, hidden ones included.
  final List<CampusService> services;

  /// The campus's venues (edited in the web Studio) a service can point at.
  final List<CampusVenue> venues;

  /// The service being edited; null adds one.
  final CampusService? service;
  final BranchSettingsRepository repo;
  final void Function(String) onSuccess;
  final void Function(String) onError;

  @override
  State<BranchServiceFormSheet> createState() => _BranchServiceFormSheetState();
}

class _BranchServiceFormSheetState extends State<BranchServiceFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _dayCtrl;
  late final TextEditingController _orderCtrl;
  String? _start;
  String? _end;
  String? _venueId;
  bool _active = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final s = widget.service;
    _nameCtrl = TextEditingController(text: s?.name ?? '');
    _dayCtrl = TextEditingController(text: s?.day ?? '');
    final nextOrder =
        widget.services.fold<int>(0, (m, e) => e.order > m ? e.order : m) + 1;
    _orderCtrl = TextEditingController(text: '${s?.order ?? nextOrder}');
    _start = s?.startTime;
    _end = s?.endTime;
    _venueId = s?.venueId;
    _active = s?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _dayCtrl.dispose();
    _orderCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickTime({required bool start}) async {
    final initial =
        _parseTime(start ? _start : _end) ??
        _parseTime(_start) ??
        const TimeOfDay(hour: 10, minute: 0);
    final t = await pickStudioTime(context, initial: initial);
    if (t == null || !mounted) return;
    setState(() {
      if (start) {
        _start = _hhmm(t);
      } else {
        _end = _hhmm(t);
      }
    });
  }

  Future<void> _write(List<CampusService> services, String message) async {
    setState(() => _saving = true);
    try {
      await widget.repo.setServices(widget.branchId, services);
      widget.onSuccess(message);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      widget.onError('Save failed: $e');
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final old = widget.service;
    final name = _nameCtrl.text.trim();
    final day = _dayCtrl.text.trim();
    final others = [
      for (final s in widget.services)
        if (s.id != old?.id) s,
    ];
    final saved = CampusService(
      id: old?.id ?? campusServiceId(name, others.map((s) => s.id)),
      name: name,
      type: old?.type,
      day: day.isEmpty ? null : day,
      startTime: _start,
      endTime: _end,
      venueId: _venueId,
      description: old?.description,
      order: int.parse(_orderCtrl.text.trim()),
      isActive: _active,
    );
    final next = [...others, saved]..sort((a, b) => a.order.compareTo(b.order));
    await _write(next, old == null ? 'Service added.' : 'Service updated.');
  }

  Future<void> _delete() async {
    final old = widget.service!;
    await _write([
      for (final s in widget.services)
        if (s.id != old.id) s,
    ], 'Service removed.');
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.service != null;
    final venueIds = [for (final v in widget.venues) v.id];
    final missingVenue = _venueId != null && !venueIds.contains(_venueId);
    return StudioSheet(
      formKey: _formKey,
      children: [
        Text(
          isEdit ? 'Edit service' : 'New service',
          style: AppTypography.titleMd.copyWith(color: AppColors.heading),
        ),
        const SizedBox(height: AppSpacing.md),

        const StudioFieldLabel('Name'),
        TextFormField(
          controller: _nameCtrl,
          style: AppTypography.bodyLg.copyWith(color: AppColors.onSurface),
          decoration: studioInputDecoration(hint: 'Sunday Service'),
          textInputAction: TextInputAction.next,
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Name is required' : null,
        ),
        const SizedBox(height: AppSpacing.sm),

        const StudioFieldLabel('Day(s)'),
        TextFormField(
          controller: _dayCtrl,
          style: AppTypography.bodyLg.copyWith(color: AppColors.onSurface),
          decoration: studioInputDecoration(hint: 'Sundays'),
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: AppSpacing.sm),

        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const StudioFieldLabel('Starts'),
                  StudioPickerButton(
                    icon: Icons.schedule_rounded,
                    label: formatServiceTime(_start) ?? 'Start time',
                    hasValue: _start != null,
                    onTap: () => _pickTime(start: true),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const StudioFieldLabel('Ends (optional)'),
                  StudioPickerButton(
                    icon: Icons.schedule_rounded,
                    label: formatServiceTime(_end) ?? 'End time',
                    hasValue: _end != null,
                    onTap: () => _pickTime(start: false),
                    onClear: _end == null
                        ? null
                        : () => setState(() => _end = null),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),

        if (widget.venues.isNotEmpty || missingVenue) ...[
          const StudioFieldLabel('Venue'),
          DropdownButtonFormField<String?>(
            initialValue: _venueId,
            isExpanded: true,
            dropdownColor: AppColors.surfaceContainer,
            style: AppTypography.bodyLg.copyWith(color: AppColors.onSurface),
            decoration: studioInputDecoration(),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('No venue'),
              ),
              for (final v in widget.venues)
                DropdownMenuItem<String?>(
                  value: v.id,
                  child: Text(v.name ?? v.id, overflow: TextOverflow.ellipsis),
                ),
              // A saved venue that no longer exists stays visible rather
              // than silently resetting to "no venue".
              if (missingVenue)
                DropdownMenuItem<String?>(
                  value: _venueId,
                  child: Text('$_venueId (missing)'),
                ),
            ],
            onChanged: (v) => setState(() => _venueId = v),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],

        const StudioFieldLabel('Order'),
        TextFormField(
          controller: _orderCtrl,
          style: AppTypography.bodyLg.copyWith(color: AppColors.onSurface),
          decoration: studioInputDecoration(hint: '1'),
          keyboardType: TextInputType.number,
          validator: (v) => int.tryParse(v?.trim() ?? '') == null
              ? 'Enter a whole number'
              : null,
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: [
            Expanded(
              child: Text(
                'Shown to members',
                style: AppTypography.bodyLg.copyWith(
                  color: AppColors.onSurface,
                ),
              ),
            ),
            Switch(
              value: _active,
              onChanged: (v) => setState(() => _active = v),
              activeThumbColor: AppColors.secondary,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        StudioSaveButton(
          label: isEdit ? 'Save service' : 'Add service',
          saving: _saving,
          onPressed: _submit,
        ),
        if (isEdit)
          Center(
            child: TextButton(
              onPressed: _saving ? null : _delete,
              child: Text(
                'Remove service',
                style: AppTypography.labelMd.copyWith(color: AppColors.error),
              ),
            ),
          ),
      ],
    );
  }
}
