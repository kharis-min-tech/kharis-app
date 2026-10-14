import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:kharis_app/core/constants/bible_books.dart';
import 'package:kharis_app/core/theme/theme.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kharis_app/features/home/data/bible_reference.dart';
import 'package:kharis_app/features/home/data/bible_repository.dart';
import 'package:kharis_app/features/home/data/daily_content_repository.dart';
import 'package:kharis_app/features/home/presentation/screens/bible_books_screen.dart';
import 'package:kharis_app/features/home/data/reading_plan.dart';
import 'package:kharis_app/features/home/presentation/widgets/todays_reading_card.dart';
import 'package:kharis_app/shared/providers/bible_provider.dart';
import 'package:kharis_app/shared/providers/onboarding_provider.dart';
import 'package:kharis_app/shared/providers/sermon_provider.dart';

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
/// uses a warm brown against the paper background (4.8:1 on `kc.bg`); dark
/// mode lifts it to a warm tan so it still separates from the serif body.
Color _verseAccent(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? const Color(0xFFD1A57C)
    : const Color(0xFF8F6440);

/// Warm ink for long-form serif scripture — deliberately softer than primary
/// text so long passages read calmly. Dark mode uses a warm off-white.
Color _scriptureInk(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? const Color(0xFFE8E2D8)
    : const Color(0xFF2A2723);

/// The Bible reader. Opens on today's reading (the same one as Home's card),
/// and from there browses the whole Bible: book list, chapter grid,
/// previous/next chapter, reference search and translation choice.
/// Design-handoff v3: calm, scripture-forward, Newsreader serif on light warm.
class ReadingScreen extends ConsumerStatefulWidget {
  const ReadingScreen({super.key});

  @override
  ConsumerState<ReadingScreen> createState() => _ReadingScreenState();
}

/// Today's reading as a place in the Bible, or why it cannot be shown.
({BibleLocation? location, String? problem}) _todayLocation(
  BibleReading reading,
) {
  final usfm = resolveBookUsfm(reading.book);
  if (usfm == null) {
    return (
      location: null,
      problem:
          '\u201c${reading.book}\u201d isn\u2019t a book we recognise. '
          'Please check back tomorrow.',
    );
  }
  final chapters = kCanonBooks.firstWhere((b) => b.usfm == usfm).chapters;
  // A plan that runs past the end of its book would ask YouVersion for a
  // chapter that does not exist ("2 Corinthians 17") and get a 404. Say what
  // is wrong instead of offering a Retry that cannot succeed.
  if (reading.chapter < 1 || reading.chapter > chapters) {
    return (
      location: null,
      problem:
          '${reading.book} has $chapters chapters, so '
          '${reading.book} ${reading.chapter} can\u2019t be shown. '
          'Please check back tomorrow.',
    );
  }
  return (location: BibleLocation(usfm, reading.chapter), problem: null);
}

class _ReadingScreenState extends ConsumerState<ReadingScreen> {
  /// The chapter being browsed; null while on today's reading.
  BibleLocation? _browsing;

  BibleLocation? get _today {
    final content = ref.read(dailyContentProvider).valueOrNull;
    return content == null ? null : _todayLocation(content.reading).location;
  }

  void _go(BibleLocation to) {
    final today = _today;
    setState(() {
      // Landing on today's chapter (without a verse) is today's reading.
      _browsing = today != null && to == today ? null : to;
    });
  }

  void _backToToday() => setState(() => _browsing = null);

  Future<void> _pickChapter(BibleLocation? current) async {
    final picked = await pickBibleChapter(context, current: current);
    if (picked != null && mounted) _go(picked);
  }

  Future<void> _search() async {
    final picked = await showModalBottomSheet<BibleLocation>(
      context: context,
      backgroundColor: context.kc.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.card),
        ),
      ),
      builder: (_) => const _ReferenceSearchSheet(),
    );
    if (picked != null && mounted) _go(picked);
  }

  @override
  Widget build(BuildContext context) {
    final contentAsync = ref.watch(dailyContentProvider);
    final content = contentAsync.valueOrNull;
    final dayLabel = content == null ? null : readingPlanDayLabel(content);
    final today = content == null
        ? null
        : _todayLocation(content.reading).location;
    final browsing = _browsing;
    final current = browsing ?? today;
    final version = ref.watch(selectedBibleProvider);

    final String title;
    if (browsing != null) {
      title = 'Bible';
    } else if (dayLabel != null) {
      title = 'Reading plan \u00B7 $dayLabel';
    } else {
      title = 'Today\u2019s reading';
    }

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
          IconButton(
            key: const Key('bible-search'),
            tooltip: 'Go to a passage',
            icon: Icon(Icons.search_rounded, color: context.kc.onBg),
            onPressed: _search,
          ),
          // Hands the passage to YouVersion / bible.com for people who want
          // their own Bible app (tester feedback).
          IconButton(
            tooltip: 'Open in Bible app',
            icon: Icon(Icons.open_in_new_rounded, color: context.kc.onBg),
            onPressed: current == null
                ? null
                : () => unawaited(
                    launchUrl(
                      Uri.parse(
                        'https://www.bible.com/bible/${version.id}/'
                        '${current.passageId}',
                      ),
                      mode: LaunchMode.externalApplication,
                    ),
                  ),
          ),
        ],
        title: Text(
          title,
          style: AppTypography.ui(
            size: 13,
            weight: FontWeight.w700,
            color: context.kc.onBg,
          ),
        ),
        centerTitle: true,
      ),
      body: browsing != null
          ? _PassageView(
              key: const ValueKey('browse'),
              location: browsing,
              isToday: false,
              onNavigate: _go,
              onPickChapter: () => _pickChapter(browsing),
              onToday: _backToToday,
            )
          : contentAsync.when(
              loading: () => Center(
                child: CircularProgressIndicator(color: context.kc.onChip),
              ),
              error: (_, _) => _ErrorView(
                title: 'Couldn\u2019t load today\u2019s reading',
                message: 'Check your connection and try again.',
                onRetry: () => ref.invalidate(dailyContentProvider),
                actionLabel: 'Browse the Bible',
                onAction: () => _pickChapter(null),
              ),
              data: (content) {
                final today = _todayLocation(content.reading);
                final location = today.location;
                if (location == null) {
                  return _ErrorView(
                    title: 'Today\u2019s reading isn\u2019t available',
                    message: today.problem!,
                    actionLabel: 'Browse the Bible',
                    onAction: () => _pickChapter(null),
                  );
                }
                return _PassageView(
                  key: const ValueKey('today'),
                  location: location,
                  isToday: true,
                  onNavigate: _go,
                  onPickChapter: () => _pickChapter(location),
                  prayer: content.prayer,
                  prayerReference: content.prayerReference,
                );
              },
            ),
    );
  }
}

