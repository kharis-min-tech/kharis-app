import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kharis_app/features/bible/presentation/reader_layout_provider.dart';
import 'package:kharis_app/features/bible/presentation/widgets/passage_picker.dart';
import 'package:kharis_app/features/bible/presentation/widgets/reference_search.dart';
import 'package:kharis_app/features/bible/presentation/widgets/verse_sheet.dart';
import 'package:kharis_app/features/home/data/bible_reference.dart';
import 'package:kharis_app/features/home/data/bible_repository.dart';
import 'package:kharis_app/features/home/data/daily_content_repository.dart';
import 'package:kharis_app/features/player/presentation/playback_launcher.dart';
import 'package:kharis_app/shared/providers/bible_provider.dart';
import 'package:kharis_app/shared/providers/last_read_provider.dart';
import 'package:kharis_app/shared/providers/related_messages_provider.dart';
import 'package:kharis_app/shared/providers/sermon_provider.dart';
import 'package:kharis_app/shared/providers/streaks_provider.dart';
import 'package:kharis_app/shared/providers/verse_marks_provider.dart';
import 'package:kharis_app/ui/components/components.dart';

/// The passages today's reading names, in order ("Romans 8:1-11; Psalm 23"
/// is two); empty when it has none or none parse.
List<BibleLocation> todayLocations(DailyEntry? reading, BibleIndex index) {
  final reference = reading?.reference ?? '';
  if (reference.isEmpty) return const [];
  return parseReadingReferences(reference, index);
}

/// The Bible reader (`/bible/:book/:chapter`, and `/bible/reading` for
/// today's reading).
///
/// With a [location] it opens that chapter, scrolled to and marking its
/// verses when it names some. Without one it opens today's reading, with a
/// switcher when the reading names several passages and Mark as read at the
/// end of the last. Previous and next, the passage picker and the search
/// move through the Bible from there; while away from today's reading a
/// "Today's reading" chip leads back.
class ReadingScreen extends ConsumerStatefulWidget {
  const ReadingScreen({super.key, this.location, this.openVerse = false});

  /// The chapter to open; null opens today's reading.
  final BibleLocation? location;

  /// Opens the verse sheet on [location]'s first verse once it has loaded
  /// (My notes opens a note this way).
  final bool openVerse;

  @override
  ConsumerState<ReadingScreen> createState() => _ReadingScreenState();
}

class _ReadingScreenState extends ConsumerState<ReadingScreen> {
  /// The chapter being read away from today's reading; null while on it.
  late BibleLocation? _browsing = widget.location;

  /// Which of today's passages is open, when the reading names several.
  int _todayPart = 0;

  bool get _todayMode => widget.location == null;

  BibleIndex _index() =>
      ref
          .read(bibleIndexProvider(ref.read(selectedBibleProvider).id))
          .valueOrNull ??
      BibleIndex.bundled();

  BibleLocation? _todayOf(List<BibleLocation> parts) =>
      parts.isEmpty ? null : parts[_todayPart.clamp(0, parts.length - 1)];

  void _go(BibleLocation to) {
    final today = _todayMode
        ? _todayOf(
            todayLocations(
              ref.read(dailyContentProvider).valueOrNull?.reading,
              _index(),
            ),
          )
        : null;
    setState(() {
      // Landing on today's chapter (without a verse) is today's reading.
      final isToday =
          today != null &&
          (to == today || (to.sameChapter(today) && to.verseStart == null));
      _browsing = isToday ? null : to;
    });
  }

  Future<void> _pickPassage(BibleLocation? current) async {
    final picked = await showPassagePicker(context, current: current);
    if (picked != null && mounted) _go(picked);
  }

  Future<void> _search() async {
    final picked = await showReferenceSearch(context);
    if (picked != null && mounted) _go(picked);
  }

  @override
  Widget build(BuildContext context) {
    final browsing = _browsing;
    final Widget body;
    if (browsing != null) {
      body = _PassageView(
        key: ValueKey('browse-$browsing'),
        location: browsing,
        openVerse: widget.openVerse && browsing == widget.location,
        onNavigate: _go,
        onPickPassage: () => _pickPassage(browsing.wholeChapter),
        onSearch: _search,
        onToday: _todayMode ? () => setState(() => _browsing = null) : null,
      );
    } else {
      body = _TodayView(
        part: _todayPart,
        onPart: (i) => setState(() => _todayPart = i),
        onNavigate: _go,
        onPickPassage: _pickPassage,
        onSearch: _search,
      );
    }
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: KSize.maxContentWidth),
            child: body,
          ),
        ),
      ),
    );
  }
}

