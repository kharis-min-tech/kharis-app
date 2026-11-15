import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kharis_app/core/constants/bible_books.dart';
import 'package:kharis_app/features/home/data/bible_repository.dart';
import 'package:kharis_app/shared/providers/bible_provider.dart';
import 'package:kharis_app/ui/components/components.dart';

/// The passage picker: one sheet with the books (Old or New Testament), the
/// chosen book's chapters and the Bible versions. Resolves to the chosen
/// chapter, or null when the member closes it. Choosing a version changes
/// the reading version at once and leaves the sheet open.
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
  final _chaptersKey = GlobalKey();

  /// The book whose chapters are shown.
  late String? _usfm = widget.current?.usfm;

  /// The testament whose books are shown; null until one is chosen, when it
  /// follows [_usfm].
  Testament? _testament;

  BibleIndex get _index =>
      ref.read(bibleIndexProvider(ref.read(selectedBibleProvider).id))
          .valueOrNull ??
      BibleIndex.bundled();

  void _chooseBook(BibleBook book) {
    // A book with one chapter has nothing more to choose.
    if (book.chapters.length == 1) {
      Navigator.of(context).pop(BibleLocation(book.usfm, book.chapters.single));
      return;
    }
    setState(() => _usfm = book.usfm);
    // The chapters sit below the books: bring them into view.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _chaptersKey.currentContext;
      if (target == null || !target.mounted) return;
      Scrollable.ensureVisible(
        target,
        duration: MediaQuery.disableAnimationsOf(target)
            ? Duration.zero
            : KMotion.fast,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final version = ref.watch(selectedBibleProvider);
    // The version's own list once it has loaded, the bundled 66-book table
    // until then, so a slow connection never leaves a spinner here.
    final index =
        ref.watch(bibleIndexProvider(version.id)).valueOrNull ??
        BibleIndex.bundled();
    final book = _usfm == null ? null : index.book(_usfm!);
    final testaments = [
      for (final t in Testament.values)
        if (index.books.any((b) => b.testament == t)) t,
    ];
    final testament = testaments.contains(_testament)
        ? _testament!
        : testaments.contains(book?.testament)
        ? book!.testament
        : testaments.first;
    final current = widget.current;

    Widget heading(String text) => Semantics(
      header: true,
      child: Text(text, style: KharisText.itemTitle.copyWith(color: k.text)),
    );

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    current == null
                        ? 'Choose a passage'
                        : index.label(current.wholeChapter),
                    maxLines: 2,
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
          ),
          const SizedBox(height: KSpace.x3),
          heading('Book'),
          if (testaments.length > 1) ...[
            const SizedBox(height: KSpace.md),
            Wrap(
              spacing: KSpace.md,
              runSpacing: KSpace.md,
              children: [
                for (final t in testaments)
                  KChip(
                    key: Key('bible-testament-${t.name}'),
                    label: t == Testament.old
                        ? 'Old Testament'
                        : 'New Testament',
                    selected: t == testament,
                    onTap: () => setState(() => _testament = t),
                  ),
              ],
            ),
          ],
          const SizedBox(height: KSpace.xl),
          Wrap(
            key: const Key('bible-books'),
            spacing: KSpace.sm,
            runSpacing: KSpace.sm,
            children: [
              for (final b in index.books)
                if (b.testament == testament)
                  KChip(
                    key: Key('bible-book-${b.usfm}'),
                    label: b.title,
                    selected: b.usfm == _usfm,
                    onTap: () => _chooseBook(b),
                  ),
            ],
          ),
          if (book != null) ...[
            const SizedBox(height: KSpace.gutter),
            KeyedSubtree(key: _chaptersKey, child: heading('Chapter')),
            const SizedBox(height: KSpace.md),
            KChapterGrid(
              book: book.title,
              chapters: book.chapters,
              selected: current?.usfm == book.usfm ? current?.chapter : null,
              onSelected: (chapter) =>
                  Navigator.of(context).pop(BibleLocation(book.usfm, chapter)),
            ),
          ],
          const SizedBox(height: KSpace.gutter),
          heading('Version'),
          const SizedBox(height: KSpace.md),
          _Versions(selected: version),
        ],
      ),
    );
  }
}

/// The approved versions the account returns, as option cards.
class _Versions extends ConsumerWidget {
  const _Versions({required this.selected});

  final BibleVersion selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(biblesProvider)
        .when(
          loading: () => const Column(
            key: Key('bible-versions-loading'),
            mainAxisSize: MainAxisSize.min,
            children: [
              KSkeleton(height: KSize.listRow, radius: KRadius.card),
              SizedBox(height: KSpace.md),
              KSkeleton(height: KSize.listRow, radius: KRadius.card),
            ],
          ),
          error: (_, _) => KErrorState(
            message:
                'The versions didn\u2019t load. '
                'Check your connection and retry.',
            onRetry: () => ref.invalidate(biblesProvider),
          ),
          data: (bibles) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final (i, b) in bibles.indexed) ...[
                if (i > 0) const SizedBox(height: KSpace.md),
                KOptionCard(
                  key: Key('bible-version-${b.id}'),
                  title: b.abbreviation,
                  meta: b.title.isEmpty ? null : b.title,
                  selected: b.id == selected.id,
                  onTap: () => unawaited(
                    ref.read(selectedBibleProvider.notifier).select(b),
                  ),
                ),
              ],
            ],
          ),
        );
  }
}
