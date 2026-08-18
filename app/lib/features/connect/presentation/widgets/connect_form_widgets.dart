import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kharis_app/shared/providers/admin_provider.dart';
import 'package:kharis_app/core/theme/theme.dart';

/// Offline fallback for [ConnectBranchDropdown].
///
/// Only used when the live branch list has not loaded. The real list comes
/// from `branchesProvider` — this used to be a hardcoded const the dropdown
/// read directly, which meant a branch added or renamed in Content Studio
/// never reached these forms, and it still listed "Medway", which is not a
/// branch in the network.
const List<String> _kFallbackBranches = [
  'London',
  'Birmingham',
  'Reading',
  'Chatham',
  'Croydon',
  'Accra',
  'Freetown',
];

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
      style: GoogleFonts.plusJakartaSans(
        fontSize: 15,
        color: context.kc.onBg,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          color: context.kc.muted,
        ),
        filled: true,
        fillColor: context.kc.surfaceAlt,
        suffixIcon: suffixIcon,
        counterStyle: GoogleFonts.plusJakartaSans(
          fontSize: 12,
          color: context.kc.muted,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: context.kc.accentInk, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.error, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
        errorStyle: GoogleFonts.plusJakartaSans(
          fontSize: 12,
          color: AppColors.error,
        ),
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
        : _kFallbackBranches;
    return Container(
      decoration: BoxDecoration(
        color: context.kc.surfaceAlt,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Text(
            'Branch',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              color: context.kc.muted,
            ),
          ),
          dropdownColor: context.kc.surface,
          isExpanded: true,
          icon: Icon(Icons.keyboard_arrow_down, color: context.kc.muted),
          style: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            color: context.kc.onBg,
          ),
          items: names
              .map(
                (b) => DropdownMenuItem(
                  value: b,
                  child: Text(b),
                ),
              )
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