/// Today's reading: the passage, or why there is none.
class _TodayView extends ConsumerWidget {
  const _TodayView({
    required this.part,
    required this.onPart,
    required this.onNavigate,
    required this.onPickPassage,
    required this.onSearch,
  });

  final int part;
  final ValueChanged<int> onPart;
  final ValueChanged<BibleLocation> onNavigate;
  final ValueChanged<BibleLocation?> onPickPassage;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final version = ref.watch(selectedBibleProvider);
    final index =
        ref.watch(bibleIndexProvider(version.id)).valueOrNull ??
        BibleIndex.bundled();

    Widget bare(Widget child) => _ReaderFrame(
      toolbar: _Toolbar(
        passage: 'Today\u2019s reading',
        onPassage: () => onPickPassage(null),
        onSearch: onSearch,
      ),
      child: child,
    );

    return ref
        .watch(dailyContentProvider)
        .when(
          loading: () => bare(const _PassageSkeleton()),
          error: (_, _) => bare(
            KErrorState(
              message:
                  'Today\u2019s reading didn\u2019t load. '
                  'Check your connection and retry.',
              onRetry: () => ref.invalidate(dailyContentProvider),
            ),
          ),
          data: (content) {
            if (content == null) {
              return bare(
                KEmptyState(
                  icon: KIcons.bookOpen,
                  title: 'No reading today',
                  hint: 'Today\u2019s reading hasn\u2019t been published yet.',
                  action: KButton(
                    label: 'Choose a passage',
                    variant: KButtonVariant.outline,
                    onPressed: () => onPickPassage(null),
                  ),
                ),
              );
            }
            final parts = todayLocations(content.reading, index);
            if (parts.isEmpty) {
              // No reference to open (or one that does not parse): the
              // Studio's own words, and the way into the Bible.
              return bare(
                _TodayText(
                  reading: content.reading,
                  prayer: content.prayer,
                  onChoose: () => onPickPassage(null),
                ),
              );
            }
            final selected = part.clamp(0, parts.length - 1);
            final location = parts[selected];
            return _PassageView(
              key: ValueKey('today-${location.passageId}'),
              location: location,
              today: (
                parts: [for (final p in parts) index.label(p)],
                selected: selected,
                onPart: onPart,
                isLast: selected == parts.length - 1,
                reading: content.reading,
                prayer: content.prayer,
              ),
              onNavigate: onNavigate,
              onPickPassage: () => onPickPassage(location.wholeChapter),
              onSearch: onSearch,
            );
          },
        );
  }
}

/// What the reader shows around today's passage.
typedef _Today = ({
  List<String> parts,
  int selected,
  ValueChanged<int> onPart,
  bool isLast,
  DailyEntry? reading,
  DailyEntry? prayer,
});

/// The toolbar above the page, and the page scrolling under it.
class _ReaderFrame extends StatelessWidget {
  const _ReaderFrame({required this.toolbar, required this.child});

  final Widget toolbar;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            KSpace.readerGutter,
            KSpace.md,
            KSpace.readerGutter,
            KSpace.md,
          ),
          child: toolbar,
        ),
        Expanded(child: child),
      ],
    );
  }
}

/// The reader toolbar with the remembered layout.
class _Toolbar extends ConsumerWidget {
  const _Toolbar({
    required this.passage,
    required this.onPassage,
    required this.onSearch,
  });

  final String passage;
  final VoidCallback onPassage;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return KReaderToolbar(
      key: const Key('bible-toolbar'),
      layout: ref.watch(readerLayoutProvider),
      onLayoutChanged: (layout) =>
          unawaited(ref.read(readerLayoutProvider.notifier).select(layout)),
      passage: passage,
      version: ref.watch(selectedBibleProvider).abbreviation,
      onSearch: onSearch,
      onPassage: onPassage,
    );
  }
}

