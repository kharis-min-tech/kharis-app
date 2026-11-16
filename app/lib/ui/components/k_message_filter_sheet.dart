import 'package:flutter/material.dart';

import '../../theme/kharis_theme.dart';
import 'k_bottom_sheet.dart';
import 'k_button.dart';
import 'k_icon.dart';
import 'k_layout.dart';
import 'k_option_card.dart';

/// One choice in a [KFilterSheet].
class KFilterOption<T> {
  const KFilterOption({required this.value, required this.label, this.meta});

  final T value;
  final String label;

  /// A short fact after the label, such as how many messages it holds.
  final String? meta;
}

/// The body of a filter sheet: a hint, radio rows ([single]) or check rows,
/// then "Clear" and "Show results".
///
/// Choices are a draft until "Show results" hands them to [onApply]; closing
/// the sheet any other way changes nothing. "Clear" empties the draft; for
/// a [single] sheet an empty draft marks the first option, the default.
class KFilterSheet<T> extends StatefulWidget {
  const KFilterSheet({
    super.key,
    required this.options,
    required this.selected,
    required this.onApply,
    this.single = false,
    this.clearLabel = 'Clear',
    this.applyLabel = 'Show results',
  });

  final List<KFilterOption<T>> options;
  final Set<T> selected;
  final ValueChanged<Set<T>> onApply;

  /// Radio rows, one choice. Otherwise check rows, any number.
  final bool single;
  final String clearLabel;
  final String applyLabel;

  @override
  State<KFilterSheet<T>> createState() => _KFilterSheetState<T>();
}

class _KFilterSheetState<T> extends State<KFilterSheet<T>> {
  late Set<T> _draft = {...widget.selected};

  bool _isOn(int index) {
    final value = widget.options[index].value;
    if (_draft.contains(value)) return true;
    return widget.single && _draft.isEmpty && index == 0;
  }

  void _toggle(int index) {
    final value = widget.options[index].value;
    setState(() {
      if (widget.single) {
        _draft = {value};
      } else if (!_draft.remove(value)) {
        _draft.add(value);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final line = BorderSide(color: k.line);
    final clear = KButton(
      label: widget.clearLabel,
      variant: KButtonVariant.outline,
      expand: kIsLargeText(context),
      onPressed: () => setState(() => _draft = {}),
    );
    final apply = KButton(
      label: widget.applyLabel,
      variant: KButtonVariant.inverse,
      expand: true,
      onPressed: () => widget.onApply({..._draft}),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.single ? 'Choose one' : 'Choose any',
          style: KharisText.meta.copyWith(color: k.muted),
        ),
        const SizedBox(height: KSpace.md),
        Flexible(
          child: ListView.builder(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            itemCount: widget.options.length,
            itemBuilder: (context, i) {
              final option = widget.options[i];
              final on = _isOn(i);
              return Semantics(
                button: true,
                inMutuallyExclusiveGroup: widget.single,
                checked: on,
                label: option.meta == null
                    ? option.label
                    : '${option.label}, ${option.meta}',
                onTap: () => _toggle(i),
                excludeSemantics: true,
                child: DecoratedBox(
                  position: DecorationPosition.foreground,
                  decoration: BoxDecoration(
                    border: i == 0 ? null : Border(top: line),
                  ),
                  child: InkWell(
                    onTap: () => _toggle(i),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        minHeight: KSize.listRow,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: KSpace.md,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                option.label,
                                style: KharisText.title.copyWith(color: k.text),
                              ),
                            ),
                            if (option.meta != null) ...[
                              const SizedBox(width: KSpace.md),
                              Text(
                                option.meta!,
                                style: KharisText.meta.copyWith(color: k.muted),
                              ),
                            ],
                            const SizedBox(width: KSpace.xl),
                            if (widget.single)
                              KRadioMark(selected: on)
                            else
                              _CheckMark(selected: on),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: KSpace.x3),
        // At large text the buttons stack, so neither label is cut.
        if (kIsLargeText(context)) ...[
          apply,
          const SizedBox(height: KSpace.md),
          clear,
        ] else
          Row(
            children: [
              clear,
              const SizedBox(width: KSpace.lg),
              Expanded(child: apply),
            ],
          ),
      ],
    );
  }
}

/// The check box at the end of a check row. On: primary fill with a check,
/// so the state does not rest on colour alone.
class _CheckMark extends StatelessWidget {
  const _CheckMark({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.all(Radius.circular(KRadius.xs)),
        color: selected ? k.primary : null,
        border: selected
            ? null
            : Border.all(color: k.muted, width: KSize.outline),
      ),
      child: SizedBox.square(
        dimension: KSize.radio,
        child: selected
            ? Center(
                child: KIcon(
                  KIcons.check,
                  size: KSize.radioMark,
                  color: k.onPrimary,
                ),
              )
            : null,
      ),
    );
  }
}

/// Shows a [KFilterSheet] titled [title] and completes with the applied
/// choices, or null when the sheet is closed without "Show results".
Future<Set<T>?> showKFilterSheet<T>({
  required BuildContext context,
  required String title,
  required List<KFilterOption<T>> options,
  required Set<T> selected,
  bool single = false,
}) {
  return showKBottomSheet<Set<T>>(
    context: context,
    title: title,
    builder: (sheetContext) => KFilterSheet<T>(
      options: options,
      selected: selected,
      single: single,
      onApply: (choices) => Navigator.of(sheetContext).pop(choices),
    ),
  );
}
