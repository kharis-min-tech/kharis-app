import 'package:add_2_calendar_new/add_2_calendar_new.dart' as add2cal;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/features/calendar/data/event_repository.dart';
import 'package:kharis_app/shared/providers/sermon_provider.dart';
import 'package:kharis_app/shared/providers/auth_provider.dart';

/// Events tab (design-handoff v3) — light screen. Segmented Upcoming / Past /
/// My RSVPs tabs, a branch selector, and event cards with a photo banner, an
/// overlaid date chip, title/time/location, and RSVP + Add-to-calendar actions.
class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

enum _EventTab { upcoming, past, rsvps }

/// Date-chip accent colours cycled per card (mirrors the prototype palette).
const List<Color> _accentPalette = [
  AppColors.primary, // purple
  Color(0xFFB91C5C), // rose
  Color(0xFFE09B1F), // gold-deep
  Color(0xFF137A6D), // teal
];

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  _EventTab _tab = _EventTab.upcoming;

  @override
  Widget build(BuildContext context) {
    final userBranch = ref.watch(currentUserProvider).valueOrNull?.branch;
    final branchName = userBranch ?? 'Kharis London';
    final eventsAsync = ref.watch(upcomingEventsProvider(branchName));

    return Scaffold(
      backgroundColor: AppColors.lightBg,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Header(branchName: branchName),
                    const SizedBox(height: 16),
                    _SegmentedTabs(
                      selected: _tab,
                      onChanged: (t) => setState(() => _tab = t),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
            if (_tab == _EventTab.upcoming)
              eventsAsync.when(
                loading: () => const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 60),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                        strokeWidth: 2,
                      ),
                    ),
                  ),
                ),
                error: (_, _) => _messageSliver(
                  icon: Icons.error_outline_rounded,
                  title: 'Unable to load events',
                  subtitle: 'Please check your connection and try again.',
                ),
                data: (events) {
                  if (events.isEmpty) {
                    return _messageSliver(
                      icon: Icons.event_busy_outlined,
                      title: 'No upcoming events',
                      subtitle: 'Check back soon for events at $branchName.',
                    );
                  }
                  return SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 150),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: _EventCard(
                            event: events[index],
                            accent: _accentPalette[index % _accentPalette.length],
                          ),
                        ),
                        childCount: events.length,
                      ),
                    ),
                  );
                },
              )
            else if (_tab == _EventTab.past)
              _messageSliver(
                icon: Icons.history_rounded,
                title: 'No past events',
                subtitle: 'Events you\u2019ve attended will appear here.',
              )
            else
              _messageSliver(
                icon: Icons.check_circle_outline_rounded,
                title: 'No RSVPs yet',
                subtitle: 'Events you RSVP to will show up here.',
              ),
          ],
        ),
      ),
    );
  }

  Widget _messageSliver({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 60, 20, 150),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppColors.textMutedLight, size: 44),
            const SizedBox(height: 14),
            Text(
              title,
              style: AppTypography.ui(size: 15, weight: FontWeight.w600)
                  .copyWith(color: AppColors.textPrimary),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: AppTypography.ui(size: 13)
                  .copyWith(color: AppColors.textMutedLight),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Header ───────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.branchName});

  final String branchName;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            'Events',
            style: AppTypography.display(size: 27, weight: FontWeight.w700)
                .copyWith(color: AppColors.textPrimary),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.cardWhite,
            borderRadius: AppRadius.pillBorder,
            boxShadow: AppShadows.card,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                branchName,
                style: AppTypography.ui(size: 13, weight: FontWeight.w600)
                    .copyWith(color: AppColors.primary),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.keyboard_arrow_down_rounded,
                  size: 16, color: AppColors.primary),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Segmented tabs ────────────────────────────────────────────────────────────

class _SegmentedTabs extends StatelessWidget {
  const _SegmentedTabs({required this.selected, required this.onChanged});

  final _EventTab selected;
  final ValueChanged<_EventTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _TabChip(
          label: 'Upcoming',
          active: selected == _EventTab.upcoming,
          onTap: () => onChanged(_EventTab.upcoming),
        ),
        const SizedBox(width: 9),
        _TabChip(
          label: 'Past',
          active: selected == _EventTab.past,
          onTap: () => onChanged(_EventTab.past),
        ),
        const SizedBox(width: 9),
        _TabChip(
          label: 'My RSVPs',
          active: selected == _EventTab.rsvps,
          onTap: () => onChanged(_EventTab.rsvps),
        ),
      ],
    );
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : const Color(0xFFF0ECEA),
          borderRadius: AppRadius.pillBorder,
        ),
        child: Text(
          label,
          style: AppTypography.ui(
            size: 13,
            weight: active ? FontWeight.w700 : FontWeight.w600,
          ).copyWith(
            color: active ? AppColors.onPrimary : AppColors.textMutedLight,
          ),
        ),
      ),
    );
  }
}

