import 'package:flutter/material.dart';

import '../../theme/kharis_theme.dart';

/// One book in a [KBookGrid].
typedef KBookCell = ({String id, String label});

/// The books of the Bible as a compact grid of names, in the passage picker,
/// so a testament fits on one phone screen. Each cell is at least 44 tall,
/// holds up to two lines and grows with the text. Selected: inverse fill,
/// announced as selected.
///
/// Columns: enough for at most [_rows] rows, between what keeps every name
/// whole and what the width allows at the member's text size.
class KBookGrid extends StatelessWidget {
  const KBookGrid({
    super.key,
    required this.books,
    required this.onSelected,
    this.selected,
  });

  final List<KBookCell> books;
  final ValueChanged<String> onSelected;

  /// The open book's id, if it is in [books].
  final String? selected;

  /// Rows the grid aims to stay within.
  static const int _rows = 10;

  /// The narrowest cell that keeps "Thessalonians" whole at 100% text.
  static const double _minCell = KSize.listRow + KSpace.section;

  /// The cell width that suits names best when there is room.
  static const double _idealCell = KSize.listRow * 2;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final scale = MediaQuery.textScalerOf(context).scale(1);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        int fit(double cell) =>
            ((width + KSpace.xs) / (cell * scale + KSpace.xs)).floor();
        final most = fit(_minCell).clamp(1, books.length + 1);
        final least = fit(_idealCell).clamp(1, most);
        final columns = ((books.length + _rows - 1) ~/ _rows).clamp(
          least,
          most,
        );

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisExtent: MediaQuery.textScalerOf(
              context,
            ).scale(KSize.touchMin),
            mainAxisSpacing: KSpace.xs,
            crossAxisSpacing: KSpace.xs,
          ),
          itemCount: books.length,
          itemBuilder: (context, i) {
            final book = books[i];
            final on = book.id == selected;
            return Semantics(
              button: true,
              selected: on,
              label: book.label,
              excludeSemantics: true,
              child: Material(
                color: on ? k.inverse : k.surface2,
                clipBehavior: Clip.antiAlias,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(KRadius.chip)),
                ),
                child: InkWell(
                  key: Key('bible-book-${book.id}'),
                  onTap: () => onSelected(book.id),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: KSpace.xxs),
                    child: Center(
                      child: Text(
                        book.label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: KharisText.caption.copyWith(
                          color: on ? k.onInverse : k.text,
                          height: 1.15,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