/// One chapter: the toolbar, the chapter title, the verses with their
/// highlights and related-message markers, the copyright, today's notes and
/// Mark as read, then previous / next.
class _PassageView extends ConsumerStatefulWidget {
  const _PassageView({
    super.key,
    required this.location,
    required this.onNavigate,
    required this.onPickPassage,
    required this.onSearch,
    this.openVerse = false,
    this.onToday,
    this.today,
  });

  final BibleLocation location;
  final ValueChanged<BibleLocation> onNavigate;
  final VoidCallback onPickPassage;
  final VoidCallback onSearch;
  final bool openVerse;

  /// Returns to today's reading; shown while away from it.
  final VoidCallback? onToday;

  /// Set while this is today's reading.
  final _Today? today;

  @override
  ConsumerState<_PassageView> createState() => _PassageViewState();
}

class _PassageViewState extends ConsumerState<_PassageView> {
  final _verseKey = GlobalKey();

  /// The verse selection already scrolled to, so rebuilds do not jump again.
  BibleLocation? _revealed;

  /// The chapter and version last recorded as read.
  String? _saved;

  bool _verseOpened = false;

  void _afterLoad(BibleLocation location, BibleVersion version) {
    final saveKey = '${location.passageId}/${version.id}';
    final reveal = location.verseStart != null && _revealed != location;
    final open = widget.openVerse && !_verseOpened;
    if (_saved == saveKey && !reveal && !open) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_saved != saveKey) {
        _saved = saveKey;
        unawaited(
          ref
              .read(lastReadProvider.notifier)
              .save(location.wholeChapter, version),
        );
      }
      if (reveal) {
        _revealed = location;
        final target = _verseKey.currentContext;
        if (target != null && target.mounted) {
          unawaited(
            Scrollable.ensureVisible(
              target,
              alignment: 0.1,
              duration: MediaQuery.disableAnimationsOf(target)
                  ? Duration.zero
                  : KMotion.fast,
            ),
          );
        }
      }
      if (open) {
        _verseOpened = true;
        final verse = location.verseStart;
        final text = _verseTexts[verse];
        if (verse != null && text != null) _openVerse(verse, text);
      }
    });
  }

  /// Each verse's words in the open chapter, for the verse sheet.
  Map<int, String> _verseTexts = const {};

  void _openVerse(int verse, String text) {
    final location = widget.location;
    final version = ref.read(selectedBibleProvider);
    final index =
        ref.read(bibleIndexProvider(version.id)).valueOrNull ??
        BibleIndex.bundled();
    unawaited(
      showVerseSheet(
        context,
        verse: VerseRef(location.usfm, location.chapter, verse),
        reference: index.label(
          BibleLocation(
            location.usfm,
            location.chapter,
            verseStart: verse,
            verseEnd: verse,
          ),
        ),
        text: text,
        version: version.abbreviation,
        onPlayMessage: (message, queue) {
          if (!mounted) return;
          unawaited(startPlayback(context, ref, message, queue: queue));
        },
      ),
    );
  }

  void _openFootnote(String letter, String note) {
    unawaited(
      showKBottomSheet<void>(
        context: context,
        title: 'Footnote $letter',
        builder: (sheetContext) => Text(
          note,
          key: const Key('bible-note-text'),
          style: KharisText.reading.copyWith(color: sheetContext.k.text),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final location = widget.location;
    final version = ref.watch(selectedBibleProvider);
    final index =
        ref.watch(bibleIndexProvider(version.id)).valueOrNull ??
        BibleIndex.bundled();
    final chapterLabel = index.label(location.wholeChapter);
    final passageKey = (
      usfm: location.passageId,
      bibleId: version.id,
      abbrev: version.abbreviation,
    );
    final today = widget.today;
    final onToday = widget.onToday;

    final top = <Widget>[
      if (today != null && today.parts.length > 1) ...[
        KChipRow(
          key: const Key('reading-parts'),
          children: [
            for (final (i, label) in today.parts.indexed)
              KChip(
                key: Key('reading-part-$i'),
                label: label,
                selected: i == today.selected,
                onTap: () => today.onPart(i),
              ),
          ],
        ),
        const SizedBox(height: KSpace.lg),
      ],
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: KSpace.readerGutter),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (today != null)
              const KOverline('Today\u2019s reading')
            else if (onToday != null)
              KChip(
                key: const Key('bible-today'),
                label: 'Today\u2019s reading',
                leading: KIcons.calendar,
                onTap: onToday,
              ),
            const SizedBox(height: KSpace.xs),
            Semantics(
              header: true,
              child: Text(
                chapterLabel,
                key: const Key('bible-chapter-title'),
                style: KharisText.pageTitle.copyWith(color: k.text),
              ),
            ),
          ],
        ),
      ),
    ];

    Widget page(List<Widget> children) => _ReaderFrame(
      toolbar: _Toolbar(
        passage: chapterLabel,
        onPassage: widget.onPickPassage,
        onSearch: widget.onSearch,
      ),
      child: SingleChildScrollView(
        key: PageStorageKey('bible-${location.passageId}'),
        padding: const EdgeInsets.only(bottom: KSize.readerBottomPad),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [...top, ...children],
        ),
      ),
    );

    Widget padded(Widget child) => Padding(
      padding: const EdgeInsets.fromLTRB(
        KSpace.readerGutter,
        KSpace.x3,
        KSpace.readerGutter,
        0,
      ),
      child: child,
    );

    return ref
        .watch(passageProvider(passageKey))
        .when(
          loading: () => page([padded(const _PassageSkeleton())]),
          error: (error, _) {
            final notFound =
                error is DioException && error.response?.statusCode == 404;
            if (notFound) {
              return page([
                padded(
                  KEmptyState(
                    icon: KIcons.bookOpen,
                    title: 'This passage isn\u2019t available',
                    hint:
                        '$chapterLabel isn\u2019t in ${version.abbreviation}. '
                        'Choose another version.',
                    action: KButton(
                      key: const Key('bible-change-version'),
                      label: 'Change version',
                      variant: KButtonVariant.outline,
                      onPressed: widget.onPickPassage,
                    ),
                  ),
                ),
              ]);
            }
            return page([
              padded(
                KErrorState(
                  message:
                      '$chapterLabel didn\u2019t load. '
                      'Check your connection and retry.',
                  onRetry: () {
                    ref.invalidate(passageProvider(passageKey));
                    if (index.isFallback) {
                      ref.invalidate(bibleIndexProvider(version.id));
                    }
                  },
                ),
              ),
            ]);
          },
          data: (passage) {
            final previous = index.previous(location);
            final next = index.next(location);
            final body = _PassageBody(
              blocks: passage.blocks,
              location: location,
              layout: ref.watch(readerLayoutProvider),
              marks: ref.watch(
                chapterMarksProvider((
                  book: location.usfm,
                  chapter: location.chapter,
                )),
              ),
              related: ref.watch(
                relatedMessagesProvider((
                  book: location.usfm,
                  chapter: location.chapter,
                )),
              ),
              verseKey: _verseKey,
              onVerse: _openVerse,
              onFootnote: _openFootnote,
            );
            _verseTexts = body.verseTexts();
            _afterLoad(location, version);
            final copyright = passage.copyright;
            return page([
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  KSpace.readerGutter - KSpace.md,
                  KSpace.lg,
                  KSpace.readerGutter - KSpace.md,
                  0,
                ),
                child: body,
              ),
              if (copyright != null && copyright.isNotEmpty)
                padded(
                  Text(
                    copyright,
                    style: KharisText.small.copyWith(color: k.muted),
                  ),
                ),
              if (today != null) ...[
                if (today.reading case final reading?
                    when reading.body.isNotEmpty)
                  padded(
                    _EntryCard(
                      key: const Key('reading-note'),
                      overline: 'Daily reading',
                      entry: reading,
                      showReference: false,
                    ),
                  ),
                if (today.prayer case final prayer?)
                  padded(_EntryCard(overline: 'Daily prayer', entry: prayer)),
                if (today.isLast) padded(const _MarkRead()),
              ],
              padded(
                KChapterNav(
                  key: const Key('bible-chapter-nav'),
                  label: 'End of $chapterLabel',
                  previousLabel: previous == null
                      ? null
                      : index.label(previous),
                  nextLabel: next == null ? null : index.label(next),
                  onPrevious: previous == null
                      ? null
                      : () => widget.onNavigate(previous),
                  onNext: next == null ? null : () => widget.onNavigate(next),
                ),
              ),
            ]);
          },
        );
  }
}

