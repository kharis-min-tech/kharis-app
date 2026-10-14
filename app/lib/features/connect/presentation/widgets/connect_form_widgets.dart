import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kharis_app/features/onboarding/data/branch_repository.dart';
import 'package:kharis_app/shared/providers/admin_provider.dart';
import 'package:kharis_app/core/theme/theme.dart';

/// Every connect-form control has the same shape: a [label] line above, a
/// filled input below (with an optional muted placeholder). Text fields,
/// dropdowns and the date field all use it, so no field floats its label
/// while the others show placeholders.
class _LabelledField extends StatelessWidget {
  const _LabelledField({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            label,
            style: AppTypography.ui(
              size: 13,
              weight: FontWeight.w600,
              color: context.kc.onBg,
            ),
          ),
        ),
        child,
      ],
    );
  }
}

InputDecoration _decoration(
  BuildContext context, {
  String? hint,
  Widget? suffixIcon,
}) {
  final kc = context.kc;
  OutlineInputBorder border(Color? color, double width) => OutlineInputBorder(
    borderRadius: AppRadius.inputBorder,
    borderSide: color == null
        ? BorderSide.none
        : BorderSide(color: color, width: width),
  );
  return InputDecoration(
    hintText: hint,
    hintStyle: AppTypography.ui(size: 15, color: kc.muted),
    filled: true,
    fillColor: kc.surfaceAlt,
    suffixIcon: suffixIcon,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    counterStyle: AppTypography.ui(size: 12, color: kc.muted),
    border: border(null, 0),
    enabledBorder: border(null, 0),
    focusedBorder: border(kc.accentInk, 2),
    errorBorder: border(kc.danger, 1),
    focusedErrorBorder: border(kc.danger, 1.5),
    errorStyle: AppTypography.ui(size: 12, color: kc.danger),
  );
}

/// Labelled text field for the connect forms. [readOnly] with [onTap] makes
/// a picker field (the visit date) that looks exactly like the others.
class ConnectFormField extends StatelessWidget {
  const ConnectFormField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.keyboardType,
    this.textInputAction,
    this.validator,
    this.maxLines = 1,
    this.maxLength,
    this.suffixIcon,
    this.readOnly = false,
    this.onTap,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final FormFieldValidator<String>? validator;
  final int maxLines;
  final int? maxLength;
  final Widget? suffixIcon;
  final bool readOnly;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return _LabelledField(
      label: label,
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        validator: validator,
        maxLines: maxLines,
        maxLength: maxLength,
        readOnly: readOnly,
        onTap: onTap,
        style: AppTypography.ui(size: 15, color: context.kc.onBg),
        decoration: _decoration(context, hint: hint, suffixIcon: suffixIcon),
      ),
    );
  }
}

/// Labelled dropdown for the connect forms, validated with the form.
class ConnectDropdownField extends StatelessWidget {
  const ConnectDropdownField({
    super.key,
    required this.label,
    required this.hint,
    required this.items,
    required this.value,
    required this.onChanged,
    this.validator,
  });

  final String label;
  final String hint;
  final List<String> items;
  final String? value;
  final ValueChanged<String?> onChanged;
  final FormFieldValidator<String>? validator;

  @override
  Widget build(BuildContext context) {
    return _LabelledField(
      label: label,
      child: DropdownButtonFormField<String>(
        // Until the items load, a remembered choice has no item to match.
        initialValue: items.contains(value) ? value : null,
        items: [
          for (final item in items)
            DropdownMenuItem(value: item, child: Text(item)),
        ],
        onChanged: onChanged,
        validator: validator,
        isExpanded: true,
        dropdownColor: context.kc.surface,
        icon: Icon(Icons.keyboard_arrow_down, color: context.kc.muted),
        style: AppTypography.ui(size: 15, color: context.kc.onBg),
        decoration: _decoration(context, hint: hint),
      ),
    );
  }
}

/// Branch picker for the connect forms: the Content Studio branches, by name.
class ConnectBranchDropdown extends ConsumerWidget {
  const ConnectBranchDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.validator,
  });

  final String label;
  final String? value;
  final ValueChanged<String?> onChanged;
  final FormFieldValidator<String>? validator;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final names = [
      for (final b in ref.watch(branchesProvider).valueOrNull ?? const <Branch>[])
        b.name,
    ]..sort();
    return ConnectDropdownField(
      label: label,
      hint: 'Choose your branch',
      items: names,
      value: value,
      onChanged: onChanged,
      validator: validator,
    );
  }
}
