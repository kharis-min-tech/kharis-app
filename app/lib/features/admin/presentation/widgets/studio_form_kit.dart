import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/shared/providers/admin_provider.dart';
import 'package:kharis_app/shared/providers/auth_provider.dart';

/// Building blocks shared by the Content Studio bottom-sheet forms, so the
/// event and announcement sheets look and behave the same everywhere they
/// open (Studio lists and branch pages).

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

/// Rounded sheet with a drag handle and a scrolling [Form] (no [Form] when
/// [formKey] is null, for sheets whose editor owns its own form).
class StudioSheet extends StatelessWidget {
  const StudioSheet({super.key, this.formKey, required this.children});

  final GlobalKey<FormState>? formKey;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final content = Column(
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
        ...children,
      ],
    );
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
        child: formKey == null ? content : Form(key: formKey, child: content),
      ),
    );
  }
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

/// Campus scope dropdown backed by the Firestore branch list and the
/// signed-in admin's [AdminScope].
///
/// No hard-coded fallback: while the list (or the admin's scope) loads it
/// says so (and the form keeps Save disabled, see [studioCampusesReady]); on
/// error it offers a retry. A stored campus missing from the list is kept as
/// an option so editing never silently re-scopes an item. `null` is
/// all-campus, offered to super admins only: a campus admin picks one of
/// their own campuses and the field requires a choice.
class StudioCampusField extends ConsumerWidget {
  const StudioCampusField({
    super.key,
    required this.value,
    required this.onChanged,
    required this.allLabel,
  });

  final String? value;
  final ValueChanged<String?> onChanged;
  final String allLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branches = ref.watch(branchesProvider);
    final scopeAsync = ref.watch(adminScopeProvider);
    final loading = _status(
      const SizedBox.square(
        dimension: 14,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: AppColors.secondary,
        ),
      ),
      'Loading campuses',
    );
    if (branches.hasError || scopeAsync.hasError) {
      return _status(
        const Icon(Icons.cloud_off_rounded, size: 16, color: AppColors.error),
        'Could not load campuses.',
        action: TextButton(
          onPressed: () => ref
            ..invalidate(branchesProvider)
            ..invalidate(adminScopeProvider),
          child: Text(
            'Retry',
            style: AppTypography.labelMd.copyWith(color: AppColors.secondary),
          ),
        ),
      );
    }
    final list = branches.valueOrNull;
    final scope = scopeAsync.valueOrNull;
    if (list == null || scope == null) return loading;

    final campusOnly = !scope.isSuperAdmin;
    final names = [
      for (final b in list)
        if (scope.canManageCampusNamed(b.name)) b.name,
    ];
    if (campusOnly) {
      for (final n in scope.branchNames) {
        if (!names.contains(n)) names.add(n);
      }
    }
    final current = value;
    if (current != null && !names.contains(current)) names.add(current);
    return DropdownButtonFormField<String?>(
      initialValue: current,
      dropdownColor: AppColors.surfaceContainer,
      style: AppTypography.bodyLg.copyWith(color: AppColors.onSurface),
      decoration: studioInputDecoration(hint: 'Choose a campus'),
      items: [
        if (!campusOnly)
          DropdownMenuItem<String?>(value: null, child: Text(allLabel)),
        for (final name in names)
          DropdownMenuItem<String?>(value: name, child: Text(name)),
      ],
      validator: campusOnly
          ? (v) => v == null ? 'Choose one of your campuses' : null
          : null,
      onChanged: onChanged,
    );
  }

  Widget _status(Widget leading, String text, {Widget? action}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: action == null ? AppSpacing.sm : 2,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceSubtle,
        borderRadius: AppRadius.inputBorder,
      ),
      child: Row(
        children: [
          leading,
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              text,
              style: AppTypography.bodyLg.copyWith(color: AppColors.textMuted),
            ),
          ),
          ?action,
        ],
      ),
    );
  }
}

/// True once the campus list and the admin's scope have loaded, so a form
/// with a campus control may save. Forms show [kLoadingCampusesHint] next to
/// a disabled Save until then.
bool studioCampusesReady(WidgetRef ref) =>
    ref.watch(branchesProvider).hasValue &&
    ref.watch(adminScopeProvider).hasValue;

/// The campus a new item starts on: a campus admin's first campus (they may
/// not post church-wide content); `null` (all-campus) for a super admin.
String? studioDefaultCampus(WidgetRef ref) {
  final scope = ref.read(adminScopeProvider).valueOrNull;
  if (scope == null || scope.isSuperAdmin) return null;
  return (scope.branchNames.toList()..sort()).firstOrNull;
}

const String kLoadingCampusesHint = 'Loading campuses';

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
