import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kharis_app/core/theme/theme.dart';

import '../../../../shared/providers/sermon_provider.dart';

class DailyPrayerCard extends ConsumerWidget {
  const DailyPrayerCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contentAsync = ref.watch(dailyContentProvider);

    return Container(
      decoration: BoxDecoration(
        borderRadius: AppRadius.cardBorder,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.purple.withValues(alpha: 0.15),
            AppColors.purple.withValues(alpha: 0.05),
          ],
        ),
        border: Border.all(
          color: AppColors.purple.withValues(alpha: 0.35),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Badge
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.purple.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.self_improvement_rounded,
                        size: 13,
                        color: AppColors.purple,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        'DAILY PRAYER',
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.purple,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            // Prayer content
            contentAsync.when(
              loading: () => _PrayerPlaceholder(),
              error: (_, _) => Text(
                'Prayer unavailable. Please try again later.',
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  color: AppColors.textMuted,
                  fontStyle: FontStyle.italic,
                  height: 1.65,
                ),
              ),
              data: (content) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '\u201c${content.prayer}\u201d',
                    style: GoogleFonts.dmSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textPrimary,
                      fontStyle: FontStyle.italic,
                      height: 1.65,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    '— ${content.prayerReference}',
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton(
                onPressed: () {},
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: AppColors.purple.withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.buttonBorder,
                  ),
                ),
                child: Text(
                  'PRAY WITH US',
                  style: GoogleFonts.mavenPro(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.purple,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Loading placeholder ────────────────────────────────────────────────────────

class _PrayerPlaceholder extends StatefulWidget {
  @override
  State<_PrayerPlaceholder> createState() => _PrayerPlaceholderState();
}

class _PrayerPlaceholderState extends State<_PrayerPlaceholder>
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
            _line(double.infinity, 14),
            const SizedBox(height: AppSpacing.sm),
            _line(double.infinity, 14),
            const SizedBox(height: AppSpacing.sm),
            _line(200, 14),
            const SizedBox(height: AppSpacing.md),
            _line(120, 12),
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
        color: AppColors.purple.withValues(alpha: _opacity.value),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}
