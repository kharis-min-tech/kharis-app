import 'package:flutter/material.dart';

import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/features/admin/presentation/widgets/studio_form_kit.dart';
import 'package:kharis_app/shared/models/campus_config.dart';

/// Edits a [GivingDetails] map: a campus's own `branches/{id}.giving` or the
/// church-wide `config/giving`. Shared by the branch page and App settings.
///
/// Saving with every field blank, or tapping [clearLabel], hands `null` to
/// [onSave]: the map is removed and members get the fallback ([fallbackHint]
/// says which). [onSave] reports its own failure and then throws; the editor
/// keeps what was typed.
class GivingEditor extends StatefulWidget {
  const GivingEditor({
    super.key,
    required this.initial,
    required this.clearLabel,
    required this.fallbackHint,
    required this.onSave,
  });

  /// The stored details; null while none are set here.
  final GivingDetails? initial;

  /// e.g. 'Use church-wide giving'.
  final String clearLabel;

  /// What members see while nothing is set here.
  final String fallbackHint;

  final Future<void> Function(GivingDetails? giving) onSave;

  @override
  State<GivingEditor> createState() => _GivingEditorState();
}

/// One editable [GivingDetails] field.
typedef _Field = ({String key, String label, String hint});

const List<_Field> _fields = [
  (key: 'url', label: 'Online giving link', hint: 'https://…'),
  (key: 'bankName', label: 'Bank name', hint: 'e.g. Barclays'),
  (key: 'accountName', label: 'Account name', hint: 'Kharis Church'),
  (key: 'sortCode', label: 'Sort code', hint: '00-00-00'),
  (key: 'accountNumber', label: 'Account number', hint: '12345678'),
  (key: 'swiftBic', label: 'SWIFT / BIC (international)', hint: 'BARCGB22'),
  (key: 'iban', label: 'IBAN (international)', hint: 'GB00 BARC …'),
  (key: 'reference', label: 'Payment reference', hint: 'e.g. LONDON TITHE'),
  (key: 'note', label: 'Note (optional)', hint: 'Shown under the details'),
];

/// Fields that only make sense as part of a bank transfer.
const _bankKeys = {
  'bankName',
  'accountName',
  'sortCode',
  'accountNumber',
  'swiftBic',
  'iban',
};

class _GivingEditorState extends State<GivingEditor> {
  final _formKey = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _ctrls;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final g = widget.initial?.toJson() ?? const {};
    _ctrls = {
      for (final f in _fields)
        f.key: TextEditingController(text: (g[f.key] as String?) ?? ''),
    };
  }

  @override
  void dispose() {
    for (final c in _ctrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  String? _value(String key) {
    final v = _ctrls[key]!.text.trim();
    return v.isEmpty ? null : v;
  }

  bool get _hasBankDetail => _bankKeys.any((k) => _value(k) != null);

  String? _validate(String key, String? raw) {
    final v = raw?.trim() ?? '';
    if (key == 'url') {
      if (v.isEmpty) {
        // A reference or note alone has nothing to apply to, and would be
        // dropped on read (see [GivingDetails.fromJson]).
        final orphan =
            !_hasBankDetail &&
            (_value('reference') != null || _value('note') != null);
        return orphan
            ? 'Add a giving link or bank details for the reference to apply'
            : null;
      }
      final uri = Uri.tryParse(v);
      final scheme = uri?.scheme.toLowerCase();
      if (uri == null ||
          (scheme != 'http' && scheme != 'https') ||
          uri.host.isEmpty) {
        return 'Links must be a full http:// or https:// address';
      }
    }
    if ((key == 'accountName' || key == 'accountNumber') &&
        v.isEmpty &&
        _hasBankDetail) {
      return 'Needed for bank transfers';
    }
    return null;
  }

  GivingDetails get _details => GivingDetails(
    url: _value('url'),
    bankName: _value('bankName'),
    accountName: _value('accountName'),
    sortCode: _value('sortCode'),
    accountNumber: _value('accountNumber'),
    swiftBic: _value('swiftBic'),
    iban: _value('iban'),
    reference: _value('reference'),
    note: _value('note'),
  );

  Future<void> _save({required bool clear}) async {
    if (!clear && !_formKey.currentState!.validate()) return;
    final details = clear ? null : _details;
    setState(() => _saving = true);
    try {
      await widget.onSave(details == null || details.isEmpty ? null : details);
      if (!mounted) return;
      if (clear || details == null || details.isEmpty) {
        for (final c in _ctrls.values) {
          c.clear();
        }
      }
    } catch (_) {
      // [GivingEditor.onSave] already told the admin; keep their input.
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.initial == null)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Text(
                widget.fallbackHint,
                style: AppTypography.bodySm.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ),
          for (final f in _fields) ...[
            StudioFieldLabel(f.label),
            TextFormField(
              key: ValueKey('giving-${f.key}'),
              controller: _ctrls[f.key],
              style: AppTypography.bodyLg.copyWith(color: AppColors.onSurface),
              decoration: studioInputDecoration(hint: f.hint),
              keyboardType: f.key == 'url' ? TextInputType.url : null,
              maxLines: f.key == 'note' ? 3 : 1,
              textInputAction: TextInputAction.next,
              validator: (v) => _validate(f.key, v),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          StudioSaveButton(
            label: 'Save giving details',
            saving: _saving,
            onPressed: () => _save(clear: false),
          ),
          if (widget.initial != null)
            Center(
              child: TextButton(
                onPressed: _saving ? null : () => _save(clear: true),
                child: Text(
                  widget.clearLabel,
                  style: AppTypography.labelMd.copyWith(
                    color: AppColors.secondary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
