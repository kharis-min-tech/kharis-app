import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kharis_app/core/theme/theme.dart';

import '../../../../shared/providers/sermon_provider.dart';

class TodaysReadingCard extends ConsumerWidget {
  const TodaysReadingCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contentAsync = ref.watch(dailyContentProvider);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: AppRadius.cardBorder,
        border: const Border(
          left: BorderSide(color: AppColors.orange, width: 4),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Text(
                  "TODAY'S READING",
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.orange,
                    letterSpacing: 0.8,
                  ),
                ),
                const Spacer(),
                const Icon(
                  Icons.menu_book_rounded,
                  size: 16,
                  color: AppColors.orange,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            // Content
            contentAsync.when(
              loading: () => _ReadingPlaceholder(),
              error: (_, _) => Text(
                'Reading unavailable',
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  color: AppColors.textMuted,
                ),
              ),
              data: (content) {
                final reading = content.reading;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${reading.book} ${reading.chapter}',
                      style: GoogleFonts.mavenPro(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Verses ${reading.verse}',
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: AppColors.textBody,
                        fontStyle: FontStyle.italic,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    GestureDetector(
                      onTap: () {},
                      child: Text(
                        'Read full passage \u2192',
                        style: GoogleFonts.dmSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.orange,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ── Loading placeholder ────────────────────────────────────────────────────────

class _ReadingPlaceholder extends StatefulWidget {
  @override
  State<_ReadingPlaceholder> createState() => _ReadingPlaceholderState();
}

class _ReadingPlaceholderState extends State<_ReadingPlaceholder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _opacity = Tween<double>(begin: 0.2, end: 0.5).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _opacity,
      builder: (context, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _line(140, 20),
            const SizedBox(height: AppSpacing.xs),
            _line(80, 14),
            const SizedBox(height: AppSpacing.md),
            _line(100, 13),
          ],
        );
      },
    );
  }

  Widget _line(double width, double height) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.orange.withValues(alpha: _opacity.value),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}
