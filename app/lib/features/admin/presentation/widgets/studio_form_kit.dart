import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:kharis_app/core/theme/theme.dart';

/// Building blocks for the Studio forms (the notification composer), so
/// fields, pickers and buttons look the same everywhere.

/// `Sat 4 Oct`.
String studioDayLabel(DateTime date) => DateFormat('EEE d MMM').format(date);

/// `Sat 4 Oct 2026, 09:00`.
String studioDateTimeLabel(DateTime date) =>
    DateFormat('EEE d MMM y, HH:mm').format(date);

InputDecoration studioInputDecoration({String? hint}) => InputDecoration(
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

/// Dark theme for the date and time pickers the forms open.
ThemeData studioPickerTheme() => ThemeData.dark().copyWith(
  colorScheme: const ColorScheme.dark(
    primary: AppColors.secondary,
    onPrimary: AppColors.onSecondary,
    surface: AppColors.surfaceDark,
    onSurface: AppColors.onSurface,
  ),
);

/// Date picker in the Studio theme.
Future<DateTime?> pickStudioDate(
  BuildContext context, {
  required DateTime initial,
  required DateTime first,
  required DateTime last,
}) {
  return showDatePicker(
    context: context,
    initialDate: initial.isBefore(first)
        ? first
        : (initial.isAfter(last) ? last : initial),
    firstDate: first,
    lastDate: last,
    builder: (ctx, child) => Theme(data: studioPickerTheme(), child: child!),
  );
}

/// Time picker in the Studio theme.
Future<TimeOfDay?> pickStudioTime(
  BuildContext context, {
  required TimeOfDay initial,
}) {
  return showTimePicker(
    context: context,
    initialTime: initial,
    builder: (ctx, child) => Theme(data: studioPickerTheme(), child: child!),
  );
}

/// Field caption above an input.
class StudioFieldLabel extends StatelessWidget {
  const StudioFieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
    child: Text(
      text,
      style: AppTypography.labelMd.copyWith(color: AppColors.onSurfaceVariant),
    ),
  );
}

/// Tappable field that opens a picker; [onClear] adds a clear (X) button.
class StudioPickerButton extends StatelessWidget {
  const StudioPickerButton({
    super.key,
    required this.label,
    required this.hasValue,
    required this.onTap,
    this.icon = Icons.calendar_today_rounded,
    this.onClear,
    this.clearTooltip = 'Clear',
  });

  final String label;
  final bool hasValue;
  final VoidCallback onTap;
  final IconData icon;
  final VoidCallback? onClear;
  final String clearTooltip;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceSubtle,
      borderRadius: AppRadius.inputBorder,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.inputBorder,
        child: Padding(
          padding: EdgeInsets.only(
            left: AppSpacing.sm,
            right: onClear == null ? AppSpacing.sm : 0,
            top: onClear == null ? AppSpacing.sm : 0,
            bottom: onClear == null ? AppSpacing.sm : 0,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 16,
                color: hasValue ? AppColors.secondary : AppColors.textFaint,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  label,
                  style: AppTypography.bodyLg.copyWith(
                    color: hasValue ? AppColors.onSurface : AppColors.textFaint,
                  ),
                ),
              ),
              if (onClear != null)
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  color: AppColors.onSurfaceVariant,
                  tooltip: clearTooltip,
                  onPressed: onClear,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Full-width primary save button with a spinner while [saving].
class StudioSaveButton extends StatelessWidget {
  const StudioSaveButton({
    super.key,
    required this.label,
    required this.saving,
    required this.onPressed,
  });

  final String label;
  final bool saving;

  /// `null` disables the button.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton(
        onPressed: saving ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.secondary,
          foregroundColor: AppColors.onSecondary,
          shape: RoundedRectangleBorder(borderRadius: AppRadius.buttonBorder),
        ),
        child: saving
            ? const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.onSecondary,
                ),
              )
            : Text(
                label,
                style: AppTypography.bodyLg.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.onSecondary,
                ),
              ),
      ),
    );
  }
}

/// Muted helper line under a field or button.
class StudioHint extends StatelessWidget {
  const StudioHint(this.text, {super.key, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.xs),
    child: Text(
      text,
      style: AppTypography.labelMd.copyWith(
        color: color ?? AppColors.textMuted,
      ),
    ),
  );
}
