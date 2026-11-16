import 'package:flutter/widgets.dart';

import '../../theme/kharis_theme.dart';
import 'k_layout.dart';

/// The header of a top-level screen: the screen title on the left and up to
/// two [KIconButton]s on the right. There is no back button: people swipe
/// back or use the system back.
///
/// At large text sizes the actions move to their own row above the title, so
/// the title has the full width and is not broken mid-word.
class KScreenHeader extends StatelessWidget {
  const KScreenHeader({
    super.key,
    required this.title,
    this.actions = const [],
  });

  final String title;

  /// Up to two [KIconButton]s.
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    assert(actions.length <= 2, 'A screen header holds two actions at most.');

    final heading = Semantics(
      header: true,
      child: Text(
        title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: KharisText.screenTitle.copyWith(color: context.k.text),
      ),
    );
    final buttons = [
      for (final (i, action) in actions.indexed) ...[
        if (i > 0) const SizedBox(width: KSpace.md),
        action,
      ],
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: KSpace.gutter),
      child: actions.isNotEmpty && kIsLargeText(context)
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: buttons,
                ),
                heading,
              ],
            )
          : Row(
              children: [
                Expanded(child: heading),
                if (buttons.isNotEmpty) const SizedBox(width: KSpace.md),
                ...buttons,
              ],
            ),
    );
  }
}
