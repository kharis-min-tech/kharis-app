import 'package:flutter/material.dart';

import '../../theme/kharis_theme.dart';

/// The chapters of a book as a grid of numbers, in the passage picker.
/// Each cell is at least 44 tall. Selected: inverse fill, announced as
/// selected.
class KChapterGrid extends StatelessWidget {
  const KChapterGrid({
    super.key,
    required this.chapters,
    required this.onSelected,
    required this.book,
    this.selected,
    this.selectedKey,
  });

  /// Chapter numbers, in order.
  final List<int> chapters;
  final ValueChanged<int> onSelected;

  /// The book's name, read before each number ("John 3").
  final String book;

  /// The open chapter, if it is in this book.
  final int? selected;

  /// Put on the [selected] cell, so the picker can bring it into view.
  final GlobalKey? selectedKey;

  @override
  Widget build(BuildContext context) {
    final k = context.k;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: KSize.listRow,
        mainAxisExtent: MediaQuery.textScalerOf(context).scale(KSize.touchMin),
        mainAxisSpacing: KSpace.sm,
        crossAxisSpacing: KSpace.sm,
      ),
      itemCount: chapters.length,
      itemBuilder: (context, i) {
        final chapter = chapters[i];
        final on = chapter == selected;
        return Semantics(
          key: on ? selectedKey : null,
          button: true,
          selected: on,
          label: '$book $chapter',
          excludeSemantics: true,
          child: Material(
            color: on ? k.inverse : k.surface2,
            clipBehavior: Clip.antiAlias,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(KRadius.chip)),
            ),
            child: InkWell(
              key: Key('bible-chapter-$chapter'),
              onTap: () => onSelected(chapter),
              child: Center(
                child: Text(
                  '$chapter',
                  maxLines: 1,
                  style: KharisText.itemTitle.copyWith(
                    color: on ? k.onInverse : k.text,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
