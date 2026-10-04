import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:kharis_app/core/constants/bible_books.dart';
import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/core/utils/usfm_books.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kharis_app/features/home/data/bible_repository.dart';
import 'package:kharis_app/features/home/data/reading_plan.dart';
import 'package:kharis_app/features/home/presentation/widgets/todays_reading_card.dart';
import 'package:kharis_app/shared/providers/onboarding_provider.dart';
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
    FutureProvider.family<
      BiblePassage,
      ({String usfm, int bibleId, String abbrev})
    >(
      (ref, key) => ref
          .watch(bibleRepositoryProvider)
          .getPassage(key.usfm, bibleId: key.bibleId, abbreviation: key.abbrev),
    );

// ── Read marks ────────────────────────────────────────────────────────────────

/// Days (as `YYYY-MM-DD` keys) the member has marked as read, persisted on
/// this device. Deliberately no streaks: it is a simple "done for today".
class ReadingMarksController extends StateNotifier<Set<String>> {
  ReadingMarksController(this._prefs)
    : super((_prefs.getStringList(prefsKey) ?? const <String>[]).toSet());

  final SharedPreferences _prefs;

  static const String prefsKey = 'reading_marked_read_dates';

  /// About a year of history is plenty for a per-day check; older keys are
  /// dropped so the list cannot grow forever.
  static const int _keep = 400;

  bool isRead(DateTime day) => state.contains(readingDateKey(day));

  /// Marks [day] read, or clears the mark when it is already set.
  Future<void> toggle(DateTime day) async {
    final key = readingDateKey(day);
    final next = {...state};
    if (!next.remove(key)) next.add(key);
    final sorted = next.toList()..sort();
    final kept = sorted.length > _keep
        ? sorted.sublist(sorted.length - _keep)
        : sorted;
    state = kept.toSet();
    await _prefs.setStringList(prefsKey, kept);
  }
}

final readingMarksProvider =
    StateNotifierProvider<ReadingMarksController, Set<String>>(
      (ref) => ReadingMarksController(ref.watch(sharedPreferencesProvider)),
    );

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
    final content = contentAsync.valueOrNull;
    final dayLabel = content == null ? null : readingPlanDayLabel(content);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Close',
          icon: Icon(Icons.keyboard_arrow_down_rounded, color: context.kc.onBg),
          // Reached from a push tap with nothing underneath, a bare pop would
          // leave a blank screen; fall back to Home.
          onPressed: () {
            final router = GoRouter.of(context);
            router.canPop() ? router.pop() : router.go('/home');
          },
        ),
        actions: [
          // Hands the passage to YouVersion / bible.com for people who want
          // their own Bible app (tester feedback).
          IconButton(
            tooltip: 'Open in Bible app',
            icon: Icon(Icons.menu_book_rounded, color: context.kc.onBg),
            onPressed: () {
              final reading = content?.reading;
              if (reading == null) return;
              final usfm = usfmPassageId(reading.book, '${reading.chapter}');
              if (usfm == null) return;
              unawaited(
                launchUrl(
                  Uri.parse('https://www.bible.com/bible/111/$usfm'),
                  mode: LaunchMode.externalApplication,
                ),
              );
            },
          ),
        ],
        title: Text(
          dayLabel == null
              ? 'Today\u2019s reading'
              : 'Reading plan \u00B7 $dayLabel',
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
          title: 'Couldn\u2019t load today\u2019s reading',
          message: 'Check your connection and try again.',
          onRetry: () => ref.invalidate(dailyContentProvider),
        ),
        data: (content) {
          final reading = content.reading;
          final chapters = kBibleBooks[reading.book];
          // A plan that runs past the end of its book would ask YouVersion
          // for a chapter that does not exist ("2 Corinthians 17") and get a
          // 404. Say what is wrong instead of offering a Retry that cannot
          // succeed.
          if (chapters != null && reading.chapter > chapters) {
            return _ErrorView(
              title: 'Today\u2019s reading isn\u2019t available',
              message:
                  '${reading.book} has $chapters chapters, so '
                  '${reading.book} ${reading.chapter} can\u2019t be shown. '
                  'Please check back tomorrow.',
            );
          }
          final usfm = usfmPassageId(reading.book, '${reading.chapter}');
          if (usfm == null) {
            return _ErrorView(
              title: 'Today\u2019s reading isn\u2019t available',
              message:
                  '\u201c${reading.book}\u201d isn\u2019t a book we '
                  'recognise. Please check back tomorrow.',
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
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.card),
        ),
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
                    style: AppTypography.bodySm.copyWith(
                      color: context.kc.muted,
                    ),
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
                            ? const Icon(
                                Icons.check_rounded,
                                color: AppColors.primary,
                                size: 20,
                              )
                            : null,
                        onTap: () {
                          sheetRef.read(selectedBibleProvider.notifier).state =
                              b;
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
    final passageAsync = ref.watch(
      passageProvider((
        usfm: usfmId,
        bibleId: version.id,
        abbrev: version.abbreviation,
      )),
    );

    return passageAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
      error: (error, _) {
        debugPrint('ReadingScreen: passage $usfmId failed: $error');
        final notFound =
            error is DioException && error.response?.statusCode == 404;
        if (notFound) {
          return _ErrorView(
            title: 'This passage isn\u2019t available',
            message:
                '$fallbackReference couldn\u2019t be found in '
                '${version.abbreviation}. Try another version, or open it '
                'in your Bible app.',
            actionLabel: 'Change version',
            onAction: () => _showVersionSheet(context, ref),
          );
        }
        return _ErrorView(
          title: 'Couldn\u2019t load the passage',
          message: 'Check your connection and try again.',
          onRetry: () => ref.invalidate(
            passageProvider((
              usfm: usfmId,
              bibleId: version.id,
              abbrev: version.abbreviation,
            )),
          ),
        );
      },
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
                    style: AppTypography.display(
                      size: 32,
                      weight: FontWeight.w700,
                    ).copyWith(color: context.kc.onBg, height: 1.15),
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
            if (passage.copyright != null && passage.copyright!.isNotEmpty) ...[
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
            const _ReadingActions(),
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
              const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: AppColors.primary,
                size: 16,
              ),
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
        children.add(
          Padding(
            padding: const EdgeInsets.only(top: 20, bottom: 8),
            child: Text(
              block.segments.map((s) => s.text).join(' '),
              style: AppTypography.display(
                size: 17,
                weight: FontWeight.w700,
              ).copyWith(color: context.kc.onBg),
            ),
          ),
        );
        continue;
      }
      if (block.isSuperscription) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              block.segments.map((s) => s.text).join(' '),
              style: AppTypography.serif(
                size: 15,
                italic: true,
              ).copyWith(color: context.kc.muted),
            ),
          ),
        );
        continue;
      }

      final spans = <InlineSpan>[];
      for (final seg in block.segments) {
        if (seg.verse != null) {
          spans.add(
            WidgetSpan(
              alignment: PlaceholderAlignment.top,
              child: Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Text('${seg.verse}', style: verseStyle),
              ),
            ),
          );
        }
        if (seg.text.isNotEmpty) {
          spans.add(TextSpan(text: '${seg.text} '));
        }
      }
      children.add(
        Padding(
          padding: EdgeInsets.only(
            left: block.poetryIndent * 18.0,
            bottom: block.styleClass.startsWith('q') ? 0 : 14,
          ),
          child: Text.rich(TextSpan(style: bodyStyle, children: spans)),
        ),
      );
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
              const Icon(
                Icons.self_improvement_rounded,
                color: AppColors.hqStroke,
                size: 16,
              ),
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

