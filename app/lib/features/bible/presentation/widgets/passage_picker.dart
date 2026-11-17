import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kharis_app/core/constants/bible_books.dart';
import 'package:kharis_app/features/home/data/bible_repository.dart';
import 'package:kharis_app/shared/providers/bible_provider.dart';
import 'package:kharis_app/ui/components/components.dart';

/// The passage picker: one sheet in two steps. Books (Old or New Testament,
/// or found by name) as a compact grid, then the chosen book's chapters.
/// With a [current] place it opens on that book's chapters, one tap from the
/// books. Resolves to the chosen chapter, or null when the member closes it.
Future<BibleLocation?> showPassagePicker(
  BuildContext context, {
  BibleLocation? current,
}) => showKBottomSheet<BibleLocation>(
  context: context,
  builder: (_) => PassagePicker(current: current),
);

class PassagePicker extends ConsumerStatefulWidget {
  const PassagePicker({super.key, this.current});

  /// Where the reader is; its book and chapter are marked.
  final BibleLocation? current;

  @override
  ConsumerState<PassagePicker> createState() => _PassagePickerState();
}

class _PassagePickerState extends ConsumerState<PassagePicker> {
  final _filter = TextEditingController();

  /// Counts step changes, so a step shown again while its last showing
  /// still fades out is a new child.
  var _visit = 0;

  /// The book whose chapters are shown; null on the books step.
  late String? _usfm = widget.current?.usfm;

  /// The testament whose books are shown; null until one is chosen, when it
  /// follows the open book.
  Testament? _testament;

  /// The book name typed into Find a book.
  String _query = '';

  @override
  void dispose() {
    _filter.dispose();
    super.dispose();
  }

  void _chooseBook(BibleBook book) {
    // A book with one chapter has nothing more to choose.
    if (book.chapters.length == 1) {
      Navigator.of(context).pop(BibleLocation(book.usfm, book.chapters.single));
      return;
    }
    FocusScope.of(context).unfocus();
    _filter.clear();
    setState(() {
      _usfm = book.usfm;
      _testament = book.testament;
      _query = '';
      _visit++;
    });
  }

  void _backToBooks(BibleBook book) => setState(() {
    _usfm = null;
    _testament = book.testament;
    _visit++;
  });

  /// Books whose name has [_query] in it, spaces ignored ("1cor").
  List<BibleBook> _matches(BibleIndex index) {
    String fold(String s) => s.toLowerCase().replaceAll(' ', '');
    final query = fold(_query);
    return [
      for (final b in index.books)
        if (fold(b.title).contains(query)) b,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final version = ref.watch(selectedBibleProvider);
    // The version's own list once it has loaded, the bundled 66-book table
    // until then, so a slow connection never leaves a spinner here.
    final index =
        ref.watch(bibleIndexProvider(version.id)).valueOrNull ??
        BibleIndex.bundled();
    final book = _usfm == null ? null : index.book(_usfm!);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    final Widget step = book == null
        ? _BooksStep(
            key: ValueKey(_visit),
            index: index,
            testament: _testament,
            selected: widget.current?.usfm,
            query: _query,
            filter: _filter,
            matches: _query.trim().isEmpty ? null : _matches(index),
            onTestament: (t) => setState(() => _testament = t),
            onQuery: (q) => setState(() => _query = q),
            onBook: _chooseBook,
          )
        : _ChaptersStep(
            key: ValueKey(_visit),
            book: book,
            selected: widget.current?.usfm == book.usfm
                ? widget.current?.chapter
                : null,
            onBack: () => _backToBooks(book),
          );

    return Padding(
      // Find a book stays above the keyboard.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: AnimatedSwitcher(
        duration: reduceMotion ? Duration.zero : KMotion.fast,
        // Books come from the left, chapters from the right.
        transitionBuilder: (child, animation) {
          final fromLeft = child is _BooksStep;
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween(
                begin: Offset(fromLeft ? -_slide : _slide, 0),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          );
        },
        layoutBuilder: (current, previous) => Stack(
          alignment: Alignment.topCenter,
          children: [...previous, ?current],
        ),
        child: step,
      ),
    );
  }

  /// How far a step slides in, as a share of its width.
  static const double _slide = 0.08;
}

/// The sheet's top row: the step's title (with Books on the chapters step)
/// and Done.
class _Header extends StatelessWidget {
  const _Header({required this.title, this.onBack});

  final String title;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final onBack = this.onBack;

