import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:kharis_app/features/bible/presentation/bible_routes.dart';
import 'package:kharis_app/features/bible/presentation/screens/reading_screen.dart';
import 'package:kharis_app/features/bible/presentation/widgets/passage_picker.dart';
import 'package:kharis_app/features/bible/presentation/widgets/reference_search.dart';
import 'package:kharis_app/features/bible/presentation/widgets/translation_sheet.dart';
import 'package:kharis_app/features/home/data/bible_reference.dart';
import 'package:kharis_app/features/home/data/bible_repository.dart';
import 'package:kharis_app/shared/providers/bible_provider.dart';
import 'package:kharis_app/shared/providers/last_read_provider.dart';
import 'package:kharis_app/shared/providers/sermon_provider.dart';
import 'package:kharis_app/shared/providers/streaks_provider.dart';
import 'package:kharis_app/shared/providers/verse_marks_provider.dart';
import 'package:kharis_app/ui/components/components.dart';

/// The church photo behind Continue reading.
const _continuePhoto = AssetImage('assets/hero/sunday-bible-raised.jpg');

/// The Bible tab (`/bible`): the translation switcher by the title, search
/// with the passage picker, Continue reading, today's Daily reading with the
/// week's dots, and the Highlights and My notes lists.
class BibleScreen extends ConsumerStatefulWidget {
  const BibleScreen({super.key});

  @override
  ConsumerState<BibleScreen> createState() => _BibleScreenState();
}

class _BibleScreenState extends ConsumerState<BibleScreen> {
  final _search = TextEditingController();
  String? _searchError;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _open(BibleLocation location) =>
      unawaited(context.push(bibleReaderPath(location)));

  void _submitSearch(String input) {
    if (input.trim().isEmpty) return;
    switch (lookUpReference(ref, input)) {
      case ReferenceFound(:final location):
        setState(() => _searchError = null);
        _search.clear();
        FocusScope.of(context).unfocus();
        _open(location);
      case ReferenceError(:final message):
        setState(() => _searchError = message);
    }
  }

  Future<void> _pickPassage() async {
    final last = ref.read(lastReadProvider);
    final picked = await showPassagePicker(context, current: last?.location);
    if (picked != null && mounted) _open(picked);
  }

  @override
  Widget build(BuildContext context) {
    final last = ref.watch(lastReadProvider);
    final error = _searchError;
    final highlights = ref.watch(verseHighlightCountProvider);
    final notes = ref.watch(verseNoteCountProvider);
    final version = ref.watch(selectedBibleProvider);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: KSize.maxContentWidth),
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(
                top: KSpace.md,
                bottom: KSize.contentBottomPad,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  KScreenHeader(
                    title: 'Bible',
                    actions: [
                      _TranslationChip(
                        version: version.abbreviation,
                        onTap: () => unawaited(showTranslationSheet(context)),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      KSpace.gutter,
                      KSpace.x3,
                      KSpace.gutter,
                      0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        KSearchField(
                          key: const Key('bible-landing-search'),
                          hint: 'Search a book, chapter or verse',
                          controller: _search,
                          onSubmitted: _submitSearch,
                          onChanged: (_) {
                            if (_searchError != null) {
                              setState(() => _searchError = null);
                            }
                          },
                          trailing: KIconButton(
                            key: const Key('bible-open-picker'),
                            icon: KIcons.bookOpen,
                            label: 'Choose a passage',
                            onPressed: _pickPassage,
                          ),
                        ),
                        if (error != null) ...[
                          const SizedBox(height: KSpace.md),
                          ReferenceSearchError(message: error),
                        ],
                        if (last != null) ...[
                          const SizedBox(height: KSpace.x3),
                          _ContinueReading(
                            last: last,
                            onOpen: () => _open(last.location),
                          ),
                        ],
                        const _DailyReading(),
                        const SizedBox(height: KSpace.x3),
                        KMoreTileGrid(
                          children: [
                            KMoreTile(
                              key: const Key('bible-highlights'),
                              icon: KIcons.pen,
                              title: 'Highlights',
                              meta: '$highlights saved',
                              onTap: () => context.push(kHighlightsPath),
                            ),
                            KMoreTile(
                              key: const Key('bible-notes'),
                              icon: KIcons.note,
                              title: 'My notes',
                              meta: notes == 1 ? '1 note' : '$notes notes',
                              onTap: () => context.push(kVerseNotesPath),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The reading translation ("NIV" with a chevron), opening the translation
/// switcher. The chip sits in a 44 hit area.
class _TranslationChip extends StatelessWidget {
  const _TranslationChip({required this.version, required this.onTap});

  final String version;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Translation, $version. Change translation',
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: KSize.touchMin),
          child: Center(
            widthFactor: 1,
            child: KChip(
              key: const Key('bible-landing-translation'),
              label: version,
              showChevron: true,
              onTap: onTap,
            ),
          ),
        ),
      ),
    );
  }
}

/// The last chapter opened, over the church photo.
class _ContinueReading extends ConsumerWidget {
  const _ContinueReading({required this.last, required this.onOpen});

  final LastRead last;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final version = ref.watch(selectedBibleProvider);
    final index =
        ref.watch(bibleIndexProvider(version.id)).valueOrNull ??
        BibleIndex.bundled();
    return KHeroCard(
      key: const Key('bible-continue'),
      compact: true,
      overline: 'Continue reading',
      title: index.label(last.location),
      image: _continuePhoto,
      primaryAction: KButton(
        key: const Key('bible-continue-button'),
        label: 'Continue',
        variant: KButtonVariant.inverse,
        onPressed: onOpen,
      ),
    );
  }
}

/// Today's reading from the Studio: whether it is read, its passages, the
/// version and the week's dots. Left out when there is no reading today.
class _DailyReading extends ConsumerWidget {
  const _DailyReading();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reading = ref.watch(dailyContentProvider).valueOrNull?.reading;
    if (reading == null) return const SizedBox.shrink();
    final k = context.k;
    final version = ref.watch(selectedBibleProvider);
    final index =
        ref.watch(bibleIndexProvider(version.id)).valueOrNull ??
        BibleIndex.bundled();
    final streaks = ref.watch(streaksProvider);
    final parts = todayLocations(reading, index);
    // A reference that does not parse is shown as the Studio wrote it.
    final title = parts.isEmpty
        ? reading.title
        : parts.map(index.label).join('; ');
    final readDays = streaks.weekRead.where((d) => d).length;

    return Padding(
      padding: const EdgeInsets.only(top: KSpace.x3),
      child: KCard(
        key: const Key('bible-daily-reading'),
        onTap: () => context.push(kTodayReadingPath),
        semanticLabel:
            'Daily reading, $title, '
            '${streaks.readToday ? 'read' : 'not read'}',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(child: KOverline('Daily reading')),
                KBadge(
                  streaks.readToday ? 'Read' : 'Not read',
                  variant: streaks.readToday
                      ? KBadgeVariant.live
                      : KBadgeVariant.newItem,
                ),
              ],
            ),
            const SizedBox(height: KSpace.xl),
            Text(title, style: KharisText.pageTitle.copyWith(color: k.text)),
            const SizedBox(height: KSpace.xxs),
            Text(
              version.abbreviation,
              style: KharisText.meta.copyWith(color: k.muted),
            ),
            const SizedBox(height: KSpace.x3),
            KStreakDots(
              days: streaks.weekRead,
              todayIndex: streaks.todayIndex,
              semanticLabel: '$readDays of 7 days read this week',
            ),
          ],
        ),
      ),
    );
  }
}