/// Grey blocks in the shape of a chapter, while it loads.
class _PassageSkeleton extends StatelessWidget {
  const _PassageSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const Key('bible-loading'),
      padding: const EdgeInsets.symmetric(horizontal: KSpace.readerGutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < 6; i++) ...[
            const KSkeleton(height: KSpace.x3, radius: KRadius.xs),
            const SizedBox(height: KSpace.md),
            const KSkeleton(height: KSpace.x3, radius: KRadius.xs),
            const SizedBox(height: KSpace.md),
            const FractionallySizedBox(
              widthFactor: 0.6,
              child: KSkeleton(height: KSpace.x3, radius: KRadius.xs),
            ),
            const SizedBox(height: KSpace.xxl),
          ],
        ],
      ),
    );
  }
}

/// The chapter's text as [KVerse]s: one verse per line, or the
/// translation's paragraphs, with section headings, highlights, the
/// searched verses marked and the related-message markers.
class _PassageBody extends StatelessWidget {
  const _PassageBody({
    required this.blocks,
    required this.location,
    required this.layout,
    required this.marks,
    required this.related,
    required this.verseKey,
    required this.onVerse,
    required this.onFootnote,
  });

  final List<PassageBlock> blocks;
  final BibleLocation location;
  final KReaderLayout layout;
  final ChapterMarks marks;
  final RelatedMessages related;
  final GlobalKey verseKey;
  final void Function(int verse, String text) onVerse;
  final void Function(String letter, String note) onFootnote;

