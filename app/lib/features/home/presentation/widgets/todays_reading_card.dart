import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kharis_app/core/constants/app_assets.dart';
import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/features/home/data/daily_content_repository.dart';
import 'package:kharis_app/shared/providers/sermon_provider.dart';

/// Eyebrow for the reading card and reader: "DAY 3 OF 13" when the reading
/// comes from a plan, otherwise no day at all (a hand-written day has no
/// plan position, and the day of the year is not a reading-plan day).
String? readingPlanDayLabel(DailyContent content) {
  final day = content.planDay;
  if (day == null) return null;
  final total = content.planDays;
  return total == null ? 'Day $day' : 'Day $day of $total';
}

/// Today's Bible reading on the brand ink card: the reference as the
/// headline, the plan position when the reading comes from a plan, the
/// daily prayer beneath, and one Read now action. The whole card opens the
/// reader.
///
/// Loading shows a skeleton of the card; a failure says so and offers Retry.
/// It never paints a made-up reading in place of the real one.
class TodaysReadingCard extends ConsumerWidget {
  const TodaysReadingCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contentAsync = ref.watch(dailyContentProvider);
    final content = contentAsync.valueOrNull;

    if (content != null) {
      return _ReadingCard(
        reference: content.reading.reference,
        dayLabel: readingPlanDayLabel(content),
        planDay: content.planDay,
        planDays: content.planDays,
        prayerReference: content.prayerReference,
        prayer: content.prayer,
      );
    }
    if (contentAsync.hasError) {
      return _CardShell(
        key: const Key('reading-card-error'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _Eyebrow(text: "TODAY'S READING"),
            const SizedBox(height: 12),
            Text(
              'We couldn\u2019t load today\u2019s reading.',
              style: AppTypography.display(
                size: 21,
                weight: FontWeight.w700,
              ).copyWith(color: Colors.white, height: 1.2),
            ),
            const SizedBox(height: 6),
            Text(
              'Check your connection and try again.',
              style: AppTypography.ui(
                size: 13.5,
              ).copyWith(color: Colors.white.withValues(alpha: .8)),
            ),
            const SizedBox(height: 16),
            _Pill(
              label: 'Retry',
              icon: Icons.refresh_rounded,
              onTap: () => ref.invalidate(dailyContentProvider),
            ),
          ],
        ),
      );
    }
    return const _CardShell(
      key: Key('reading-card-loading'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _GlassBar(width: 140, height: 11),
          SizedBox(height: 14),
          _GlassBar(width: 190, height: 28),
          SizedBox(height: 30),
          _GlassBar(width: 150, height: 10),
          SizedBox(height: 10),
          _GlassBar(width: double.infinity, height: 14),
          SizedBox(height: 8),
          _GlassBar(width: 220, height: 14),
          SizedBox(height: 20),
          _GlassBar(width: 120, height: 38, radius: AppRadius.pill),
        ],
      ),
    );
  }
}

/// Translucent placeholder bar that reads on the purple card in both themes
/// (the shared Skeleton's surface tint would be invisible here). Static on
/// purpose: the card is small and a pulse adds nothing but motion.
class _GlassBar extends StatelessWidget {
  const _GlassBar({required this.width, required this.height, this.radius = 6});

  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

class _Eyebrow extends StatelessWidget {
  const _Eyebrow({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTypography.ui(
        size: 10.5,
        weight: FontWeight.w800,
        letterSpacing: 1.1,
      ).copyWith(color: AppColors.secondary, height: 1),
    );
  }
}

/// The card's gold action pill.
class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.icon, required this.onTap});

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const ink = AppColors.onSecondary;
    return Semantics(
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
          decoration: BoxDecoration(
            color: AppColors.secondary,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: AppTypography.ui(
                  size: 13.5,
                  weight: FontWeight.w800,
                ).copyWith(color: ink, height: 1),
              ),
              const SizedBox(width: 6),
              Icon(icon, color: ink, size: 15),
            ],
          ),
        ),
      ),
    );
  }
}

