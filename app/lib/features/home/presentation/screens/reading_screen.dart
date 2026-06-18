import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:kharis_app/core/theme/app_colors.dart';
import 'package:kharis_app/core/theme/app_spacing.dart';
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

/// Full-screen reader for today's Bible reading with version switching.
class ReadingScreen extends ConsumerWidget {
  const ReadingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contentAsync = ref.watch(dailyContentProvider);

    return Scaffold(
      backgroundColor: AppColors.surfaceDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: AppColors.onSurface),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          "Today's Reading",
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.1,
            color: AppColors.textMuted,
          ),
        ),
        centerTitle: true,
      ),
      body: contentAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.secondary),
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
          );
        },
      ),
    );
  }
}

class _PassageView extends ConsumerWidget {
  const _PassageView({required this.usfmId, required this.fallbackReference});

  final String usfmId;
  final String fallbackReference;

  void _showVersionSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surfaceElevated,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
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
                  padding: EdgeInsets.all(AppSpacing.lg),
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.secondary),
                  ),
                ),
                error: (_, _) => Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Text(
                    'Could not load versions',
                    style: GoogleFonts.plusJakartaSans(color: AppColors.onSurfaceVariant),
                  ),
                ),
                data: (bibles) => ListView(
                  shrinkWrap: true,
                  padding:
                      const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg),
                      child: Text(
                        'BIBLE VERSION',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.1,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    for (final b in bibles)
                      ListTile(
                        dense: true,
                        title: Text(
                          b.abbreviation,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: b.id == selected.id
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: b.id == selected.id
                                ? AppColors.secondary
                                : AppColors.onSurface,
                          ),
                        ),
                        subtitle: Text(
                          b.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                        trailing: b.id == selected.id
                            ? const Icon(Icons.check_rounded,
                                color: AppColors.secondary, size: 20)
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
        child: CircularProgressIndicator(color: AppColors.secondary),
      ),
      error: (_, _) => _ErrorView(
        message: 'Could not load the passage in ${version.abbreviation}',
        onRetry: () => ref.invalidate(passageProvider(
          (usfm: usfmId, bibleId: version.id, abbrev: version.abbreviation),
        )),
      ),
      data: (passage) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl, AppSpacing.md, AppSpacing.xl, AppSpacing.xl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    passage.reference.isNotEmpty
                        ? passage.reference
                        : fallbackReference,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: AppColors.onSurface,
                    ),
                  ),
                ),
                Semantics(
                  button: true,
                  label: 'Change Bible version',
                  child: GestureDetector(
                    onTap: () => _showVersionSheet(context, ref),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md, vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.secondary, width: 1),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            passage.bibleAbbreviation,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.secondary,
                            ),
                          ),
                          const SizedBox(width: 3),
                          const Icon(Icons.keyboard_arrow_down_rounded,
                              color: AppColors.secondary, size: 16),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            _PassageBody(blocks: passage.blocks),
            if (passage.copyright != null &&
                passage.copyright!.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.lg),
              Text(
                passage.copyright!,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  color: AppColors.textMuted,
                  height: 1.5,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Renders passage blocks with superscript verse numbers, poetry indents,
/// headings, and superscriptions.
class _PassageBody extends StatelessWidget {
  const _PassageBody({required this.blocks});

  final List<PassageBlock> blocks;

  @override
  Widget build(BuildContext context) {
    final bodyStyle = GoogleFonts.plusJakartaSans(
      fontSize: 17,
      height: 1.8,
      color: AppColors.onSurface.withValues(alpha: 0.92),
    );
    final verseStyle = GoogleFonts.plusJakartaSans(
      fontSize: 11,
      height: 1.8,
      fontWeight: FontWeight.w700,
      color: AppColors.primary,
    );

    final children = <Widget>[];
    for (final block in blocks) {
      if (block.isHeading) {
        children.add(Padding(
          padding: const EdgeInsets.only(
            top: AppSpacing.lg, bottom: AppSpacing.sm,
          ),
          child: Text(
            block.segments.map((s) => s.text).join(' '),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.onSurface,
            ),
          ),
        ));
        continue;
      }
      if (block.isSuperscription) {
        children.add(Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: Text(
            block.segments.map((s) => s.text).join(' '),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontStyle: FontStyle.italic,
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ));
        continue;
      }

      final spans = <InlineSpan>[];
      for (final seg in block.segments) {
        if (seg.verse != null) {
          spans.add(TextSpan(text: '${seg.verse} ', style: verseStyle));
        }
        if (seg.text.isNotEmpty) {
          spans.add(TextSpan(text: '${seg.text} '));
        }
      }
      children.add(Padding(
        padding: EdgeInsets.only(
          left: block.poetryIndent * 18.0,
          bottom: block.styleClass.startsWith('q') ? 0 : AppSpacing.md,
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
          const Icon(Icons.menu_book_rounded,
              color: AppColors.textMuted, size: 40),
          const SizedBox(height: AppSpacing.md),
          Text(
            message,
            style: GoogleFonts.plusJakartaSans(
              color: AppColors.onSurfaceVariant, fontSize: 14,
            ),
          ),
          TextButton(
            onPressed: onRetry,
            child: Text(
              'Retry',
              style: GoogleFonts.plusJakartaSans(
                color: AppColors.secondary, fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
