import 'package:flutter/material.dart';

import '../../theme/kharis_theme.dart';
import 'k_icon.dart';

/// The search input: at least 52 tall, tile corners, surface fill with the
/// card border and shadow, a muted search icon and an optional trailing
/// [KIconButton].
class KSearchField extends StatelessWidget {
  const KSearchField({
    super.key,
    required this.hint,
    this.controller,
    this.focusNode,
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.trailing,
    this.readOnly = false,
    this.autofocus = false,
  });

  /// Placeholder, also what screen readers announce for the empty field.
  final String hint;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  /// With [readOnly], makes the field a button that opens the search screen.
  final VoidCallback? onTap;

  /// Usually a [KIconButton], such as Clear or the open-book button.
  final Widget? trailing;
  final bool readOnly;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final k = context.k;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: k.surface,
        borderRadius: const BorderRadius.all(Radius.circular(KRadius.tile)),
        border: Border.all(color: k.border),
        boxShadow: context.isDarkTheme ? KShadow.cardDark : KShadow.cardLight,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: KSize.searchField),
        child: Padding(
          padding: EdgeInsetsDirectional.only(
            start: KSpace.x3,
            end: trailing == null ? KSpace.x3 : KSpace.xs,
          ),
          child: Row(
            children: [
              KIcon(KIcons.search, color: k.muted),
              const SizedBox(width: KSpace.lg),
              Expanded(
                child: Material(
                  type: MaterialType.transparency,
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    onChanged: onChanged,
                    onSubmitted: onSubmitted,
                    onTap: onTap,
                    readOnly: readOnly,
                    autofocus: autofocus,
                    textInputAction: TextInputAction.search,
                    cursorColor: k.primaryText,
                    style: KharisText.body.copyWith(color: k.text),
                    decoration: InputDecoration.collapsed(
                      hintText: hint,
                      hintStyle: KharisText.body.copyWith(color: k.muted),
                    ),
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
        ),
      ),
    );
  }
}
