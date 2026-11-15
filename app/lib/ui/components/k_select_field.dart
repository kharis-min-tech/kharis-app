import 'package:flutter/material.dart';

import '../../theme/kharis_theme.dart';
import 'k_icon.dart';
import 'k_text_field.dart';

/// A labelled single-choice dropdown validated with its [Form]. Looks like
/// a [KTextField] with a chevron at the end.
class KSelectField extends StatelessWidget {
  const KSelectField({
    super.key,
    required this.label,
    required this.hint,
    required this.items,
    required this.value,
    required this.onChanged,
    this.validator,
  });

  final String label;
  final String hint;
  final List<String> items;

  /// Ignored while it is not one of [items] (the list may still be loading).
  final String? value;

  /// Null disables the field.
  final ValueChanged<String?>? onChanged;
  final FormFieldValidator<String>? validator;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final style = KharisText.body.copyWith(color: k.text);

    return KFieldLabel(
      label: label,
      child: DropdownButtonFormField<String>(
        initialValue: items.contains(value) ? value : null,
        items: [
          for (final item in items)
            DropdownMenuItem(
              value: item,
              child: Text(item, overflow: TextOverflow.ellipsis, style: style),
            ),
        ],
        onChanged: onChanged,
        validator: validator,
        isExpanded: true,
        dropdownColor: k.surface,
        borderRadius: const BorderRadius.all(Radius.circular(KRadius.card)),
        icon: KIcon(KIcons.chevronDown, size: KSize.iconSm, color: k.muted),
        style: style,
        decoration: kFieldDecoration(context, hint: hint),
      ),
    );
  }
}
