import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/core/utils/usfm_books.dart';
import 'package:kharis_app/features/home/data/bible_repository.dart';
import 'package:kharis_app/shared/providers/sermon_provider.dart';

final bibleRepositoryProvider = Provider<BibleRepository>(
  (ref) => BibleRepository(),
);

/// Selected reading translation. Session-scoped; defaults to NIV.
final selectedBibleProvider = StateProvider<BibleVersion>(
  (ref) => const BibleVersion(
    id: BibleRepository.defaultBibleId,
    abbreviation: BibleRepository.defaultBibleAbbreviation,
    title: 'New International Version 2011',
  ),
);

/// Versions licensed for the app key.
final biblesProvider = FutureProvider<List<BibleVersion>>(
  (ref) => ref.watch(bibleRepositoryProvider).getBibles(),
);

/// Passage for (usfm, version), cached per pair by the repository.
final passageProvider =
    FutureProvider.family<BiblePassage, ({String usfm, int bibleId, String abbrev})>(
  (ref, key) => ref.watch(bibleRepositoryProvider).getPassage(
        key.usfm,
        bibleId: key.bibleId,
        abbreviation: key.abbrev,
      ),
);

/// Reading-plan day counter, derived from today's day-of-year. Presentation
/// only — keeps the devotional "Day N" label truthful to the calendar.
int _readingPlanDay() {
  final now = DateTime.now();
  return now.difference(DateTime(now.year, 1, 1)).inDays + 1;
}

/// Warm superscript verse-number accent for the reading surface. Light mode
/// uses a warm brown against the paper background; dark mode lifts it to a
/// warm tan so it still separates from the serif body.
Color _verseAccent(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFFD1A57C)
        : const Color(0xFFB8875F);

/// Warm ink for long-form serif scripture — deliberately softer than primary
/// text so long passages read calmly. Dark mode uses a warm off-white.
Color _scriptureInk(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFFE8E2D8)
        : const Color(0xFF2A2723);

/// Full-screen reader for today's Bible reading with version switching.
/// Design-handoff v3 — calm, scripture-forward, Newsreader serif on light warm.
class ReadingScreen extends ConsumerWidget {
  const ReadingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contentAsync = ref.watch(dailyContentProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.keyboard_arrow_down_rounded,
              color: context.kc.onBg),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Reading plan \u00B7 Day ${_readingPlanDay()}',
          style: AppTypography.ui(
            size: 13,
            weight: FontWeight.w700,
            color: context.kc.onBg,
          ),
        ),
        centerTitle: true,
      ),
      body: contentAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (_, _) => _ErrorView(
          message: 'Could not load today\'s reading',
          onRetry: () => ref.invalidate(dailyContentProvider),
        ),
        data: (content) {
          final reading = content.reading;
          final usfm = usfmPassageId(reading.book, '${reading.chapter}');
          if (usfm == null) {
            return _ErrorView(
              message: 'Unknown book: ${reading.book}',
              onRetry: () => ref.invalidate(dailyContentProvider),
            );
          }
          return _PassageView(
            usfmId: usfm,
            fallbackReference: '${reading.book} ${reading.chapter}',
            prayer: content.prayer,
            prayerReference: content.prayerReference,
          );
        },
      ),
    );
  }
}

class _PassageView extends ConsumerWidget {
  const _PassageView({
    required this.usfmId,
    required this.fallbackReference,
    required this.prayer,
    required this.prayerReference,
  });

  final String usfmId;
  final String fallbackReference;
  final String prayer;
  final String prayerReference;

