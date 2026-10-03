import 'package:flutter/material.dart';
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

/// Purple gradient card showing today's Bible reading with a serif scripture
/// line and Read now / Daily prayer actions (design-handoff v3, light screen).
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
        theme: content.prayerReference,
        verse: content.prayer,
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
              filled: true,
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
          _GlassBar(width: 190, height: 26),
          SizedBox(height: 14),
          _GlassBar(width: double.infinity, height: 14),
          SizedBox(height: 8),
          _GlassBar(width: 220, height: 14),
          SizedBox(height: 20),
          Row(
            children: [
              _GlassBar(width: 112, height: 38, radius: AppRadius.pill),
              SizedBox(width: 10),
              _GlassBar(width: 112, height: 38, radius: AppRadius.pill),
            ],
          ),
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

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.onTap,
    this.icon,
    this.filled = false,
  });

  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final ink = filled ? AppColors.onSecondary : Colors.white;
    final icon = this.icon;
    return Semantics(
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
          decoration: BoxDecoration(
            color: filled
                ? AppColors.secondary
                : Colors.white.withValues(alpha: .14),
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: filled
                ? null
                : Border.all(color: Colors.white.withValues(alpha: .18)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: AppTypography.ui(
                  size: 13.5,
                  weight: filled ? FontWeight.w800 : FontWeight.w700,
                ).copyWith(color: ink, height: 1),
              ),
              if (icon != null) ...[
                const SizedBox(width: 6),
                Icon(icon, color: ink, size: 15),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The card's brand surface: deep purple base, radial wash, dove watermark.
class _CardShell extends StatelessWidget {
  const _CardShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    // DecoratedBox carries the elevation because ClipRRect cannot cast a
    // shadow through its clip.
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: AppShadows.card,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF2A1A6B), Color(0xFF0B0A12)],
                  ),
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(-0.75, -0.85),
                      radius: 1.1,
                      colors: [
                        AppColors.primary.withValues(alpha: 0.85),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.55],
                    ),
                  ),
                ),
              ),
            ),
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
    required this.theme,
    required this.verse,
  });

  final String reference;
  final String? dayLabel;
  final String theme;
  final String verse;

  @override
  Widget build(BuildContext context) {
    final scripture = verse.isNotEmpty ? verse : theme;
    final day = dayLabel;

    // Brand gradient (via _CardShell), identical in both themes, so its text
    // stays light regardless of the active brightness.
    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Eyebrow: TODAY'S READING · DAY N OF M (plan readings only)
          _Eyebrow(
            text: day == null
                ? "TODAY'S READING"
                : "TODAY'S READING \u00b7 ${day.toUpperCase()}",
          ),

          const SizedBox(height: 12),

          // Reference (big display heading)
          Text(
            reference,
            style: AppTypography.display(
              size: 27,
              weight: FontWeight.w700,
            ).copyWith(color: Colors.white, height: 1.1),
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
              _Pill(
                label: 'Read now',
                icon: Icons.arrow_forward_rounded,
                filled: true,
                onTap: () => context.push('/reading'),
              ),
              const SizedBox(width: 10),
              _Pill(
                label: 'Daily prayer',
                onTap: () => context.push('/reading'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
