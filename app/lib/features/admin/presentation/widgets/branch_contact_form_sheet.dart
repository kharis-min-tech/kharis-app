import 'package:flutter/material.dart';

import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/features/admin/data/branch_settings_repository.dart';
import 'package:kharis_app/features/admin/presentation/widgets/studio_form_kit.dart';
import 'package:kharis_app/shared/models/campus_config.dart';

/// Bottom sheet that edits a campus's contact details: `contact.email`,
/// `contact.phone` and the top-level `instagram`.
class BranchContactFormSheet extends StatefulWidget {
  const BranchContactFormSheet({
    super.key,
    required this.branchId,
    required this.branchName,
    required this.contact,
    required this.repo,
    required this.onSuccess,
    required this.onError,
  });

  final String branchId;
  final String branchName;
  final CampusContact contact;
  final BranchSettingsRepository repo;
  final void Function(String) onSuccess;
  final void Function(String) onError;

  @override
  State<BranchContactFormSheet> createState() => _BranchContactFormSheetState();
}

class _BranchContactFormSheetState extends State<BranchContactFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _instagramCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _emailCtrl = TextEditingController(text: widget.contact.email ?? '');
    _phoneCtrl = TextEditingController(text: widget.contact.phone ?? '');
    _instagramCtrl = TextEditingController(
      text: widget.contact.instagram ?? '',
    );
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _instagramCtrl.dispose();
    super.dispose();
  }

  static String? _nullIfBlank(String raw) {
    final v = raw.trim();
    return v.isEmpty ? null : v;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await widget.repo.setContact(
        widget.branchId,
        CampusContact(
          email: _nullIfBlank(_emailCtrl.text),
          phone: _nullIfBlank(_phoneCtrl.text),
          instagram: _nullIfBlank(_instagramCtrl.text),
        ),
      );
      widget.onSuccess('Contact details updated.');
      if (mounted) Navigator.pop(context);
    } catch (e) {
      widget.onError('Save failed: $e');
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _field(
    String label,
    TextEditingController ctrl,
    String hint, {
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StudioFieldLabel(label),
        TextFormField(
          controller: ctrl,
          style: AppTypography.bodyLg.copyWith(color: AppColors.onSurface),
          decoration: studioInputDecoration(hint: hint),
          keyboardType: keyboardType,
          textInputAction: TextInputAction.next,
          validator: validator,
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    return StudioSheet(
      formKey: _formKey,
      children: [
        Text(
          'Contact details',
          style: AppTypography.titleMd.copyWith(color: AppColors.heading),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'How members reach ${widget.branchName}. Blank fields are hidden.',
          style: AppTypography.labelMd.copyWith(color: AppColors.textMuted),
        ),
        const SizedBox(height: AppSpacing.md),
        _field(
          'Email',
          _emailCtrl,
          'london@kharis.org',
          keyboardType: TextInputType.emailAddress,
          validator: (v) {
            final t = v?.trim() ?? '';
            return t.isEmpty ||
                    RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(t)
                ? null
                : 'Enter a valid email address';
          },
        ),
        _field(
          'Phone',
          _phoneCtrl,
          '+44 20 0000 0000',
          keyboardType: TextInputType.phone,
        ),
        _field('Instagram', _instagramCtrl, '@kharislondon or a profile link'),
        StudioSaveButton(
          label: 'Save contact details',
          saving: _saving,
          onPressed: _submit,
        ),
      ],
    );
  }
}