  void _showVersionSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.kc.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.card)),
      ),
      builder: (sheetContext) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(sheetContext).size.height * 0.7,
          ),
          child: Consumer(
            builder: (context, sheetRef, _) {
              final biblesAsync = sheetRef.watch(biblesProvider);
              final selected = sheetRef.watch(selectedBibleProvider);

              return biblesAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                ),
                error: (_, _) => Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Could not load versions',
                    style: AppTypography.bodySm
                        .copyWith(color: context.kc.muted),
                  ),
                ),
                data: (bibles) => ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 22),
                      child: Text(
                        'BIBLE VERSION',
                        style: AppTypography.labelMd.copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.1,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    for (final b in bibles)
                      ListTile(
                        dense: true,
                        title: Text(
                          b.abbreviation,
                          style: AppTypography.ui(
                            size: 14,
                            weight: b.id == selected.id
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: b.id == selected.id
                                ? AppColors.primary
                                : context.kc.onBg,
                          ),
                        ),
                        subtitle: Text(
                          b.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.ui(
                            size: 12,
                            color: context.kc.muted,
                          ),
                        ),
                        trailing: b.id == selected.id
                            ? const Icon(Icons.check_rounded,
                                color: AppColors.primary, size: 20)
                            : null,
                        onTap: () {
                          sheetRef
                              .read(selectedBibleProvider.notifier)
                              .state = b;
                          Navigator.of(sheetContext).pop();
                        },
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final version = ref.watch(selectedBibleProvider);
    final passageAsync = ref.watch(passageProvider(
      (usfm: usfmId, bibleId: version.id, abbrev: version.abbreviation),
    ));

    return passageAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
      error: (_, _) => _ErrorView(
        message: 'Could not load the passage in ${version.abbreviation}',
        onRetry: () => ref.invalidate(passageProvider(
          (usfm: usfmId, bibleId: version.id, abbrev: version.abbreviation),
        )),
      ),
      data: (passage) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(30, 8, 30, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Eyebrow.
            Text(
              'TODAY\u2019S READING',
              style: AppTypography.ui(
                size: 11,
                weight: FontWeight.w600,
                letterSpacing: 11 * 0.09,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 8),
            // Reference (display) + version switcher.
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    passage.reference.isNotEmpty
                        ? passage.reference
                        : fallbackReference,
                    style: AppTypography.display(size: 32, weight: FontWeight.w700)
                        .copyWith(color: context.kc.onBg, height: 1.15),
                  ),
                ),
                const SizedBox(width: 12),
                _VersionPill(
                  label: passage.bibleAbbreviation,
                  onTap: () => _showVersionSheet(context, ref),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _PassageBody(blocks: passage.blocks),
            if (passage.copyright != null &&
                passage.copyright!.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(
                passage.copyright!,
                style: AppTypography.ui(
                  size: 11,
                  height: 1.5,
                  color: context.kc.muted,
                ),
              ),
            ],
            const SizedBox(height: 26),
            _DailyPrayer(prayer: prayer, reference: prayerReference),
            const SizedBox(height: 22),
            _ReadingActions(),
          ],
        ),
      ),
    );
  }
}

