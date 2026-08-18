import 'package:flutter/material.dart';

import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/core/utils/service_time.dart';
import 'package:kharis_app/features/onboarding/data/branch_repository.dart';

/// Bottom sheet that edits the member-facing venue fields of a branch:
/// address, meeting day(s) and meeting time.
///
/// Deliberately narrow. Name, subtitle, gradients, image, order and group are
/// edited on the branches list screen and are passed straight through here, so
/// a venue edit can never blank them.
class BranchVenueFormSheet extends StatefulWidget {
  const BranchVenueFormSheet({
    super.key,
    required this.branch,
    required this.repo,
    required this.onSuccess,
    required this.onError,
  });

  final Branch branch;
  final BranchRepository repo;
  final void Function(String) onSuccess;
  final void Function(String) onError;

  @override
  State<BranchVenueFormSheet> createState() => _BranchVenueFormSheetState();
}

class _BranchVenueFormSheetState extends State<BranchVenueFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _addressCtrl;
  late final TextEditingController _meetingDaysCtrl;
  late final TextEditingController _meetingTimeCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _addressCtrl = TextEditingController(text: widget.branch.address ?? '');
    _meetingDaysCtrl =
        TextEditingController(text: widget.branch.meetingDays ?? '');
    // Normalised to 12-hour form so an admin never sees the web portal's raw
    // 24-hour '14:00' in this field.
    _meetingTimeCtrl = TextEditingController(
      text: formatServiceTime(widget.branch.meetingTime) ?? '',
    );
  }

  @override
  void dispose() {
    _addressCtrl.dispose();
    _meetingDaysCtrl.dispose();
    _meetingTimeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                'Edit venue',
                style: AppTypography.titleMd.copyWith(color: AppColors.heading),
              ),
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
                    widget.branch.name,
                    style: AppTypography.labelMd
                        .copyWith(color: AppColors.secondary),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Shown to members on the Home screen.',
                style:
                    AppTypography.labelMd.copyWith(color: AppColors.textMuted),
              ),
              const SizedBox(height: AppSpacing.md),

              _label('Address'),
              const SizedBox(height: AppSpacing.xs),
              TextFormField(
                controller: _addressCtrl,
                style:
                    AppTypography.bodyLg.copyWith(color: AppColors.onSurface),
                decoration:
                    _deco(hint: 'Kensington Town Hall, London W8 7NX'),
                maxLines: 2,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: AppSpacing.sm),

              _label('Meeting day(s)'),
              const SizedBox(height: AppSpacing.xs),
              TextFormField(
                controller: _meetingDaysCtrl,
                style:
                    AppTypography.bodyLg.copyWith(color: AppColors.onSurface),
                decoration: _deco(hint: 'Sundays'),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: AppSpacing.sm),

              _label('Meeting time'),
              const SizedBox(height: AppSpacing.xs),
              TextFormField(
                controller: _meetingTimeCtrl,
                style:
                    AppTypography.bodyLg.copyWith(color: AppColors.onSurface),
                decoration: _deco(hint: '10:00 AM'),
                textInputAction: TextInputAction.done,
              ),
              const SizedBox(height: AppSpacing.md),

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
                          'Save venue',
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
      final b = widget.branch;
      await widget.repo.updateBranch(
        b.id,
        name: b.name,
        subtitle: b.subtitle,
        gradientStart: b.gradientStart,
        gradientEnd: b.gradientEnd,
        imageUrl: b.imageUrl,
        order: b.order,
        address: _nullIfBlank(_addressCtrl.text),
        meetingDays: _nullIfBlank(_meetingDaysCtrl.text),
        meetingTime: _nullIfBlank(_meetingTimeCtrl.text),
        group: b.group,
      );
      widget.onSuccess('Venue updated.');
      if (mounted) Navigator.pop(context);
    } catch (e) {
      widget.onError('Save failed: $e');
      if (mounted) setState(() => _saving = false);
    }
  }

  static String? _nullIfBlank(String raw) {
    final v = raw.trim();
    return v.isEmpty ? null : v;
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
      );
}
