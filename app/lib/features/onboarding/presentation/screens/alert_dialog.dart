import 'package:flutter/material.dart';

import '../../../../theme/kharis_theme.dart';

/// The app-update prompt: the platform's own dialog (Cupertino on iOS,
/// Material elsewhere) styled from the design tokens. With [forceUpdate] the
/// cancel action is hidden.
void showPlatformAlertDialogAdaptive(
  BuildContext context, {
  required String title,
  required String description,
  required bool forceUpdate,
  VoidCallback? onOk,
  VoidCallback? onCancel,
  String okText = 'OK',
  String cancelText = 'Cancel',
}) {
  showAdaptiveDialog(
    context: context,
    builder: (BuildContext context) {
      final k = context.k;
      return AlertDialog.adaptive(
        title: Text(title, style: KharisText.title.copyWith(color: k.text)),
        content: Text(
          description,
          style: KharisText.body.copyWith(color: k.muted),
        ),
        actions: <Widget>[
          if (!forceUpdate)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                if (onCancel != null) onCancel();
              },
              child: Text(
                cancelText,
                style: KharisText.button.copyWith(color: k.muted),
              ),
            ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              if (onOk != null) onOk();
            },
            child: Text(
              okText,
              style: KharisText.button.copyWith(color: k.primaryText),
            ),
          ),
        ],
      );
    },
  );
}
