import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

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
      return AlertDialog.adaptive(
        title: Text(
          title,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            fontSize: 16.sp,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        content: Text(
          description,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            fontSize: 10.sp,
            fontWeight: FontWeight.w400,
            color: Colors.black.withValues(alpha: 0.6),
          ),
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
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w500,
                  color: Colors.red,
                ),
              ),
            ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              if (onOk != null) onOk();
            },
            child: Text(
              okText,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontSize: 14.sp,
                fontWeight: FontWeight.w500,
                color: Colors.green,
              ),
            ),
          ),
        ],
      );
    },
  );
}