    return Row(
      children: [
        if (onBack != null) ...[
          Semantics(
            button: true,
            label: 'Back to books',
            onTap: onBack,
            excludeSemantics: true,
            child: InkWell(
              key: const Key('passage-picker-books'),
              onTap: onBack,
              borderRadius: const BorderRadius.all(
                Radius.circular(KRadius.chip),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minWidth: KSize.touchMin,
                  minHeight: KSize.touchMin,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    KIcon(
                      KIcons.chevronLeft,
                      size: KSize.iconSm,
                      color: k.primaryText,
                    ),
                    const SizedBox(width: KSpace.xs),
                    Text(
                      'Books',
                      style: KharisText.link.copyWith(color: k.primaryText),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: KSpace.xl),
        ],
        Expanded(
          child: Semantics(
            header: true,
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: KharisText.section.copyWith(color: k.text),
            ),
          ),
        ),
        const SizedBox(width: KSpace.xl),
        KButton(
          key: const Key('passage-picker-done'),
          label: 'Done',
          variant: KButtonVariant.inverse,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

/// Step one: the testaments, Find a book and the books as a grid.
class _BooksStep extends StatelessWidget {
  const _BooksStep({
    super.key,
    required this.index,
    required this.testament,
    required this.selected,
    required this.query,
    required this.filter,
    required this.matches,
    required this.onTestament,
    required this.onQuery,
    required this.onBook,
  });

  final BibleIndex index;

  /// The testament chosen; null follows [selected], then the first.
  final Testament? testament;

  /// The open book, marked.
  final String? selected;
  final String query;
  final TextEditingController filter;

  /// Books matching [query]; null when nothing is typed.
  final List<BibleBook>? matches;
  final ValueChanged<Testament> onTestament;
  final ValueChanged<String> onQuery;
  final ValueChanged<BibleBook> onBook;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final testaments = [
      for (final t in Testament.values)
        if (index.books.any((b) => b.testament == t)) t,
    ];
    final open = selected == null ? null : index.book(selected!);
    final shown = testaments.contains(testament)
        ? testament!
        : testaments.contains(open?.testament)
        ? open!.testament
        : testaments.first;
    final matches = this.matches;
    final books =
        matches ??
        [
          for (final b in index.books)
            if (b.testament == shown) b,
        ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const _Header(title: 'Choose a book'),
        const SizedBox(height: KSpace.x3),
        if (testaments.length > 1) ...[
          KSegmentedControl(
            segments: [
              for (final t in testaments)
                KSegment(
                  key: Key('bible-testament-${t.name}'),
                  label: t == Testament.old ? 'Old Testament' : 'New Testament',
                  semanticLabel: t == Testament.old
                      ? 'Old Testament'
                      : 'New Testament',
                  selected: matches == null && t == shown,
                  onTap: () {
                    if (matches != null) {
                      filter.clear();
                      onQuery('');
                    }
                    onTestament(t);
                  },
                ),
            ],
          ),
          const SizedBox(height: KSpace.md),
        ],
        KSearchField(
          key: const Key('bible-book-filter'),
          hint: 'Find a book',
          controller: filter,
          onChanged: onQuery,
          onSubmitted: (_) {
            if (books.length == 1) onBook(books.single);
          },
        ),
        const SizedBox(height: KSpace.xl),
        Flexible(
          child: SingleChildScrollView(
            child: books.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: KSpace.x3),
                    child: Text(
                      'No book called \u201c${query.trim()}\u201d',
                      textAlign: TextAlign.center,
                      style: KharisText.meta.copyWith(color: k.muted),
                    ),
                  )
                : KBookGrid(
                    key: const Key('bible-books'),
                    books: [
                      for (final b in books) (id: b.usfm, label: b.title),
                    ],
                    selected: selected,
                    onSelected: (usfm) => onBook(index.book(usfm)!),
                  ),
          ),
        ),
      ],
    );
  }
}

/// Step two: Books, the book's name and its chapters, scrolled to the open
/// chapter (Psalm 119 sits far down).
class _ChaptersStep extends StatefulWidget {
  const _ChaptersStep({
    super.key,
    required this.book,
    required this.selected,
    required this.onBack,
  });

  final BibleBook book;
  final int? selected;
  final VoidCallback onBack;

  @override
  State<_ChaptersStep> createState() => _ChaptersStepState();
}

class _ChaptersStepState extends State<_ChaptersStep> {
  final _selected = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _selected.currentContext;
      if (target == null || !target.mounted) return;
      Scrollable.ensureVisible(target, alignment: 0.5);
    });
  }

  @override
  Widget build(BuildContext context) {
    final book = widget.book;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _Header(title: book.title, onBack: widget.onBack),
        const SizedBox(height: KSpace.x3),
        Flexible(
          child: SingleChildScrollView(
            child: KChapterGrid(
              key: const Key('bible-chapters'),
              book: book.title,
              chapters: book.chapters,
              selected: widget.selected,
              selectedKey: _selected,
              onSelected: (chapter) =>
                  Navigator.of(context).pop(BibleLocation(book.usfm, chapter)),
            ),
          ),
        ),
      ],
    );
  }
}
