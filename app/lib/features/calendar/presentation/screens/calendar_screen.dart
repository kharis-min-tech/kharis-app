import 'package:add_2_calendar_new/add_2_calendar_new.dart' as cal;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:kharis_app/core/theme/app_colors.dart';
import 'package:kharis_app/features/calendar/data/event_repository.dart';
import 'package:kharis_app/core/theme/app_spacing.dart';
import 'package:kharis_app/shared/providers/sermon_provider.dart';
import 'package:kharis_app/shared/providers/cache_provider.dart';
import 'package:kharis_app/shared/widgets/skeleton.dart';

const _branches = ['All Branches', 'London', 'Birmingham', 'Reading'];

/// Calendar tab - realtime upcoming events from Firestore.
///
/// Events stream live: anything created in the admin panel appears here
/// without a refresh. Branch chips filter client-side via the provider.
class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  String _selectedBranch = 'All Branches';

  @override
  void initState() {
    super.initState();
    _selectedBranch = ref
        .read(cacheServiceProvider)
        .getPreference<String>('last_branch_filter', 'All Branches');
  }

  @override
  Widget build(BuildContext context) {
    final branchParam =
        _selectedBranch == 'All Branches' ? null : _selectedBranch;
    final eventsAsync = ref.watch(upcomingEventsProvider(branchParam));

    return Scaffold(
      backgroundColor: AppColors.surfaceDark,
      body: SafeArea(
        child: eventsAsync.when(
          loading: () => _buildLoadingSkeleton(),
          error: (_, _) => _buildScroll(const [], const []),
          data: (events) {
            final cutoff = DateTime.now().add(const Duration(days: 7));
            final thisWeek =
                events.where((e) => e.startTime.isBefore(cutoff)).toList();
            final comingUp =
                events.where((e) => !e.startTime.isBefore(cutoff)).toList();
            return _buildScroll(thisWeek, comingUp);
          },
        ),
      ),
    );
  }

  Widget _buildScroll(List<Event> thisWeek, List<Event> comingUp) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _buildHeader()),
        SliverToBoxAdapter(child: _buildBranchFilters()),
        SliverToBoxAdapter(child: _buildServiceTimesBar()),
        if (thisWeek.isEmpty && comingUp.isEmpty)
          SliverToBoxAdapter(child: _buildEmpty())
        else ...[
          if (thisWeek.isNotEmpty) ...[
            SliverToBoxAdapter(child: _buildSectionTitle('This Week')),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) => _buildEventCard(thisWeek[i]),
                childCount: thisWeek.length,
              ),
            ),
          ],
          if (comingUp.isNotEmpty) ...[
            SliverToBoxAdapter(child: _buildSectionTitle('Coming Up')),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) => _buildEventCard(comingUp[i]),
                childCount: comingUp.length,
              ),
            ),
          ],
        ],
        const SliverToBoxAdapter(child: SizedBox(height: 96)),
      ],
    );
  }

  Widget _buildEmpty() {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.event_busy_rounded,
                color: AppColors.textMuted, size: 40),
            const SizedBox(height: 12),
            Text(
              'No upcoming events for this branch',
              style: GoogleFonts.plusJakartaSans(
                color: AppColors.onSurfaceVariant,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
      child: Text(
        'Calendar',
        style: GoogleFonts.plusJakartaSans(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: AppColors.onSurface,
        ),
      ),
    );
  }

  Widget _buildBranchFilters() {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemCount: _branches.length,
        itemBuilder: (context, i) {
          final branch = _branches[i];
          final isActive = branch == _selectedBranch;
          return GestureDetector(
            onTap: () {
              ref
                  .read(cacheServiceProvider)
                  .cachePreference('last_branch_filter', branch);
              setState(() => _selectedBranch = branch);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isActive ? Colors.transparent : AppColors.surfaceSubtle,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isActive ? AppColors.secondary : Colors.transparent,
                  width: 1.5,
                ),
              ),
              child: Text(
                branch,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                  color: isActive ? AppColors.secondary : AppColors.textMuted,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildServiceTimesBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Text(
            'Service Times',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
              letterSpacing: 0.5,
            ),
          ),
          const Spacer(),
          _buildServiceDot(AppColors.primary),
          const SizedBox(width: 6),
          Text(
            'Sun 10:30am',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.onSurface,
            ),
          ),
          const SizedBox(width: 16),
          _buildServiceDot(AppColors.primary),
          const SizedBox(width: 6),
          Text(
            'Wed 7:00pm',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceDot(Color color) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
      child: Text(
        title,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.onSurface,
        ),
      ),
    );
  }

  Widget _buildEventCard(Event event) {
    final day = DateFormat('dd').format(event.startTime);
    final month = DateFormat('MMM').format(event.startTime).toUpperCase();
    final time = DateFormat('EEE, h:mma')
        .format(event.startTime)
        .replaceAll('AM', 'am')
        .replaceAll('PM', 'pm');

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: event.isFeatured
            ? const Border(
                left: BorderSide(color: AppColors.primary, width: 3),
              )
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDateBadge(day, month),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 12,
                        color: AppColors.textMuted,
                      ),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          event.location ?? 'Kharis Church',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      const Icon(
                        Icons.access_time_rounded,
                        size: 12,
                        color: AppColors.textMuted,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        time,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                cal.Add2Calendar.addEvent2Cal(
                  cal.Event(
                    title: event.title,
                    description: event.description ?? event.title,
                    location: event.location ?? 'Kharis Church',
                    startDate: event.startTime,
                    endDate: event.endTime,
                  ),
                );
              },
              child: const Icon(
                Icons.calendar_today_outlined,
                size: 20,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateBadge(String day, String month) {
    return Container(
      width: 44,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceSubtle,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            day,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            month,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppColors.textMuted,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingSkeleton() {
    return CustomScrollView(
      physics: const NeverScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(child: _buildHeader()),
        SliverToBoxAdapter(child: _buildBranchFilters()),
        SliverToBoxAdapter(child: _buildSectionTitle('This Week')),
        SliverList.separated(
          itemCount: 3,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (_, _) => _buildEventCardSkeleton(),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 96)),
      ],
    );
  }

  Widget _buildEventCardSkeleton() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Skeleton(width: 44, height: 44, radius: 8),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                SkeletonLine(width: double.infinity),
                SizedBox(height: AppSpacing.sm),
                SkeletonLine(width: 160),
              ],
            ),
          ),
        ],
      ),
    );
  }

}