  /// Each verse's words, joined across paragraphs.
  Map<int, String> verseTexts() {
    final texts = <int, StringBuffer>{};
    int? verse;
    for (final block in blocks) {
      if (block.isHeading || block.isSuperscription) continue;
      for (final seg in block.segments) {
        verse = seg.verse ?? verse;
        if (verse == null) continue;
        (texts[verse] ??= StringBuffer())
          ..write(seg.text)
          ..write(' ');
      }
    }
    return {
      for (final e in texts.entries)
        e.key: e.value.toString().replaceAll(RegExp(r'\s+'), ' ').trim(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final texts = verseTexts();

    // Where each verse's last piece is, for the related-message marker.
    final lastPiece = <int, (int, int)>{};
    {
      int? verse;
      for (final (b, block) in blocks.indexed) {
        if (block.isHeading || block.isSuperscription) continue;
        for (final (s, seg) in block.segments.indexed) {
          verse = seg.verse ?? verse;
          if (verse != null) lastPiece[verse] = (b, s);
        }
      }
    }

    final start = location.verseStart;
    final end = location.verseEnd ?? start;
    bool marked(int? verse) =>
        start != null && verse != null && verse >= start && verse <= end!;

    var noteCount = 0;
    int? verse;
    var revealPlaced = false;
    final children = <Widget>[];
    List<KVersePart>? group;
    var groupIndent = 0;
    var groupDense = false;
    var groupReveals = false;

    void flush() {
      final parts = group;
      if (parts == null || parts.isEmpty) return;
      final block = KVerse(
        parts: parts,
        indent: groupIndent,
        dense: groupDense,
      );
      children.add(
        groupReveals ? KeyedSubtree(key: verseKey, child: block) : block,
      );
      group = null;
      groupReveals = false;
    }

    for (final (b, block) in blocks.indexed) {
      if (block.isHeading) {
        flush();
        children.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(
              KSpace.md,
              KSpace.xxl,
              KSpace.md,
              KSpace.sm,
            ),
            child: Semantics(
              header: true,
              child: Text(
                block.segments.map((s) => s.text).join(' '),
                style: KharisText.title.copyWith(color: k.text),
              ),
            ),
          ),
        );
        continue;
      }
      if (block.isSuperscription) {
        flush();
        children.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(
              KSpace.md,
              0,
              KSpace.md,
              KSpace.md,
            ),
            child: Text(
              block.segments.map((s) => s.text).join(' '),
              style: KharisText.body.copyWith(
                color: k.muted,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        );
        continue;
      }

      final poetry = block.styleClass.startsWith('q');
      if (layout == KReaderLayout.paragraphs) {
        flush();
        group = [];
        groupIndent = block.poetryIndent;
        groupDense = poetry;
      }
      for (final (s, seg) in block.segments.indexed) {
        final number = seg.verse;
        if (number != null) {
          verse = number;
          if (layout == KReaderLayout.verses) {
            flush();
            group = [];
            groupIndent = 0;
            groupDense = false;
          }
        }
        group ??= [];
        if (!revealPlaced && number != null && number == start) {
          revealPlaced = true;
          groupReveals = true;
        }
        final current = verse;
        final isLast = current != null && lastPiece[current] == (b, s);
        final text = seg.text.isEmpty
            ? ''
            : seg.notes.isEmpty
            ? '${seg.text} '
            : seg.text;
        group!.add(
          KVersePart(
            text: text,
            number: number,
            highlight: current == null
                ? null
                : marks.highlights[current]?.colour,
            marked: marked(current),
            related: isLast && related.has(current),
            onTap: current == null
                ? null
                : () => onVerse(current, texts[current] ?? ''),
            footnotes: [
              for (final note in seg.notes)
                () {
                  final letter = _noteLetter(noteCount++);
                  return KVerseFootnote(
                    letter: letter,
                    onTap: () => onFootnote(letter, note),
                  );
                }(),
            ],
          ),
        );
      }
    }
    flush();

    return Column(
      key: const Key('bible-text'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }
}

/// Footnote letters through a chapter: a…z, then aa, ab…
String _noteLetter(int i) => i < 26
    ? String.fromCharCode(97 + i)
    : '${_noteLetter(i ~/ 26 - 1)}${_noteLetter(i % 26)}';

/// Today's reading that has no passage to open: the Studio's title,
/// reference and text, the daily prayer, and the way into the Bible.
class _TodayText extends StatelessWidget {
  const _TodayText({
    required this.reading,
    required this.prayer,
    required this.onChoose,
  });

  final DailyEntry? reading;
  final DailyEntry? prayer;
  final VoidCallback onChoose;

  @override
  Widget build(BuildContext context) {
    final reading = this.reading;
    final prayer = this.prayer;
    return SingleChildScrollView(
      key: const Key('reading-today-text'),
      padding: const EdgeInsets.fromLTRB(
        KSpace.readerGutter,
        KSpace.md,
        KSpace.readerGutter,
        KSize.readerBottomPad,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (reading != null)
            _EntryCard(overline: 'Today\u2019s reading', entry: reading),
          if (prayer != null) ...[
            if (reading != null) const SizedBox(height: KSpace.x3),
            _EntryCard(overline: 'Daily prayer', entry: prayer),
          ],
          const SizedBox(height: KSpace.x3),
          KButton(
            label: 'Choose a passage',
            icon: KIcons.bookOpen,
            variant: KButtonVariant.outline,
            onPressed: onChoose,
          ),
          const SizedBox(height: KSpace.x3),
          const _MarkRead(),
        ],
      ),
    );
  }
}

/// One Studio entry (today's reading text or the daily prayer): its
/// overline, the title, the reference and the text.
class _EntryCard extends StatelessWidget {
  const _EntryCard({
    super.key,
    required this.overline,
    required this.entry,
    this.showReference = true,
  });

  final String overline;
  final DailyEntry entry;
  final bool showReference;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return KCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          KOverline(overline),
          const SizedBox(height: KSpace.md),
          Text(entry.title, style: KharisText.title.copyWith(color: k.text)),
          if (showReference && entry.reference.isNotEmpty) ...[
            const SizedBox(height: KSpace.xxs),
            Text(
              entry.reference,
              style: KharisText.meta.copyWith(color: k.muted),
            ),
          ],
          if (entry.body.isNotEmpty) ...[
            const SizedBox(height: KSpace.md),
            Text(entry.body, style: KharisText.reading.copyWith(color: k.text)),
          ],
        ],
      ),
    );
  }
}

/// Mark as read, at the end of today's last passage; "Read today" once it
/// is marked.
class _MarkRead extends ConsumerWidget {
  const _MarkRead();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final read = ref.watch(readTodayProvider);
    return KButton(
      key: const Key('reading-mark-read'),
      label: read ? 'Read today' : 'Mark as read',
      icon: KIcons.check,
      expand: true,
      variant: read ? KButtonVariant.outline : KButtonVariant.primary,
      onPressed: read
          ? null
          : () => ref.read(streakRepositoryProvider).markReadToday(),
    );
  }
}
