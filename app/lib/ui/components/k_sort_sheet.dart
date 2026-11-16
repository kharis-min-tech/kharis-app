import 'package:flutter/material.dart';

import '../../theme/kharis_theme.dart';
import 'k_bottom_sheet.dart';
import 'k_option_card.dart';

/// One choice in a [KSortSheet].
class KSortOption<T> {
  const KSortOption({required this.value, required this.label});

  final T value;
  final String label;
}

/// Radio rows for a single choice, such as a sort order. Put it in a
/// [KBottomSheet], or call [showKSortSheet].
class KSortSheet<T> extends StatelessWidget {
  const KSortSheet({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final List<KSortOption<T>> options;
  final T? selected;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final line = BorderSide(color: k.line);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < options.length; i++)
          Semantics(
            button: true,
            inMutuallyExclusiveGroup: true,
            checked: options[i].value == selected,
            label: options[i].label,
            onTap: () => onSelected(options[i].value),
            excludeSemantics: true,
            child: DecoratedBox(
              position: DecorationPosition.foreground,
              decoration: BoxDecoration(
                border: i == 0 ? null : Border(top: line),
              ),
              child: InkWell(
                onTap: () => onSelected(options[i].value),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: KSize.listRow),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: KSpace.md),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            options[i].label,
                            style: KharisText.title.copyWith(color: k.text),
                          ),
                        ),
                        const SizedBox(width: KSpace.xl),
                        KRadioMark(selected: options[i].value == selected),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Shows a [KSortSheet] in a bottom sheet and completes with the chosen
/// value, or null if the sheet is dismissed.
Future<T?> showKSortSheet<T>({
  required BuildContext context,
  required String title,
  required List<KSortOption<T>> options,
  required T? selected,
}) {
  return showKBottomSheet<T>(
    context: context,
    title: title,
    builder: (sheetContext) => KSortSheet<T>(
      options: options,
      selected: selected,
      onSelected: (value) => Navigator.of(sheetContext).pop(value),
    ),
  );
}
