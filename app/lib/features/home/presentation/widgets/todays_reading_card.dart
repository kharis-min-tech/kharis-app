import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kharis_app/core/constants/app_assets.dart';
import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/features/home/data/daily_content_repository.dart';
import 'package:kharis_app/shared/providers/sermon_provider.dart';

/// Today's Content Studio reading on the brand ink card: its title as the
/// headline, the reference, the start of the text, the daily prayer
/// beneath, and one Read now action. The whole card opens the reader. A day
/// with only a prayer shows the prayer alone.
///
/// Loading shows a skeleton of the card. It never paints a made-up reading:
/// when the Studio has nothing for today, or it cannot be reached, it shows
/// the way into the whole Bible instead ([_BibleCard]).
class TodaysReadingCard extends ConsumerWidget {
  const TodaysReadingCard({super.key, this.padding = EdgeInsets.zero});

  /// Space around the card, applied only when it shows.
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contentAsync = ref.watch(dailyContentProvider);
    final content = contentAsync.valueOrNull;
    final Widget card;
    if (content != null) {
      card = _ReadingCard(reading: content.reading, prayer: content.prayer);
    } else if (contentAsync.isLoading && !contentAsync.hasError) {
      card = const _CardShell(
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
    } else {
      // Nothing from the Studio today (or it cannot be reached): Home still
      // leads into Scripture, through the whole Bible.
      card = const _BibleCard();
    }
    return Padding(padding: padding, child: card);
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

/// The card's action, as the website's yellow button: square, with a hard
/// darker edge underneath.
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
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        // Vertical slack lifts the ~36 px pill to a 44 px tap target.
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: const ShapeDecoration(
              color: AppColors.secondary,
              shape: EdgedBorder(edge: AppColors.secondaryEdge),
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
  const _ReadingCard({required this.reading, required this.prayer});

  final DailyEntry? reading;
  final DailyEntry? prayer;

  @override
  Widget build(BuildContext context) {
    final reading = this.reading;
    final prayer = this.prayer;
    final faint = Colors.white.withValues(alpha: .85);
    void open() => context.push('/reading');

    // Brand fill (via _CardShell), identical in both themes, so its text
    // stays light regardless of the active brightness.
    final card = _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // TODAY'S READING (or PRAYER) and the date it is for.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _Eyebrow(
                  text: reading == null ? "TODAY'S PRAYER" : "TODAY'S READING",
                ),
              ),
              const SizedBox(width: 12),
              // Clear of the dove watermark in the corner.
              Padding(
                padding: const EdgeInsets.only(right: 44),
                child: Text(
                  DateFormat('EEE d MMM').format(DateTime.now()),
                  style: AppTypography.ui(
                    size: 11.5,
                    weight: FontWeight.w600,
                  ).copyWith(color: faint, height: 1),
                ),
              ),
            ],
          ),

          if (reading != null) ...[
            const SizedBox(height: 14),
            Text(
              reading.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.display(
                size: 26,
                weight: FontWeight.w700,
              ).copyWith(color: Colors.white, height: 1.15),
            ),
            if (reading.reference.isNotEmpty &&
                reading.reference != reading.title) ...[
              const SizedBox(height: 6),
              Text(
                reading.reference,
                style: AppTypography.ui(
                  size: 13.5,
                  weight: FontWeight.w700,
                ).copyWith(color: AppColors.secondary, height: 1.2),
              ),
            ],
            if (reading.body.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                reading.body,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.ui(
                  size: 14,
                ).copyWith(color: faint, height: 1.45),
              ),
            ],
          ],

          // Daily prayer (serif italic), under a hairline after a reading.
          if (prayer != null) ...[
            if (reading != null) ...[
              const SizedBox(height: 16),
              Container(height: 1, color: Colors.white.withValues(alpha: .14)),
            ],
            const SizedBox(height: 14),
            Text(
              prayer.reference.isEmpty
                  ? 'DAILY PRAYER'
                  : 'DAILY PRAYER \u00b7 ${prayer.reference.toUpperCase()}',
              style: AppTypography.ui(
                size: 10.5,
                weight: FontWeight.w700,
                letterSpacing: 1.0,
              ).copyWith(color: faint, height: 1),
            ),
            const SizedBox(height: 8),
            Text(
              prayer.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.ui(
                size: 15,
                weight: FontWeight.w700,
              ).copyWith(color: Colors.white, height: 1.3),
            ),
            if (prayer.body.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                prayer.body,
                style: AppTypography.serif(size: 16, italic: true).copyWith(
                  color: Colors.white.withValues(alpha: .88),
                  height: 1.45,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],

          const SizedBox(height: 14),
          _Pill(
            label: reading == null ? 'Pray now' : 'Read now',
            icon: Icons.arrow_forward_rounded,
            onTap: open,
          ),
        ],
      ),
    );

    // The whole card opens the reader; with only a prayer it shows the
    // prayer in full there.
    return Semantics(
      button: true,
      label: reading == null
          ? "Today's prayer: ${prayer?.title ?? ''}. Pray now"
          : "Today's reading: ${reading.title}. Read now",
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: open,
        child: card,
      ),
    );
  }
}

/// The way into the whole Bible when the Studio has no reading for today,
/// on the same brand card so Home always has Scripture in the same place.
class _BibleCard extends StatelessWidget {
  const _BibleCard();

  @override
  Widget build(BuildContext context) {
    void open() => context.push('/bible');
    return Semantics(
      button: true,
      label: 'Read the Bible',
      excludeSemantics: true,
      child: GestureDetector(
        key: const Key('reading-card-bible'),
        behavior: HitTestBehavior.opaque,
        onTap: open,
        child: _CardShell(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _Eyebrow(text: 'THE BIBLE'),
              const SizedBox(height: 14),
              Text(
                'Read the Bible',
                style: AppTypography.display(
                  size: 26,
                  weight: FontWeight.w700,
                ).copyWith(color: Colors.white, height: 1.15),
              ),
              const SizedBox(height: 8),
              Text(
                'Every book and chapter, in your translation.',
                style: AppTypography.ui(size: 14).copyWith(
                  color: Colors.white.withValues(alpha: .85),
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 16),
              _Pill(
                label: 'Open the Bible',
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
