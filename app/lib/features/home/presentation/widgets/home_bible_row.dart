import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/features/home/data/bible_reference.dart';
import 'package:kharis_app/features/home/data/bible_repository.dart';
import 'package:kharis_app/shared/providers/bible_provider.dart';
import 'package:kharis_app/shared/providers/sermon_provider.dart';
import 'package:kharis_app/shared/widgets/press_effect.dart';
import 'package:kharis_app/shared/widgets/skeleton.dart';

const double _kRowHeight = 68;

/// Home's way into Scripture as one compact row. With a Content Studio
/// reading today it names the chapters the reading opens on ("John 3",
/// "Romans 8 · Psalm 23") and opens the reader there, with a separate
/// "Whole Bible" action for the book list; otherwise it offers the whole
/// Bible. Loading holds the row's place with a skeleton so the sections
/// below do not jump when the day's content lands.
class HomeBibleRow extends ConsumerWidget {
  const HomeBibleRow({super.key, this.padding = EdgeInsets.zero});

  /// Space around the row.
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contentAsync = ref.watch(dailyContentProvider);
    final reading = contentAsync.valueOrNull?.reading;
    final loading =
        !contentAsync.hasValue &&
        contentAsync.isLoading &&
        !contentAsync.hasError;

    final Widget row;
    if (reading != null) {
      final version = ref.watch(selectedBibleProvider);
      final index =
          ref.watch(bibleIndexProvider(version.id)).valueOrNull ??
          BibleIndex.bundled();
      final reference = reading.reference.trim();
      final chapters = {
        for (final at in parseReadingReferences(reference, index))
          index.label(at.wholeChapter),
      };
      // Nothing parsed: the Studio's own wording.
      final title = chapters.isNotEmpty
          ? chapters.join(' \u00b7 ')
          : (reference.isEmpty ? reading.title : reference);
      row = _Row(
        eyebrow: "Today's reading",
        title: title,
        semanticsLabel: "Today's reading: $title. Read now",
        onTap: () => context.push('/reading'),
        wholeBible: () => context.push('/bible'),
      );
    } else if (loading) {
      row = const Skeleton(
        key: Key('home-bible-row-loading'),
        width: double.infinity,
        height: _kRowHeight,
        radius: AppRadius.card,
      );
    } else {
      row = _Row(
        title: 'Read the Bible',
        subtitle: 'Every book and chapter, in your translation.',
        semanticsLabel: 'Read the Bible',
        onTap: () => context.push('/bible'),
      );
    }

    return Padding(
      key: const Key('home-bible-row'),
      padding: padding,
      child: row,
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    this.eyebrow,
    required this.title,
    this.subtitle,
    required this.semanticsLabel,
    required this.onTap,
    this.wholeBible,
  });

  /// Small caption above [title].
  final String? eyebrow;
  final String title;

  /// Supporting line below [title].
  final String? subtitle;
  final String semanticsLabel;
  final VoidCallback onTap;

  /// Opens the whole Bible from a trailing action; no action when null.
  final VoidCallback? wholeBible;

  @override
  Widget build(BuildContext context) {
    final kc = context.kc;
    final eyebrow = this.eyebrow;
    final subtitle = this.subtitle;
    final wholeBible = this.wholeBible;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: kc.surface,
        borderRadius: AppRadius.cardBorder,
        boxShadow: AppShadows.card,
      ),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              button: true,
              label: semanticsLabel,
              excludeSemantics: true,
              child: PressEffect(
                key: const Key('home-bible-row-open'),
                onTap: onTap,
                child: Container(
                  constraints: const BoxConstraints(minHeight: _kRowHeight),
                  padding: EdgeInsets.fromLTRB(
                    14,
                    12,
                    wholeBible == null ? 14 : 4,
                    12,
                  ),
                  // Transparent fill so the whole area takes the tap.
                  color: Colors.transparent,
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: kc.chipBg,
                          borderRadius: BorderRadius.circular(AppRadius.tile),
                        ),
                        child: Icon(
                          Icons.menu_book_rounded,
                          size: 22,
                          color: kc.onChip,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (eyebrow != null) ...[
                              Text(
                                eyebrow,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.ui(
                                  size: 12,
                                  weight: FontWeight.w600,
                                ).copyWith(color: kc.muted, height: 1.2),
                              ),
                              const SizedBox(height: 3),
                            ],
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.ui(
                                size: 15,
                                weight: FontWeight.w700,
                              ).copyWith(color: kc.onBg, height: 1.25),
                            ),
                            if (subtitle != null) ...[
                              const SizedBox(height: 3),
                              Text(
                                subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.ui(
                                  size: 12.5,
                                ).copyWith(color: kc.muted, height: 1.3),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (wholeBible == null) ...[
                        const SizedBox(width: 8),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 22,
                          color: kc.muted,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (wholeBible != null)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Semantics(
                button: true,
                label: 'Open the whole Bible',
                excludeSemantics: true,
                child: TextButton(
                  key: const Key('home-bible-row-whole-bible'),
                  onPressed: wholeBible,
                  style: TextButton.styleFrom(
                    minimumSize: const Size(44, 44),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    foregroundColor: kc.accentInk,
                    textStyle: AppTypography.ui(
                      size: 13,
                      weight: FontWeight.w700,
                    ),
                  ),
                  child: const Text('Whole Bible'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