void _showVersionSheet(BuildContext context) {
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
              loading: () => Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: CircularProgressIndicator(color: context.kc.onChip),
                ),
              ),
              error: (_, _) => Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Could not load versions',
                      style: AppTypography.bodySm.copyWith(
                        color: context.kc.muted,
                      ),
                    ),
                    TextButton(
                      onPressed: () => sheetRef.invalidate(biblesProvider),
                      child: Text(
                        'Retry',
                        style: AppTypography.ui(
                          weight: FontWeight.w600,
                          color: context.kc.onChip,
                        ),
                      ),
                    ),
                  ],
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
                        color: context.kc.onChip,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final b in bibles)
                    ListTile(
                      key: Key('bible-version-${b.id}'),
                      dense: true,
                      title: Text(
                        b.abbreviation,
                        style: AppTypography.ui(
                          size: 14,
                          weight: b.id == selected.id
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: b.id == selected.id
                              ? context.kc.onChip
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
                          ? Icon(
                              Icons.check_rounded,
                              color: context.kc.onChip,
                              size: 20,
                            )
                          : null,
                      onTap: () {
                        unawaited(
                          sheetRef
                              .read(selectedBibleProvider.notifier)
                              .select(b),
                        );
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

/// One chapter: header (today label or way back to it, reference, version),
/// the text with any searched verses highlighted, then previous/next.
class _PassageView extends ConsumerStatefulWidget {
  const _PassageView({
    super.key,
    required this.location,
    required this.isToday,
    required this.onNavigate,
    required this.onPickChapter,
    this.onToday,
    this.prayer = '',
    this.prayerReference = '',
  });

  final BibleLocation location;
  final bool isToday;
  final ValueChanged<BibleLocation> onNavigate;
  final VoidCallback onPickChapter;

  /// Returns to today's reading; shown while browsing.
  final VoidCallback? onToday;
  final String prayer;
  final String prayerReference;

  @override
  ConsumerState<_PassageView> createState() => _PassageViewState();
}

class _PassageViewState extends ConsumerState<_PassageView> {
  final _verseKey = GlobalKey();

  /// The verse selection already scrolled to, so rebuilds do not jump again.
  BibleLocation? _revealed;

  void _revealVerse(BibleLocation location) {
    if (location.verseStart == null || _revealed == location) return;
    _revealed = location;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _verseKey.currentContext;
      if (target == null || !target.mounted) return;
      Scrollable.ensureVisible(
        target,
        alignment: 0.2,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final location = widget.location;
    final version = ref.watch(selectedBibleProvider);
    final index =
        ref.watch(bibleIndexProvider(version.id)).valueOrNull ??
        BibleIndex.bundled();
    final passageKey = (
      usfm: location.passageId,
      bibleId: version.id,
      abbrev: version.abbreviation,
    );
    final passageAsync = ref.watch(passageProvider(passageKey));

    final header = Padding(
      padding: const EdgeInsets.fromLTRB(30, 8, 30, 0),
      child: _PassageHeader(
        label: index.label(location),
        versionLabel: version.abbreviation,
        isToday: widget.isToday,
        onToday: widget.onToday,
        onPickChapter: widget.onPickChapter,
        onPickVersion: () => _showVersionSheet(context),
      ),
    );

    Widget withHeader(Widget body) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        Expanded(child: body),
      ],
    );

    return passageAsync.when(
      loading: () => withHeader(
        Center(child: CircularProgressIndicator(color: context.kc.onChip)),
      ),
      error: (error, _) {
        debugPrint('ReadingScreen: passage $location failed: $error');
        final notFound =
            error is DioException && error.response?.statusCode == 404;
        if (notFound) {
          return withHeader(
            _ErrorView(
              title: 'This passage isn\u2019t available',
              message:
                  '${index.label(location.wholeChapter)} couldn\u2019t be '
                  'found in ${version.abbreviation}. Try another version, '
                  'or open it in your Bible app.',
              actionLabel: 'Change version',
              onAction: () => _showVersionSheet(context),
            ),
          );
        }
        return withHeader(
          _ErrorView(
            title: 'Couldn\u2019t load the passage',
            message: 'Check your connection and try again.',
            onRetry: () {
              ref.invalidate(passageProvider(passageKey));
              if (index.isFallback) {
                ref.invalidate(bibleIndexProvider(version.id));
              }
            },
          ),
        );
      },
      data: (passage) {
        _revealVerse(location);
        final previous = index.previous(location);
        final next = index.next(location);
        return SingleChildScrollView(
          key: PageStorageKey('bible-${location.passageId}'),
          padding: const EdgeInsets.only(bottom: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              header,
              Padding(
                padding: const EdgeInsets.fromLTRB(30, 20, 30, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _PassageBody(
                      blocks: passage.blocks,
                      highlight: location.verseStart == null
                          ? null
                          : (
                              location.verseStart!,
                              location.verseEnd ?? location.verseStart!,
                            ),
                      verseKey: _verseKey,
                    ),
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
                    if (widget.isToday) ...[
                      const SizedBox(height: 26),
                      _DailyPrayer(
                        prayer: widget.prayer,
                        reference: widget.prayerReference,
                      ),
                      const SizedBox(height: 22),
                      const _ReadingActions(),
                    ],
                    if (previous != null || next != null) ...[
                      const SizedBox(height: 26),
                      Row(
                        children: [
                          Expanded(
                            child: previous == null
                                ? const SizedBox.shrink()
                                : _ChapterStep(
                                    key: const Key('bible-prev'),
                                    caption: 'Previous',
                                    label: index.label(previous),
                                    forward: false,
                                    onTap: () => widget.onNavigate(previous),
                                  ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: next == null
                                ? const SizedBox.shrink()
                                : _ChapterStep(
                                    key: const Key('bible-next'),
                                    caption: 'Next',
                                    label: index.label(next),
                                    forward: true,
                                    onTap: () => widget.onNavigate(next),
                                  ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// "Today's reading" eyebrow (or a way back to it while browsing), the
/// reference that opens the book list, and the version switcher.
class _PassageHeader extends StatelessWidget {
  const _PassageHeader({
    required this.label,
    required this.versionLabel,
    required this.isToday,
    required this.onToday,
    required this.onPickChapter,
    required this.onPickVersion,
  });

  final String label;
  final String versionLabel;
  final bool isToday;
  final VoidCallback? onToday;
  final VoidCallback onPickChapter;
  final VoidCallback onPickVersion;

  @override
  Widget build(BuildContext context) {
    final kc = context.kc;
    final onToday = this.onToday;
    final Widget eyebrow;
    if (isToday) {
      eyebrow = Text(
        'TODAY\u2019S READING',
        style: AppTypography.ui(
          size: 11,
          weight: FontWeight.w600,
          letterSpacing: 11 * 0.09,
          color: kc.onChip,
        ),
      );
    } else if (onToday != null) {
      eyebrow = Semantics(
        button: true,
        label: 'Back to today\u2019s reading',
        excludeSemantics: true,
        child: GestureDetector(
          key: const Key('bible-today'),
          behavior: HitTestBehavior.opaque,
          onTap: onToday,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: kc.chipBg,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.today_rounded, size: 14, color: kc.onChip),
                const SizedBox(width: 5),
                Text(
                  'Today\u2019s reading',
                  style: AppTypography.ui(
                    size: 12,
                    weight: FontWeight.w700,
                    color: kc.onChip,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } else {
      eyebrow = const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The version sits up here so the reference gets the full width.
        Row(
          children: [
            Expanded(
              child: Align(alignment: Alignment.centerLeft, child: eyebrow),
            ),
            const SizedBox(width: 12),
            _VersionPill(label: versionLabel, onTap: onPickVersion),
          ],
        ),
        Semantics(
          button: true,
          label: '$label. Choose a book and chapter',
          excludeSemantics: true,
          child: GestureDetector(
            key: const Key('bible-reference'),
            behavior: HitTestBehavior.opaque,
            onTap: onPickChapter,
            child: Text.rich(
              TextSpan(
                // The no-break space keeps the chevron with the last word.
                text: '$label\u00A0',
                children: [
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: kc.muted,
                      size: 26,
                    ),
                  ),
                ],
              ),
              style: AppTypography.display(
                size: 32,
                weight: FontWeight.w700,
              ).copyWith(color: kc.onBg, height: 1.15),
            ),
          ),
        ),
      ],
    );
  }
}

/// Previous / next chapter card at the end of a chapter.
class _ChapterStep extends StatelessWidget {
  const _ChapterStep({
    super.key,
    required this.caption,
    required this.label,
    required this.forward,
    required this.onTap,
  });

  final String caption;
  final String label;
  final bool forward;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final kc = context.kc;
    final arrow = Icon(
      forward ? Icons.chevron_right_rounded : Icons.chevron_left_rounded,
      color: kc.onChip,
      size: 22,
    );
    final text = Expanded(
      child: Column(
        crossAxisAlignment: forward
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Text(caption, style: AppTypography.ui(size: 11.5, color: kc.muted)),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.ui(
              size: 14,
              weight: FontWeight.w700,
              color: kc.onBg,
            ),
          ),
        ],
      ),
    );
    return Semantics(
      button: true,
      label: '$caption chapter, $label',
      excludeSemantics: true,
      child: Material(
        color: kc.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.button),
          side: BorderSide(color: kc.divider),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            child: Row(children: forward ? [text, arrow] : [arrow, text]),
          ),
        ),
      ),
    );
  }
}

/// "Go to" sheet: a reference field that resolves against the selected
/// version and explains anything it cannot find.
class _ReferenceSearchSheet extends ConsumerStatefulWidget {
  const _ReferenceSearchSheet();

  @override
  ConsumerState<_ReferenceSearchSheet> createState() =>
      _ReferenceSearchSheetState();
}

class _ReferenceSearchSheetState extends ConsumerState<_ReferenceSearchSheet> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final navigator = Navigator.of(context);
    final version = ref.read(selectedBibleProvider);
    // Never wait on the version's book list here: on a slow connection Go
    // would do nothing for up to a minute. The bundled table covers the
    // standard canon; the reader re-checks the chapter once the list lands.
    final index =
        ref.read(bibleIndexProvider(version.id)).valueOrNull ??
        BibleIndex.bundled();
    switch (parseBibleReference(_controller.text, index)) {
      case ReferenceFound(:final location):
        navigator.pop(location);
      case ReferenceError(:final message):
        setState(() => _error = message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final kc = context.kc;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Go to a passage',
                style: AppTypography.display(
                  size: 20,
                  weight: FontWeight.w700,
                ).copyWith(color: kc.onBg),
              ),
              const SizedBox(height: 14),
              TextField(
                key: const Key('bible-search-field'),
                controller: _controller,
                autofocus: true,
                autocorrect: false,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.go,
                onSubmitted: (_) => _submit(),
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
                style: AppTypography.ui(size: 16, color: kc.onBg),
                decoration: InputDecoration(
                  hintText: 'John 3:16, Psalm 23, 1 Cor 13:4-7',
                  hintStyle: AppTypography.ui(size: 15, color: kc.muted),
                  errorText: _error,
                  errorMaxLines: 3,
                  prefixIcon: Icon(Icons.search_rounded, color: kc.muted),
                  filled: true,
                  fillColor: kc.surfaceAlt,
                  border: OutlineInputBorder(
                    borderRadius: AppRadius.inputBorder,
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const Key('bible-search-go'),
                  onPressed: _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.buttonBorder,
                    ),
                  ),
                  child: Text(
                    'Go',
                    style: AppTypography.ui(
                      size: 15,
                      weight: FontWeight.w700,
                      color: AppColors.onPrimary,
                    ),
                  ),
                ),
              ),
            ],
          ),
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
    final purple = context.kc.onChip;
    return Semantics(
      button: true,
      label: 'Change Bible version',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        // 44 px tall hit area around the 30 px pill.
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              border: Border.all(color: purple, width: 1),
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
                    color: purple,
                  ),
                ),
                const SizedBox(width: 3),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: purple,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Renders passage blocks with superscript verse numbers, poetry indents,
/// headings, and superscriptions — all in Newsreader serif for a calm,
/// scripture-forward reading tone. Verses in [highlight] get a soft tint and
/// the block where the first of them starts carries [verseKey] so the reader
/// can scroll to it.
class _PassageBody extends StatelessWidget {
  const _PassageBody({
    required this.blocks,
    required this.verseKey,
    this.highlight,
  });

  final List<PassageBlock> blocks;
  final GlobalKey verseKey;

  /// First and last verse to highlight, inclusive.
  final (int, int)? highlight;

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

    final highlight = this.highlight;
    bool lit(int? verse) =>
        highlight != null &&
        verse != null &&
        verse >= highlight.$1 &&
        verse <= highlight.$2;
    final litStyle = TextStyle(backgroundColor: context.kc.chipBg);
    // Highlighted verse numbers sit in the text run (not a superscript
    // widget) so the tint runs through them; the height multiplier gives the
    // smaller number the same line box as the body, so the tint is full-line.
    final litVerseStyle = verseStyle.copyWith(
      color: context.kc.onChip,
      backgroundColor: context.kc.chipBg,
      height: bodyStyle.fontSize! * bodyStyle.height! / verseStyle.fontSize!,
    );

    // Text before a block's first verse label continues the previous verse.
    int? verse;
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
      var startsHighlight = false;
      for (final seg in block.segments) {
        if (seg.verse != null) {
          verse = seg.verse;
          if (highlight != null && verse == highlight.$1) {
            startsHighlight = true;
          }
          spans.add(
            lit(verse)
                ? TextSpan(text: '${seg.verse}\u00A0', style: litVerseStyle)
                : WidgetSpan(
                    alignment: PlaceholderAlignment.top,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Text('${seg.verse}', style: verseStyle),
                    ),
                  ),
          );
        }
        if (seg.text.isNotEmpty) {
          spans.add(
            TextSpan(text: '${seg.text} ', style: lit(verse) ? litStyle : null),
          );
        }
      }
      final paragraph = Padding(
        padding: EdgeInsets.only(
          left: block.poetryIndent * 18.0,
          bottom: block.styleClass.startsWith('q') ? 0 : 14,
        ),
        child: Text.rich(TextSpan(style: bodyStyle, children: spans)),
      );
      children.add(
        startsHighlight
            ? KeyedSubtree(key: verseKey, child: paragraph)
            : paragraph,
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
              Icon(
                Icons.self_improvement_rounded,
                color: context.kc.accentInk,
                size: 16,
              ),
              const SizedBox(width: 7),
              Text(
                'DAILY PRAYER',
                style: AppTypography.ui(
                  size: 11,
                  weight: FontWeight.w700,
                  letterSpacing: 11 * 0.09,
                  color: context.kc.accentInk,
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
                color: read ? AppColors.onPrimary : context.kc.onChip,
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
      color: context.kc.onChip,
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