// ── Event card ─────────────────────────────────────────────────────────────────

class _EventCard extends StatelessWidget {
  const _EventCard({required this.event, required this.accent});

  final Event event;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final day = DateFormat('d').format(event.startTime);
    final month = DateFormat('MMM').format(event.startTime).toUpperCase();
    final weekday = DateFormat('EEE').format(event.startTime);
    final time = DateFormat('h:mm a').format(event.startTime);
    final whenText = '$weekday \u00b7 $time';
    final place = event.location ?? event.branch ?? '';

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: AppRadius.cardBorder,
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Photo banner with overlaid date chip.
          Stack(
            children: [
              SizedBox(
                height: 104,
                width: double.infinity,
                child: _banner(),
              ),
              Positioned(
                top: 11,
                left: 11,
                child: _DateChip(day: day, month: month, color: accent),
              ),
            ],
          ),

          // Title + time + location.
          Padding(
            padding: const EdgeInsets.fromLTRB(15, 14, 15, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  style: AppTypography.ui(
                    size: 15.5,
                    weight: FontWeight.w700,
                    height: 1.15,
                  ).copyWith(color: AppColors.textPrimary),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                _InfoRow(icon: Icons.schedule_rounded, text: whenText),
                if (place.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  _InfoRow(icon: Icons.place_outlined, text: place),
                ],
              ],
            ),
          ),

          // Split footer: RSVP | Add to calendar.
          DecoratedBox(
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.dividerLight)),
            ),
            child: IntrinsicHeight(
              child: Row(
                children: [
                  Expanded(
                    child: _FooterAction(
                      label: 'RSVP',
                      color: AppColors.primary,
                      onTap: () => _rsvp(context),
                    ),
                  ),
                  const VerticalDivider(
                    width: 1,
                    thickness: 1,
                    color: AppColors.dividerLight,
                  ),
                  Expanded(
                    child: _FooterAction(
                      label: 'Add to calendar',
                      color: AppColors.textMutedLight,
                      onTap: () => _addToCalendar(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _banner() {
    final fallback = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: 0.85),
            AppColors.primaryDeep,
          ],
        ),
      ),
    );
    final url = event.imageUrl;
    if (url == null || url.isEmpty) return fallback;
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      placeholder: (_, _) => fallback,
      errorWidget: (_, _, _) => fallback,
    );
  }

  void _rsvp(BuildContext context) {
    _showToast(context, 'You\u2019re going to ${event.title} \ud83c\udf89');
  }

  Future<void> _addToCalendar(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final calEvent = add2cal.Event(
      title: event.title,
      description: event.description,
      location: event.location,
      startDate: event.startTime,
      endDate: event.endTime,
    );
    try {
      await add2cal.Add2Calendar.addEvent2Cal(calEvent);
    } catch (_) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(_toast('Couldn\u2019t open your calendar.'));
    }
  }
}

class _DateChip extends StatelessWidget {
  const _DateChip({
    required this.day,
    required this.month,
    required this.color,
  });

  final String day;
  final String month;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26000000),
            offset: Offset(0, 2),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            day,
            style: AppTypography.ui(size: 18, weight: FontWeight.w700, height: 1)
                .copyWith(color: color),
          ),
          Text(
            month,
            style: AppTypography.ui(
              size: 9,
              weight: FontWeight.w600,
              letterSpacing: 0.4,
            ).copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 13, color: AppColors.textMutedLight),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            text,
            style: AppTypography.ui(size: 12.5)
                .copyWith(color: AppColors.textMutedLight),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _FooterAction extends StatelessWidget {
  const _FooterAction({
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: Text(
            label,
            style: AppTypography.ui(size: 13, weight: FontWeight.w700)
                .copyWith(color: color),
          ),
        ),
      ),
    );
  }
}

// ── Toast ─────────────────────────────────────────────────────────────────────

void _showToast(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(_toast(message));
}

SnackBar _toast(String message) => SnackBar(
      content: Text(
        message,
        style: AppTypography.ui(size: 14, weight: FontWeight.w600)
            .copyWith(color: Colors.white),
      ),
      backgroundColor: AppColors.darkSurface,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      duration: const Duration(milliseconds: 1900),
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 90),
    );