/// The card's brand surface: solid deep purple and a dove watermark.
class _CardShell extends StatelessWidget {
  const _CardShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    // DecoratedBox carries the elevation because ClipRRect cannot cast a
    // shadow through its clip.
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.primaryDeep,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: AppShadows.card,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Stack(
          children: [
            Positioned(
              right: -14,
              top: -10,
              child: Opacity(
                opacity: 0.12,
                child: Image.asset(AppAssets.doveWhite, width: 96),
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}

class _ReadingCard extends StatelessWidget {
  const _ReadingCard({
    required this.reference,
    required this.dayLabel,
    required this.planDay,
    required this.planDays,
    required this.prayerReference,
    required this.prayer,
  });

  final String reference;
  final String? dayLabel;
  final int? planDay;
  final int? planDays;
  final String prayerReference;
  final String prayer;

  @override
  Widget build(BuildContext context) {
    final day = dayLabel;
    final prayer = this.prayer.trim();
    final prayerRef = prayerReference.trim();
    final planDay = this.planDay;
    final planDays = this.planDays;
    void open() => context.push('/reading');

    // Brand fill (via _CardShell), identical in both themes, so its text
    // stays light regardless of the active brightness.
    return Semantics(
      button: true,
      label: "Today's reading: $reference. Read now",
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: open,
        child: _CardShell(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // TODAY'S READING · DAY N OF M (plan readings only), and the
              // date the reading is for.
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _Eyebrow(
                      text: day == null
                          ? "TODAY'S READING"
                          : "TODAY'S READING \u00b7 ${day.toUpperCase()}",
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Clear of the dove watermark in the corner.
                  Padding(
                    padding: const EdgeInsets.only(right: 44),
                    child: Text(
                      DateFormat('EEE d MMM').format(DateTime.now()),
                      style:
                          AppTypography.ui(
                            size: 11.5,
                            weight: FontWeight.w600,
                          ).copyWith(
                            color: Colors.white.withValues(alpha: .85),
                            height: 1,
                          ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // Reference (the headline)
              Text(
                reference,
                style: AppTypography.display(
                  size: 28,
                  weight: FontWeight.w700,
                ).copyWith(color: Colors.white, height: 1.1),
              ),

              // How far through the plan: real plan position only.
              if (planDay != null && planDays != null && planDays > 0) ...[
                const SizedBox(height: 12),
                _PlanProgress(fraction: (planDay / planDays).clamp(0.0, 1.0)),
              ],

              // Daily prayer (serif italic) under a hairline.
              if (prayer.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  height: 1,
                  color: Colors.white.withValues(alpha: .14),
                ),
                const SizedBox(height: 14),
                Text(
                  prayerRef.isEmpty
                      ? 'DAILY PRAYER'
                      : 'DAILY PRAYER \u00b7 ${prayerRef.toUpperCase()}',
                  style:
                      AppTypography.ui(
                        size: 10.5,
                        weight: FontWeight.w700,
                        letterSpacing: 1.0,
                      ).copyWith(
                        color: Colors.white.withValues(alpha: .85),
                        height: 1,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  prayer,
                  style: AppTypography.serif(size: 16, italic: true).copyWith(
                    color: Colors.white.withValues(alpha: .88),
                    height: 1.45,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],

              const SizedBox(height: 18),

              _Pill(
                label: 'Read now',
                icon: Icons.arrow_forward_rounded,
                onTap: open,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Plan position as a slim gold bar on a faint track (day N of M).
class _PlanProgress extends StatelessWidget {
  const _PlanProgress({required this.fraction});

  final double fraction;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: AppRadius.pillBorder,
      child: SizedBox(
        height: 3,
        width: double.infinity,
        child: ColoredBox(
          color: Colors.white.withValues(alpha: .14),
          child: Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: fraction,
              heightFactor: 1,
              child: const ColoredBox(color: AppColors.secondary),
            ),
          ),
        ),
      ),
    );
  }
}