/// Purple outlined version-switcher pill.
class _VersionPill extends StatelessWidget {
  const _VersionPill({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Change Bible version',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.primary, width: 1),
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: AppTypography.ui(
                  size: 12,
                  weight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 3),
              const Icon(Icons.keyboard_arrow_down_rounded,
                  color: AppColors.primary, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}

/// Renders passage blocks with superscript verse numbers, poetry indents,
/// headings, and superscriptions — all in Newsreader serif for a calm,
/// scripture-forward reading tone.
class _PassageBody extends StatelessWidget {
  const _PassageBody({required this.blocks});

  final List<PassageBlock> blocks;

  @override
  Widget build(BuildContext context) {
    final bodyStyle = AppTypography.serif(
      size: 18,
      height: 1.62,
      color: _scriptureInk(context),
    );
    final verseStyle = AppTypography.ui(
      size: 12,
      height: 1.62,
      weight: FontWeight.w600,
      color: _verseAccent(context),
    );

    final children = <Widget>[];
    for (final block in blocks) {
      if (block.isHeading) {
        children.add(Padding(
          padding: const EdgeInsets.only(top: 20, bottom: 8),
          child: Text(
            block.segments.map((s) => s.text).join(' '),
            style: AppTypography.display(size: 17, weight: FontWeight.w700)
                .copyWith(color: context.kc.onBg),
          ),
        ));
        continue;
      }
      if (block.isSuperscription) {
        children.add(Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            block.segments.map((s) => s.text).join(' '),
            style: AppTypography.serif(size: 15, italic: true)
                .copyWith(color: context.kc.muted),
          ),
        ));
        continue;
      }

      final spans = <InlineSpan>[];
      for (final seg in block.segments) {
        if (seg.verse != null) {
          spans.add(WidgetSpan(
            alignment: PlaceholderAlignment.top,
            child: Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Text('${seg.verse}', style: verseStyle),
            ),
          ));
        }
        if (seg.text.isNotEmpty) {
          spans.add(TextSpan(text: '${seg.text} '));
        }
      }
      children.add(Padding(
        padding: EdgeInsets.only(
          left: block.poetryIndent * 18.0,
          bottom: block.styleClass.startsWith('q') ? 0 : 14,
        ),
        child: Text.rich(TextSpan(style: bodyStyle, children: spans)),
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }
}

/// Calm serif daily-prayer card shown beneath the passage.
class _DailyPrayer extends StatelessWidget {
  const _DailyPrayer({required this.prayer, required this.reference});

  final String prayer;
  final String reference;

  @override
  Widget build(BuildContext context) {
    if (prayer.trim().isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      decoration: BoxDecoration(
        color: context.kc.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.self_improvement_rounded,
                  color: AppColors.hqStroke, size: 16),
              const SizedBox(width: 7),
              Text(
                'DAILY PRAYER',
                style: AppTypography.ui(
                  size: 11,
                  weight: FontWeight.w700,
                  letterSpacing: 11 * 0.09,
                  color: AppColors.hqStroke,
                ),
              ),
            ],
          ),
          if (reference.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Inspired by $reference',
              style: AppTypography.ui(size: 12.5, color: context.kc.muted),
            ),
          ],
          const SizedBox(height: 14),
          Text(
            prayer,
            style: AppTypography.serif(
              size: 17,
              italic: true,
              height: 1.6,
              color: _scriptureInk(context),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom actions — gold Listen (hooks into the player) + Mark-as-read.
class _ReadingActions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Listen (gold primary) → opens the existing full-screen player.
        Expanded(
          child: GestureDetector(
            onTap: () => context.push('/player'),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: context.kc.accent,
                borderRadius: BorderRadius.circular(AppRadius.button),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.play_arrow_rounded,
                      color: context.kc.onAccent, size: 19),
                  const SizedBox(width: 7),
                  Text(
                    'Listen',
                    style: AppTypography.ui(
                      size: 14.5,
                      weight: FontWeight.w700,
                      color: context.kc.onAccent,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 11),
        // Mark as read (outlined secondary).
        GestureDetector(
          onTap: () {
            ScaffoldMessenger.of(context)
              ..clearSnackBars()
              ..showSnackBar(
                SnackBar(
                  content: Text(
                    'Day ${_readingPlanDay()} marked as read \u2705',
                    style: AppTypography.ui(
                      size: 13.5,
                      weight: FontWeight.w600,
                    ),
                  ),
                  behavior: SnackBarBehavior.floating,
                ),
              );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: context.kc.surface,
              borderRadius: BorderRadius.circular(AppRadius.button),
              border: Border.all(color: context.kc.divider, width: 1),
              boxShadow: AppShadows.card,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_rounded,
                    color: AppColors.primary, size: 18),
                const SizedBox(width: 7),
                Text(
                  'Mark read',
                  style: AppTypography.ui(
                    size: 14.5,
                    weight: FontWeight.w700,
                    color: context.kc.onBg,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.menu_book_rounded,
              color: context.kc.muted, size: 40),
          const SizedBox(height: 14),
          Text(
            message,
            style: AppTypography.bodySm.copyWith(color: context.kc.muted),
          ),
          TextButton(
            onPressed: onRetry,
            child: Text(
              'Retry',
              style: AppTypography.ui(
                weight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
