import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:kharis_app/features/bible/presentation/bible_routes.dart';
import 'package:kharis_app/shared/providers/verse_marks_provider.dart';
import 'package:kharis_app/ui/components/components.dart';

/// The member's verse highlights, newest first (`/bible/highlights`). Each
/// opens its verse in the reader; swipe or Remove takes it away.
class HighlightsScreen extends ConsumerWidget {
  const HighlightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final highlights = ref.watch(verseHighlightsProvider);
    return BibleListScaffold(
      title: 'Highlights',
      empty: highlights.isEmpty
          ? const KEmptyState(
              key: Key('highlights-empty'),
              icon: KIcons.pen,
              title: 'No highlights yet',
              hint: 'Tap a verse in the reader to highlight it.',
            )
          : null,
      children: [
        for (final h in highlights)
          Dismissible(
            key: Key('highlight-${h.ref.usfm}'),
            direction: DismissDirection.endToStart,
            onDismissed: (_) =>
                ref.read(verseMarksRepositoryProvider).clearHighlight(h.ref),
            child: KListRow(
              title: h.ref.reference,
              meta: '${h.text} \u00b7 ${h.version}',
              leading: KHighlightSwatch(colour: h.colour),
              trailing: KIconButton(
                key: Key('highlight-remove-${h.ref.usfm}'),
                icon: KIcons.close,
                label: 'Remove highlight on ${h.ref.reference}',
                onPressed: () => ref
                    .read(verseMarksRepositoryProvider)
                    .clearHighlight(h.ref),
              ),
              onTap: () =>
                  unawaited(context.push(bibleReaderPath(h.ref.location))),
            ),
          ),
      ],
    );
  }
}

/// A Bible list screen: the header, then the rows in one group, or the
/// empty state.
class BibleListScaffold extends StatelessWidget {
  const BibleListScaffold({
    super.key,
    required this.title,
    required this.children,
    this.empty,
  });

  final String title;
  final List<Widget> children;

  /// Shown instead of the rows when there are none.
  final Widget? empty;

  @override
  Widget build(BuildContext context) {
    final empty = this.empty;
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
                  KScreenHeader(title: title),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      KSpace.gutter,
                      KSpace.x3,
                      KSpace.gutter,
                      0,
                    ),
                    child: empty ?? KListGroup(children: children),
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