/// Bottom action: mark today's reading as read. Persists on this device
/// ([readingMarksProvider]) and toggles back off on a second tap.
class _ReadingActions extends ConsumerWidget {
  const _ReadingActions();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = DateTime.now();
    final read = ref
        .watch(readingMarksProvider)
        .contains(readingDateKey(today));
    return Semantics(
      button: true,
      toggled: read,
      child: GestureDetector(
        key: const Key('reading-mark-read'),
        onTap: () => ref.read(readingMarksProvider.notifier).toggle(today),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: read ? AppColors.primary : context.kc.surface,
            borderRadius: BorderRadius.circular(AppRadius.button),
            border: Border.all(
              color: read ? AppColors.primary : context.kc.divider,
            ),
            boxShadow: AppShadows.card,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                read ? Icons.check_circle_rounded : Icons.check_rounded,
                color: read ? AppColors.onPrimary : AppColors.primary,
                size: 19,
              ),
              const SizedBox(width: 8),
              Text(
                read ? 'Read today' : 'Mark as read',
                style: AppTypography.ui(
                  size: 14.5,
                  weight: FontWeight.w700,
                  color: read ? AppColors.onPrimary : context.kc.onBg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({
    required this.title,
    required this.message,
    this.onRetry,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String message;

  /// Only offered when retrying can actually help (a network failure).
  final VoidCallback? onRetry;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final actionLabel = this.actionLabel;
    final buttonStyle = AppTypography.ui(
      weight: FontWeight.w600,
      color: AppColors.primary,
    );
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.menu_book_rounded, color: context.kc.muted, size: 40),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTypography.ui(
                size: 16,
                weight: FontWeight.w700,
              ).copyWith(color: context.kc.onBg),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTypography.bodySm.copyWith(color: context.kc.muted),
            ),
            const SizedBox(height: 8),
            if (onRetry != null)
              TextButton(
                onPressed: onRetry,
                child: Text('Retry', style: buttonStyle),
              ),
            if (actionLabel != null)
              TextButton(
                onPressed: onAction,
                child: Text(actionLabel, style: buttonStyle),
              ),
          ],
        ),
      ),
    );
  }
}
