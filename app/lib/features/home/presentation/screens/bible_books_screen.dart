import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kharis_app/core/constants/bible_books.dart';
import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/features/home/data/bible_repository.dart';
import 'package:kharis_app/shared/providers/bible_provider.dart';

/// Book list, then chapter grid, for the selected version. Resolves to the
/// chosen chapter, or null when the member backs out.
Future<BibleLocation?> pickBibleChapter(
  BuildContext context, {
  BibleLocation? current,
}) => Navigator.of(context).push<BibleLocation>(
  MaterialPageRoute(builder: (_) => BibleBooksScreen(current: current)),
);

AppBar _pickerAppBar(BuildContext context, String title) => AppBar(
  backgroundColor: context.kc.bg,
  elevation: 0,
  scrolledUnderElevation: 0,
  iconTheme: IconThemeData(color: context.kc.onBg),
  title: Text(
    title,
    style: AppTypography.display(
      size: 24,
      weight: FontWeight.w700,
      color: context.kc.onBg,
    ),
  ),
);

/// Books grouped Old Testament / New Testament (and other books for versions
/// that carry them).
class BibleBooksScreen extends ConsumerStatefulWidget {
  const BibleBooksScreen({super.key, this.current});

  /// Where the reader is; its book is marked and scrolled into view.
  final BibleLocation? current;

  @override
  ConsumerState<BibleBooksScreen> createState() => _BibleBooksScreenState();
}

class _BibleBooksScreenState extends ConsumerState<BibleBooksScreen> {
  final _currentKey = GlobalKey();
  bool _revealed = false;

  Future<void> _open(BibleBook book) async {
    final navigator = Navigator.of(context);
    if (book.chapters.length == 1) {
      navigator.pop(BibleLocation(book.usfm, book.chapters.single));
      return;
    }
    final picked = await navigator.push<BibleLocation>(
      MaterialPageRoute(
        builder: (_) =>
            BibleChaptersScreen(book: book, current: widget.current),
      ),
    );
    if (picked != null && mounted) navigator.pop(picked);
  }

  void _revealCurrent() {
    if (_revealed) return;
    _revealed = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _currentKey.currentContext;
      if (target != null) Scrollable.ensureVisible(target, alignment: 0.3);
    });
  }

  @override
  Widget build(BuildContext context) {
    final version = ref.watch(selectedBibleProvider);
    // Like the reader: the version's own list once it has loaded, the
    // bundled 66-book table until then, so a slow connection never leaves
    // the member looking at a spinner.
    final index =
        ref.watch(bibleIndexProvider(version.id)).valueOrNull ??
        BibleIndex.bundled();

    return Scaffold(
      backgroundColor: context.kc.bg,
      appBar: _pickerAppBar(context, 'Books'),
      body: Builder(
        builder: (context) {
          _revealCurrent();
          final groups = [
            ('Old Testament', Testament.old),
            ('New Testament', Testament.newTestament),
            ('Other books', Testament.other),
          ];
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final (label, testament) in groups)
                  if (index.books.any((b) => b.testament == testament)) ...[
                    _GroupLabel(label),
                    _BookCard(
                      books: [
                        for (final b in index.books)
                          if (b.testament == testament) b,
                      ],
                      currentUsfm: widget.current?.usfm,
                      currentKey: _currentKey,
                      onTap: _open,
                    ),
                    const SizedBox(height: 22),
                  ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 8, top: 8),
    child: Text(
      label.toUpperCase(),
      style: AppTypography.ui(
        size: 11,
        weight: FontWeight.w700,
        letterSpacing: 1.2,
      ).copyWith(color: context.kc.muted),
    ),
  );
}

class _BookCard extends StatelessWidget {
  const _BookCard({
    required this.books,
    required this.currentUsfm,
    required this.currentKey,
    required this.onTap,
  });

  final List<BibleBook> books;
  final String? currentUsfm;
  final GlobalKey currentKey;
  final ValueChanged<BibleBook> onTap;

  @override
  Widget build(BuildContext context) {
    final kc = context.kc;
    return Container(
      decoration: BoxDecoration(
        color: kc.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: AppShadows.card,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < books.length; i++)
            _BookRow(
              key: books[i].usfm == currentUsfm ? currentKey : null,
              book: books[i],
              selected: books[i].usfm == currentUsfm,
              isLast: i == books.length - 1,
              onTap: () => onTap(books[i]),
            ),
        ],
      ),
    );
  }
}

class _BookRow extends StatelessWidget {
  const _BookRow({
    super.key,
    required this.book,
    required this.selected,
    required this.isLast,
    required this.onTap,
  });

  final BibleBook book;
  final bool selected;
  final bool isLast;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final kc = context.kc;
    final count = book.chapters.length;
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 50),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: isLast
              ? null
              : BoxDecoration(
                  border: Border(bottom: BorderSide(color: kc.divider)),
                ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  book.title,
                  style: AppTypography.ui(
                    size: 15,
                    weight: selected ? FontWeight.w700 : FontWeight.w600,
                  ).copyWith(color: selected ? kc.onChip : kc.onBg),
                ),
              ),
              Text(
                '$count',
                style: AppTypography.ui(size: 13).copyWith(color: kc.muted),
              ),
              const SizedBox(width: 6),
              Icon(Icons.chevron_right_rounded, color: kc.faint, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

/// Chapter numbers of one book as a grid.
class BibleChaptersScreen extends StatelessWidget {
  const BibleChaptersScreen({super.key, required this.book, this.current});

  final BibleBook book;
  final BibleLocation? current;

  @override
  Widget build(BuildContext context) {
    final kc = context.kc;
    return Scaffold(
      backgroundColor: kc.bg,
      appBar: _pickerAppBar(context, book.title),
      body: GridView.builder(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 72,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
        ),
        itemCount: book.chapters.length,
        itemBuilder: (context, i) {
          final chapter = book.chapters[i];
          final selected =
              current?.usfm == book.usfm && current?.chapter == chapter;
          return Semantics(
            button: true,
            selected: selected,
            label: '${book.title} $chapter',
            excludeSemantics: true,
            child: Material(
              color: selected ? kc.chipBg : kc.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
                side: BorderSide(color: selected ? kc.onChip : kc.divider),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                key: Key('bible-chapter-$chapter'),
                onTap: () => Navigator.of(
                  context,
                ).pop(BibleLocation(book.usfm, chapter)),
                child: Center(
                  child: Text(
                    '$chapter',
                    style: AppTypography.ui(
                      size: 16,
                      weight: selected ? FontWeight.w700 : FontWeight.w600,
                    ).copyWith(color: selected ? kc.onChip : kc.onBg),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
