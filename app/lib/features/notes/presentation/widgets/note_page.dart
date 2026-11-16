import 'package:flutter/material.dart';

import 'package:kharis_app/ui/components/components.dart';

/// The frame of a full-screen note page (a message's notepad, a general
/// note): a [KScreenHeader] with a Close button, an optional one-line
/// [subtitle] such as the message title, and the editor below. These pages
/// open as modals over the notebook, so Close is their way out alongside the
/// system back.
class NotePage extends StatelessWidget {
  const NotePage({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
  });

  final String title;
  final String? subtitle;

  /// Fills the space under the header.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: KSize.maxContentWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: KSpace.x3),
                KScreenHeader(
                  title: title,
                  actions: [
                    KIconButton(
                      icon: KIcons.close,
                      label: 'Close',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: KSpace.gutter,
                    ),
                    child: Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: KharisText.meta.copyWith(color: context.k.muted),
                    ),
                  ),
                const SizedBox(height: KSpace.xl),
                Expanded(child: child),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
