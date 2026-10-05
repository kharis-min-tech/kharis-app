import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kharis_app/features/onboarding/data/branch_repository.dart';
import 'package:kharis_app/shared/providers/admin_provider.dart';
import 'package:kharis_app/core/theme/theme.dart';

/// Styled text form field matching the dark connect form aesthetic.
class ConnectFormField extends StatelessWidget {
  const ConnectFormField({
    super.key,
    required this.controller,
    required this.label,
    this.keyboardType,
    this.textInputAction,
    this.validator,
    this.maxLines = 1,
    this.maxLength,
    this.suffixIcon,
  });

  final TextEditingController controller;
  final String label;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final FormFieldValidator<String>? validator;
  final int maxLines;
  final int? maxLength;
  final Widget? suffixIcon;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      validator: validator,
      maxLines: maxLines,
      maxLength: maxLength,
      style: AppTypography.ui(size: 15, color: context.kc.onBg),
      decoration: InputDecoration(
        labelText: label,
        // A multi-line field keeps its label at the top, not floating in the
        // middle of an empty box.
        alignLabelWithHint: maxLines > 1,
        labelStyle: AppTypography.ui(size: 14, color: context.kc.muted),
        filled: true,
        fillColor: context.kc.surfaceAlt,
        suffixIcon: suffixIcon,
        counterStyle: AppTypography.ui(size: 12, color: context.kc.muted),
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
          borderSide: BorderSide(color: context.kc.accentInk, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.inputBorder,
          borderSide: BorderSide(color: context.kc.danger, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppRadius.inputBorder,
          borderSide: BorderSide(color: context.kc.danger, width: 1.5),
        ),
        errorStyle: AppTypography.ui(size: 12, color: context.kc.danger),
      ),
    );
  }
}

/// Styled branch dropdown matching the connect form aesthetic.
class ConnectBranchDropdown extends ConsumerWidget {
  const ConnectBranchDropdown({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final live = ref.watch(branchesProvider).valueOrNull;
    final names = (live != null && live.isNotEmpty)
        ? (live.map((b) => b.name).toList()..sort())
        : BranchRepository.seedBranches.map((b) => b.name).toList();
    return Container(
      decoration: BoxDecoration(
        color: context.kc.surfaceAlt,
        borderRadius: AppRadius.inputBorder,
      ),
      // 20 on the left lines "Branch" up with the text-field labels above.
      padding: const EdgeInsets.only(left: 20, right: 14),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Text(
            'Branch',
            style: AppTypography.ui(size: 14, color: context.kc.muted),
          ),
          dropdownColor: context.kc.surface,
          isExpanded: true,
          icon: Icon(Icons.keyboard_arrow_down, color: context.kc.muted),
          style: AppTypography.ui(size: 15, color: context.kc.onBg),
          items: names
              .map((b) => DropdownMenuItem(value: b, child: Text(b)))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
