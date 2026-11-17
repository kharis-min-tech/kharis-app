import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kharis_app/features/bible/presentation/reader_layout_provider.dart';
import 'package:kharis_app/shared/providers/text_size_provider.dart';
import 'package:kharis_app/shared/providers/verse_marks_provider.dart';
import 'package:kharis_app/ui/components/components.dart';

/// Where a row of the study tools leads; the reader opens it once the sheet
/// has closed.
enum StudyTool {
  /// Go to a passage by reference ("John 3:16").
  search,

  /// The highlighted verses.
  highlights,

  /// The notes on verses.
  notes,
}

/// The reader's study tools in one short sheet: Go to a passage,
/// Highlights and My notes, then the layout and the text size, which apply
/// at once and leave the sheet open. Resolves to the row chosen, or null.
Future<StudyTool?> showStudyTools(BuildContext context) =>
    showKBottomSheet<StudyTool>(
      context: context,
      title: 'Study tools',
      builder: (_) => const StudyToolsSheet(),
    );

class StudyToolsSheet extends ConsumerWidget {
  const StudyToolsSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final k = context.k;
    final highlights = ref.watch(verseHighlightCountProvider);
    final notes = ref.watch(verseNoteCountProvider);
    final layout = ref.watch(readerLayoutProvider);
    final textSize = ref.watch(textSizeProvider);

    void open(StudyTool tool) => Navigator.of(context).pop(tool);

    Widget label(String text) => Padding(
      padding: const EdgeInsets.only(bottom: KSpace.md),
      child: Semantics(
        header: true,
        child: Text(text, style: KharisText.itemTitle.copyWith(color: k.text)),
      ),
    );

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          KListGroup(
            children: [
              KListRow(
                key: const Key('bible-search'),
                leading: const KIconTile(KIcons.search),
                title: 'Go to a passage',
                meta: 'John 3:16, Psalm 23',
                showChevron: true,
                onTap: () => open(StudyTool.search),
              ),
              KListRow(
                key: const Key('bible-study-highlights'),
                leading: const KIconTile(KIcons.pen),
                title: 'Highlights',
                meta: '$highlights saved',
                showChevron: true,
                onTap: () => open(StudyTool.highlights),
              ),
              KListRow(
                key: const Key('bible-study-notes'),
                leading: const KIconTile(KIcons.note),
                title: 'My notes',
                meta: notes == 1 ? '1 note' : '$notes notes',
                showChevron: true,
                onTap: () => open(StudyTool.notes),
              ),
            ],
          ),
          const SizedBox(height: KSpace.md),
          Text(
            'Tap a verse to highlight it, add a note, copy or share it.',
            style: KharisText.caption.copyWith(color: k.muted),
          ),
          const SizedBox(height: KSpace.gutter),
          label('Layout'),
          KSegmentedControl(
            segments: [
              for (final (option, name) in const [
                (KReaderLayout.verses, 'Verse by verse'),
                (KReaderLayout.paragraphs, 'Paragraphs'),
              ])
                KSegment(
                  key: Key('reader-layout-${option.name}'),
                  label: name,
                  semanticLabel: name,
                  selected: layout == option,
                  onTap: () => unawaited(
                    ref.read(readerLayoutProvider.notifier).select(option),
                  ),
                ),
            ],
          ),
          const SizedBox(height: KSpace.gutter),
          label('Text size'),
          KSegmentedControl(
            segments: [
              for (final choice in TextSizeChoice.values)
                KSegment(
                  key: Key('reader-text-size-${choice.name}'),
                  label: choice.label,
                  semanticLabel: 'Text size ${choice.label}',
                  selected: textSize == choice,
                  onTap: () => unawaited(
                    ref.read(textSizeProvider.notifier).set(choice),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
