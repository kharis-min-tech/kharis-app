import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';

class _Event {
  const _Event({
    required this.day,
    required this.month,
    required this.title,
    required this.location,
    required this.time,
    this.isFeatured = false,
  });

  final String day;
  final String month;
  final String title;
  final String location;
  final String time;
  final bool isFeatured;
}

const _thisWeekEvents = [
  _Event(
    day: '08',
    month: 'JUN',
    title: 'Sunday Celebration Service',
    location: 'London — 12 Acton Street',
    time: 'Sun, 10:30am',
  ),
  _Event(
    day: '10',
    month: 'JUN',
    title: 'Midweek Prayer & Bible Study',
    location: 'Birmingham — Broad Street',
    time: 'Wed, 7:00pm',
  ),
  _Event(
    day: '12',
    month: 'JUN',
    title: 'Youth Night',
    location: 'Reading — Caversham Road',
    time: 'Fri, 6:30pm',
  ),
];

const _comingUpEvents = [
  _Event(
    day: '15',
    month: 'JUN',
    title: 'Kharis Leadership Summit 2026',
    location: 'London — 12 Acton Street',
    time: 'Sun, 10:00am',
    isFeatured: true,
  ),
  _Event(
    day: '22',
    month: 'JUN',
    title: 'Worship Night',
    location: 'Birmingham — Broad Street',
    time: 'Sun, 6:00pm',
  ),
];

const _branches = ['All Branches', 'London', 'Birmingham', 'Reading'];

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  String _selectedBranch = 'All Branches';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceDark,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHeader()),
            SliverToBoxAdapter(child: _buildBranchFilters()),
            SliverToBoxAdapter(child: _buildServiceTimesBar()),
            SliverToBoxAdapter(child: _buildSectionTitle('This Week')),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) => _buildEventCard(_thisWeekEvents[i]),
                childCount: _thisWeekEvents.length,
              ),
            ),
            SliverToBoxAdapter(child: _buildSectionTitle('Coming Up')),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) => _buildEventCard(_comingUpEvents[i]),
                childCount: _comingUpEvents.length,
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 96)),
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
        style: GoogleFonts.mavenPro(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
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
            onTap: () => setState(() => _selectedBranch = branch),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isActive ? Colors.transparent : AppColors.surfaceSubtle,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isActive ? AppColors.orange : Colors.transparent,
                  width: 1.5,
                ),
              ),
              child: Text(
                branch,
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                  color: isActive ? AppColors.orange : AppColors.textMuted,
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
            style: GoogleFonts.dmSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
              letterSpacing: 0.5,
            ),
          ),
          const Spacer(),
          _buildServiceDot(AppColors.orange),
          const SizedBox(width: 6),
          Text(
            'Sun 10:30am',
            style: GoogleFonts.dmSans(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(width: 16),
          _buildServiceDot(AppColors.purple),
          const SizedBox(width: 6),
          Text(
            'Wed 7:00pm',
            style: GoogleFonts.dmSans(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
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
        style: GoogleFonts.mavenPro(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }

  Widget _buildEventCard(_Event event) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: event.isFeatured
            ? const Border(
                left: BorderSide(color: AppColors.orange, width: 3),
              )
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDateBadge(event.day, event.month),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    style: GoogleFonts.mavenPro(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
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
                          event.location,
                          style: GoogleFonts.dmSans(
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
                        event.time,
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ],
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
            style: GoogleFonts.mavenPro(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.purple,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            month,
            style: GoogleFonts.dmSans(
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
}
