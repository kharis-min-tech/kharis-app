import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/shared/providers/sermon_provider.dart';

/// Purple gradient card showing today's Bible reading with a serif scripture
/// line and Read now / Daily prayer actions (design-handoff v3, light screen).
class TodaysReadingCard extends ConsumerWidget {
  const TodaysReadingCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contentAsync = ref.watch(dailyContentProvider);

    return contentAsync.when(
      loading: () => _ReadingCard(
        reference: 'Loading...',
        theme: '',
        verse: '',
      ),
      error: (_, _) => _ReadingCard(
        reference: 'Psalms 23:1-6',
        theme: 'Psalm 23:1',
        verse:
            'Lord, thank You for being my Shepherd. Lead me today in paths of righteousness.',
      ),
      data: (content) => _ReadingCard(
        reference: content.reading.reference,
        theme: content.prayerReference,
        verse: content.prayer,
      ),
    );
  }
}

class _ReadingCard extends StatelessWidget {
  const _ReadingCard({
    required this.reference,
    required this.theme,
    required this.verse,
  });

  final String reference;
  final String theme;
  final String verse;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final dayOfYear = now.difference(DateTime(now.year)).inDays + 1;
    final scripture = verse.isNotEmpty ? verse : theme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: AppShadows.card,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primaryDeep],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Eyebrow: TODAY'S READING · DAY N
          Text(
            "TODAY'S READING · DAY $dayOfYear",
            style: AppTypography.ui(
              size: 10.5,
              weight: FontWeight.w800,
              letterSpacing: 1.1,
            ).copyWith(color: AppColors.secondary, height: 1),
          ),

          const SizedBox(height: 12),

          // Reference (big display heading)
          Text(
            reference,
            style: AppTypography.display(size: 27, weight: FontWeight.w700)
                .copyWith(color: Colors.white, height: 1.1),
          ),

          // Scripture / prayer line (serif italic)
          if (scripture.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              scripture,
              style: AppTypography.serif(size: 15.5, italic: true).copyWith(
                color: Colors.white.withValues(alpha: .88),
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
              // Read now (gold pill)
              GestureDetector(
                onTap: () => context.push('/reading'),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.secondary,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Read now',
                        style: AppTypography.ui(
                          size: 13.5,
                          weight: FontWeight.w800,
                        ).copyWith(color: AppColors.onSecondary, height: 1),
                      ),
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        color: AppColors.onSecondary,
                        size: 15,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 10),

              // Daily prayer (translucent pill)
              GestureDetector(
                onTap: () => context.push('/reading'),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .14),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: .18),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    'Daily prayer',
                    style: AppTypography.ui(
                      size: 13.5,
                      weight: FontWeight.w700,
                    ).copyWith(color: Colors.white, height: 1),
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
