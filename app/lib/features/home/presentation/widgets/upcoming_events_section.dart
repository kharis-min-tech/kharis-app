import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kharis_app/core/theme/theme.dart';

import '../../../../features/calendar/data/event_repository.dart';
import '../../../../shared/providers/sermon_provider.dart';
import 'event_card.dart';

class UpcomingEventsSection extends ConsumerWidget {
  const UpcomingEventsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(upcomingEventsProvider(null));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Upcoming Events',
              style: GoogleFonts.mavenPro(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: () {},
              child: Text(
                'See All',
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.orange,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        eventsAsync.when(
          loading: () => const _EventShimmer(),
          error: (error, _) => _ErrorState(
            onRetry: () => ref.invalidate(upcomingEventsProvider(null)),
          ),
          data: (events) => events.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
                  child: Text(
                    'No upcoming events',
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      color: AppColors.textMuted,
                    ),
                  ),
                )
              : Column(
                  children: [
                    for (int i = 0; i < events.length; i++) ...[
                      if (i > 0) const SizedBox(height: AppSpacing.md),
                      EventCard(
                        day: _formatDay(events[i].startTime),
                        month: _formatMonth(events[i].startTime),
                        title: events[i].title,
                        location: events[i].location ?? '',
                        time: _formatTimeRange(events[i]),
                        onTap: () {},
                      ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  static const _monthNames = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static String _formatDay(DateTime dt) => dt.day.toString();
  static String _formatMonth(DateTime dt) => _monthNames[dt.month - 1];

  static String _formatTime(DateTime dt) {
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  static String _formatTimeRange(Event event) {
    final start = _formatTime(event.startTime);
    final end = _formatTime(event.endTime);
    return '$start - $end';
  }
}

// ── Loading shimmer ────────────────────────────────────────────────────────────

class _EventShimmer extends StatefulWidget {
  const _EventShimmer();

  @override
  State<_EventShimmer> createState() => _EventShimmerState();
}

class _EventShimmerState extends State<_EventShimmer>
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
    _opacity = Tween<double>(begin: 0.3, end: 0.65).animate(
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
          children: [
            _shimmerBox(76),
            const SizedBox(height: AppSpacing.md),
            _shimmerBox(76),
          ],
        );
      },
    );
  }

  Widget _shimmerBox(double height) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated.withValues(alpha: _opacity.value),
        borderRadius: AppRadius.cardBorder,
      ),
    );
  }
}

// ── Error state ────────────────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Could not load events',
            style: GoogleFonts.dmSans(
              fontSize: 14,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          GestureDetector(
            onTap: onRetry,
            child: Text(
              'Retry',
              style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.orange,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
