import 'package:flutter/material.dart';

import 'package:kharis_app/ui/components/components.dart';

/// Asks the member to confirm an action in a bottom sheet: what will happen
/// in [message], one primary button ([confirmLabel]) and Cancel. True only
/// when they confirm; swiping the sheet away or tapping the scrim cancels.
Future<bool> showConfirmSheet(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
}) async {
  final confirmed = await showKBottomSheet<bool>(
    context: context,
    title: title,
    builder: (sheetContext) => SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            message,
            style: KharisText.body.copyWith(color: sheetContext.k.muted),
          ),
          const SizedBox(height: KSpace.x3),
          KButton(
            label: confirmLabel,
            expand: true,
            onPressed: () => Navigator.of(sheetContext).pop(true),
          ),
          const SizedBox(height: KSpace.md),
          KButton(
            label: 'Cancel',
            variant: KButtonVariant.text,
            expand: true,
            onPressed: () => Navigator.of(sheetContext).pop(false),
          ),
        ],
      ),
    ),
  );
  return confirmed ?? false;
}
