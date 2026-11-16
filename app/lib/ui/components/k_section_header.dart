import 'package:flutter/material.dart';

import '../../theme/kharis_theme.dart';
import 'k_icon.dart';

/// Section title on the left, optional text action ("See all") on the right.
class KSectionHeader extends StatelessWidget {
  const KSectionHeader({super.key, required this.title, this.actionLabel, this.onAction});

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return Padding(
      padding: const EdgeInsets.only(bottom: KSpace.xl),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(title, style: KharisText.section.copyWith(color: k.text)),
            ),
          ),
          if (actionLabel != null)
            InkWell(
              onTap: onAction,
              borderRadius: const BorderRadius.all(Radius.circular(KRadius.button)),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: KSize.touchMin, minWidth: KSize.touchMin),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(actionLabel!, style: KharisText.link.copyWith(color: k.primaryText)),
                    KIcon(KIcons.chevronRight, size: 16, color: k.primaryText),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Small uppercase eyebrow above a title, in primaryText.
class KOverline extends StatelessWidget {
  const KOverline(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      semanticsLabel: text,
      style: KharisText.overline.copyWith(color: context.k.primaryText),
    );
  }
}
