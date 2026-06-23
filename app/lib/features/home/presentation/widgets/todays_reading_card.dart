import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/shared/providers/sermon_provider.dart';

/// Gold/purple gradient card showing today's Bible reading with Read + Listen.
class TodaysReadingCard extends ConsumerWidget {
  const TodaysReadingCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contentAsync = ref.watch(dailyContentProvider);

    return contentAsync.when(
      loading: () => _ReadingCard(
        plan: 'Devotional Plan',
        reference: 'Loading...',
        theme: '',
        verse: '',
      ),
      error: (_, _) => _ReadingCard(
        plan: 'Devotional Plan',
        reference: 'Psalms 23:1-6',
        theme: 'Psalm 23:1',
        verse:
            'Lord, thank You for being my Shepherd. Lead me today in paths of righteousness.',
      ),
      data: (content) => _ReadingCard(
        plan: 'Devotional Plan',
        reference: content.reading.reference,
        theme: content.prayerReference,
        verse: content.prayer,
      ),
    );
  }
}

class _ReadingCard extends StatelessWidget {
  const _ReadingCard({
    required this.plan,
    required this.reference,
    required this.theme,
    required this.verse,
  });

  final String plan;
  final String reference;
  final String theme;
  final String verse;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0x33E9C349),
          width: 1,
        ),
        gradient: const LinearGradient(
          begin: Alignment(-1, -1),
          end: Alignment(1, 1),
          colors: [
            Color(0x24E9C349),
            Color(0x1A7C3AED),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: "TODAY'S READING" label + plan right
          Row(
            children: [
              const Icon(
                Icons.menu_book_rounded,
                color: AppColors.secondary,
                size: 15,
              ),
              const SizedBox(width: 7),
              Text(
                "TODAY'S READING",
                style: AppTypography.labelMd.copyWith(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.secondary,
                  letterSpacing: 1.1,
                  height: 1,
                ),
              ),
              const Spacer(),
              Text(
                plan,
                style: AppTypography.labelMd.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textMuted,
                  letterSpacing: 0,
                  height: 1,
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Reference (big heading)
          Text(
            reference,
            style: AppTypography.titleMd.copyWith(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.heading,
              letterSpacing: -0.3,
              height: 1.2,
            ),
          ),

          if (theme.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(
              theme,
              style: AppTypography.bodySm.copyWith(
                fontSize: 13.5,
                fontWeight: FontWeight.w400,
                color: const Color(0xFFCFC8D4),
                height: 1.4,
              ),
            ),
          ],

          if (verse.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              verse,
              style: AppTypography.bodySm.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                fontStyle: FontStyle.italic,
                color: AppColors.onSurfaceVariant,
                height: 1.5,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],

          const SizedBox(height: 18),

          // Action buttons
          Row(
            children: [
              // Read button (gold pill)
              GestureDetector(
                onTap: () => context.push('/reading'),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.secondary,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.menu_book_rounded,
                        color: AppColors.onSecondary,
                        size: 15,
                      ),
                      const SizedBox(width: 7),
                      Text(
                        'Read',
                        style: AppTypography.labelMd.copyWith(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.onSecondary,
                          letterSpacing: 0,
                          height: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 10),

              // Listen button (glass pill)
              GestureDetector(
                onTap: () => context.push('/reading'),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .06),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: .08),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.play_arrow_rounded,
                        color: AppColors.heading,
                        size: 15,
                      ),
                      const SizedBox(width: 7),
                      Text(
                        'Listen',
                        style: AppTypography.labelMd.copyWith(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.heading,
                          letterSpacing: 0,
                          height: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
