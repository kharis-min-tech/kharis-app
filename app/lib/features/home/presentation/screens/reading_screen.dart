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

/// Passage text for a USFM id, cached per id by the repository.
final passageProvider = FutureProvider.family<BiblePassage, String>(
  (ref, usfmId) => ref.watch(bibleRepositoryProvider).getPassage(usfmId),
);

/// Full-screen reader for today's Bible reading.
///
/// Resolves the reading from [dailyContentProvider], converts it to a USFM
/// passage id, and renders the NIV text from the YouVersion Platform API.
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
          icon: const Icon(Icons.close_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          "Today's Reading",
          style: GoogleFonts.dmSans(
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
          child: CircularProgressIndicator(color: AppColors.accent),
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final passageAsync = ref.watch(passageProvider(usfmId));

    return passageAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.accent),
      ),
      error: (_, _) => _ErrorView(
        message: 'Could not load the passage',
        onRetry: () => ref.invalidate(passageProvider(usfmId)),
      ),
      data: (passage) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl, AppSpacing.md, AppSpacing.xl, AppSpacing.xxxl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    passage.reference.isNotEmpty
                        ? passage.reference
                        : fallbackReference,
                    style: GoogleFonts.mavenPro(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md, vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.accent, width: 1),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    passage.bibleAbbreviation,
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.accent,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              passage.content,
              style: GoogleFonts.dmSans(
                fontSize: 17,
                height: 1.85,
                color: AppColors.textPrimary.withValues(alpha: 0.92),
              ),
            ),
            if (passage.copyright != null &&
                passage.copyright!.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xxl),
              Text(
                passage.copyright!,
                style: GoogleFonts.dmSans(
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
            style: GoogleFonts.dmSans(
              color: AppColors.textBody, fontSize: 14,
            ),
          ),
          TextButton(
            onPressed: onRetry,
            child: Text(
              'Retry',
              style: GoogleFonts.dmSans(
                color: AppColors.accent, fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
