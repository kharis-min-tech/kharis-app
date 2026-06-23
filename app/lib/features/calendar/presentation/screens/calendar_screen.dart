import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/features/calendar/data/event_repository.dart';
import 'package:kharis_app/shared/providers/sermon_provider.dart';

const _branchName = 'Kharis London';

class CalendarScreen extends ConsumerWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(upcomingEventsProvider(_branchName));

    return Scaffold(
      backgroundColor: AppColors.surfaceDark,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Header: pad 4 top, 20 sides
            const SliverPadding(
              padding: EdgeInsets.fromLTRB(20, 4, 20, 0),
              sliver: SliverToBoxAdapter(child: _Header()),
            ),

            eventsAsync.when(
              loading: () => const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 60),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: AppColors.secondary,
                      strokeWidth: 2,
                    ),
                  ),
                ),
              ),
              error: (_, _) => SliverToBoxAdapter(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 60),
                  child: Center(
                    child: Text(
                      'Unable to load events.',
                      style: AppTypography.bodySm.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                ),
              ),
              data: (events) {
                if (events.isEmpty) {
                  return SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 60, 20, 150),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.event_busy_outlined,
                            color: AppColors.textFaint,
                            size: 44,
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'No upcoming events',
                            style: AppTypography.bodySm.copyWith(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textMuted,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Check back soon for events at $_branchName.',
                            style: AppTypography.bodySm.copyWith(
                              fontSize: 13,
                              color: AppColors.textFaint,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 150),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _EventCard(event: events[index]),
                      ),
                      childCount: events.length,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ── Header ─────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Calendar',
          style: AppTypography.headlineLg.copyWith(
            fontSize: 30,
            fontWeight: FontWeight.w800,
            color: AppColors.heading,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Upcoming at $_branchName',
          style: AppTypography.bodySm.copyWith(
            fontSize: 13,
            color: AppColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

// ── Event card ─────────────────────────────────────────────────────────────────

class _EventCard extends StatelessWidget {
  const _EventCard({required this.event});

  final Event event;

  @override
  Widget build(BuildContext context) {
    final month = DateFormat('MMM').format(event.startTime).toUpperCase();
    final day = DateFormat('d').format(event.startTime);
    final time = DateFormat('h:mm a').format(event.startTime);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.06),
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg), // 16
      ),
      padding: const EdgeInsets.all(15),
      child: Row(
        children: [
          // Date block: fixed width 54
          SizedBox(
            width: 54,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  month,
                  style: AppTypography.labelMd.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.secondary,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  day,
                  style: AppTypography.headlineLg.copyWith(
                    fontSize: 25,
                    fontWeight: FontWeight.w800,
                    color: AppColors.heading,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),

          // Divider: 1px wide, white at 10%, height 42
          Container(
            width: 1,
            height: 42,
            margin: const EdgeInsets.symmetric(horizontal: 14),
            color: Colors.white.withValues(alpha: 0.1),
          ),

          // Title + time
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  style: AppTypography.bodySm.copyWith(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurface,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  time,
                  style: AppTypography.bodySm.copyWith(
                    fontSize: 12.5,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
