import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/core/utils/service_time.dart';
import 'package:kharis_app/features/calendar/data/event_repository.dart';
import 'package:kharis_app/features/home/presentation/widgets/campus_card.dart';
import 'package:kharis_app/features/onboarding/data/branch_repository.dart';
import 'package:kharis_app/shared/models/campus_config.dart';
import 'package:kharis_app/shared/providers/campus_config_provider.dart';
import 'package:kharis_app/shared/providers/notification_feed_provider.dart';
import 'package:kharis_app/shared/widgets/press_effect.dart';

/// The clock the Next service card reads "now" from; overridden in tests.
final nextServiceClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

/// Weekdays (0 = Sunday ... 6 = Saturday) [branch] holds a service on.
Set<int> branchServiceWeekdays(Branch branch) => {
  for (final s in branch.services) ?weekdayIndex(s.day),
};

/// True when [event] is one of [branch]'s weekly services as the Studio
/// published it: a weekly event, visible to the branch, repeating on a
/// weekday the branch holds a service on. Next service shows these, so the
/// events strip need not.
bool isBranchServiceEvent(Event event, Branch branch) {
  if (!event.isWeekly || !event.isVisibleTo(branch.name)) return false;
  final days = branchServiceWeekdays(branch);
  return event.recurrenceDays.any(days.contains);
}

/// The soonest day a branch meets and the services held that day.
@immutable
class NextServiceDay {
  const NextServiceDay({
    required this.date,
    required this.daysAway,
    required this.services,
  });

  /// Midnight of the day.
  final DateTime date;

  /// 0 for today, 1 for tomorrow, up to 7 for the same weekday next week.
  final int daysAway;

  /// That day's services, earliest first.
  final List<CampusService> services;

  /// 0 = Sunday ... 6 = Saturday, as [Event.recurrenceDays] counts.
  int get weekday => date.weekday % 7;
}

/// Minutes after midnight a service starts, from its 24-hour "14:00" time;
/// null when the Studio set no clock time.
int? _startMinutes(CampusService service) {
  final m = RegExp(
    r'^(\d{1,2}):(\d{2})',
  ).firstMatch(service.startTime?.trim() ?? '');
  if (m == null) return null;
  final hour = int.parse(m.group(1)!);
  final minute = int.parse(m.group(2)!);
  if (hour > 23 || minute > 59) return null;
  return hour * 60 + minute;
}

/// The next day, from [now], that [services] meet on. Today counts while one
/// of its services has yet to start (a service with no time counts all day);
/// otherwise the search runs on through the week to the same weekday next
/// week. Null when no service names a weekday.
NextServiceDay? nextServiceDay(List<CampusService> services, DateTime now) {
  final nowMinutes = now.hour * 60 + now.minute;
  for (var offset = 0; offset <= 7; offset++) {
    final date = DateTime(now.year, now.month, now.day + offset);
    final weekday = date.weekday % 7;
    final day = [
      for (final s in services)
        if (weekdayIndex(s.day) == weekday) s,
    ];
    if (day.isEmpty) continue;
    if (offset == 0 &&
        !day.any((s) => (_startMinutes(s) ?? 24 * 60) > nowMinutes)) {
      continue;
    }
    // Earliest first; untimed services last; Studio order breaks ties.
    final sorted = [...day.indexed]
      ..sort((a, b) {
        final byTime = (_startMinutes(a.$2) ?? 24 * 60).compareTo(
          _startMinutes(b.$2) ?? 24 * 60,
        );
        return byTime != 0 ? byTime : a.$1.compareTo(b.$1);
      });
    return NextServiceDay(
      date: date,
      daysAway: offset,
      services: [for (final (_, s) in sorted) s],
    );
  }
  return null;
}

/// "Today", "Tomorrow", else "In 3 days".
@visibleForTesting
String relativeDayLabel(int daysAway) => switch (daysAway) {
  0 => 'Today',
  1 => 'Tomorrow',
  _ => 'In $daysAway days',
};

/// The services' start times on one line: `11:00 AM & 1:00 PM`; null when
/// none has a time.
@visibleForTesting
String? serviceTimesLabel(List<CampusService> services) {
  final times = <String>[];
  for (final s in services) {
    if (formatServiceTime(s.startTime) case final t? when !times.contains(t)) {
      times.add(t);
    }
  }
  if (times.isEmpty) return null;
  if (times.length == 1) return times.single;
  return '${times.sublist(0, times.length - 1).join(', ')} & ${times.last}';
}

/// Opens the branch page with the full timetable.
void _openBranch(BuildContext context) => context.push('/branch');

/// Home's "Next service" card: the soonest day the member's branch meets,
/// its times, where (with directions) and how to reach the branch.
///
/// Shows the flyer of the branch's weekly service event for that day when
/// the Studio published one. Tapping the card, or "Full timetable", opens
/// the branch page. Renders nothing for All branches or a branch with no
/// dated services.
class NextServiceCard extends ConsumerWidget {
  const NextServiceCard({super.key, this.padding = EdgeInsets.zero});

  /// Outer padding, applied only when the card renders, so Home's spacing
  /// collapses with it.
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branch = ref.watch(currentCampusProvider);
    if (branch == null) return const SizedBox.shrink();
    final now = ref.watch(nextServiceClockProvider)();
    final next = nextServiceDay(branch.services, now);
    if (next == null) return const SizedBox.shrink();

    final events =
        ref.watch(campusUpcomingEventsProvider).valueOrNull ?? const <Event>[];
    final image = [
      for (final e in events)
        if (isBranchServiceEvent(e, branch) &&
            e.recurrenceDays.contains(next.weekday))
          if (e.imageUrl?.trim() case final url? when url.isNotEmpty) url,
    ].firstOrNull;

    // The day's services by the venue they meet at, each venue once, in
    // order of its first service.
    final groups = <(CampusVenue?, List<CampusService>)>[];
    for (final s in next.services) {
      final venue = branch.venueById(s.venueId);
      final i = groups.indexWhere((g) => g.$1?.id == venue?.id);
      if (i < 0) {
        groups.add((venue, [s]));
      } else {
        groups[i].$2.add(s);
      }
    }

    final kc = context.kc;
    final contact = branch.contact;
    return Padding(
      key: const Key('home-next-service'),
      padding: padding,
      child: PressEffect(
        onTap: () => _openBranch(context),
        child: Container(
          width: double.infinity,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: kc.surface,
            borderRadius: AppRadius.cardBorder,
            boxShadow: AppShadows.card,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (image != null)
                AspectRatio(
                  aspectRatio: 2,
                  child: CachedNetworkImage(
                    key: const Key('next-service-image'),
                    imageUrl: image,
                    fit: BoxFit.cover,
                    placeholder: (_, _) => ColoredBox(color: kc.chipBg),
                    errorWidget: (_, _, _) => ColoredBox(color: kc.chipBg),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            DateFormat('EEEE').format(next.date),
                            style: AppTypography.display(
                              size: 22,
                              weight: FontWeight.w700,
                            ).copyWith(color: kc.onBg, height: 1.1),
                          ),
                        ),
                        const SizedBox(width: 10),
                        _DayTag(relativeDayLabel(next.daysAway)),
                      ],
                    ),
                    if (groups.length == 1)
                      _VenueTimes(
                        venue: groups.single.$1,
                        services: groups.single.$2,
                        timesFirst: true,
                      )
                    else
                      for (final (venue, services) in groups)
                        _VenueTimes(venue: venue, services: services),
                    if (!contact.isEmpty) ...[
                      const SizedBox(height: 10),
                      CampusContactActions(
                        contact: contact,
                        keyPrefix: 'next-service',
                      ),
                    ],
                    const SizedBox(height: 4),
                    TextButton.icon(
                      key: const Key('next-service-timetable'),
                      onPressed: () => _openBranch(context),
                      style: TextButton.styleFrom(
                        foregroundColor: kc.accentInk,
                        minimumSize: const Size(0, 44),
                        padding: EdgeInsets.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      iconAlignment: IconAlignment.end,
                      icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                      label: Text(
                        'Full timetable',
                        style: AppTypography.ui(
                          size: 13.5,
                          weight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Today" / "Tomorrow" / "In 3 days" beside the day name.
class _DayTag extends StatelessWidget {
  const _DayTag(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final kc = context.kc;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: kc.chipBg,
        borderRadius: AppRadius.pillBorder,
      ),
      child: Text(
        text,
        style: AppTypography.ui(
          size: 12,
          weight: FontWeight.w700,
        ).copyWith(color: kc.onChip, height: 1),
      ),
    );
  }
}

/// One venue's part of the day: its times and where it is. With a single
/// venue the times lead ([timesFirst]) as the day's headline; with several,
/// each venue's name leads its own times.
class _VenueTimes extends StatelessWidget {
  const _VenueTimes({
    required this.venue,
    required this.services,
    this.timesFirst = false,
  });

  final CampusVenue? venue;
  final List<CampusService> services;
  final bool timesFirst;

  @override
  Widget build(BuildContext context) {
    final kc = context.kc;
    final venue = this.venue;
    final times = serviceTimesLabel(services);
    final timesText = times == null
        ? null
        : Text(
            times,
            style: timesFirst
                ? AppTypography.ui(
                    size: 16,
                    weight: FontWeight.w700,
                  ).copyWith(color: kc.onBg, height: 1.3)
                : AppTypography.ui(
                    size: 13.5,
                    weight: FontWeight.w500,
                  ).copyWith(color: kc.muted, height: 1.3),
          );
    final name = venue?.name == null
        ? null
        : Text(
            venue!.name!,
            style: AppTypography.ui(
              size: 14,
              weight: FontWeight.w700,
            ).copyWith(color: kc.onBg, height: 1.25),
          );
    return Padding(
      key: venue == null ? null : Key('next-service-venue-${venue.id}'),
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (timesFirst) ...[
            ?timesText,
            if (timesText != null && name != null) const SizedBox(height: 10),
            ?name,
          ] else ...[
            ?name,
            if (timesText != null && name != null) const SizedBox(height: 2),
            ?timesText,
          ],
          if (venue != null && venueDirectionsQuery(venue) != null)
            VenueDirectionsLink(
              key: Key('next-service-directions-${venue.id}'),
              venue: venue,
            ),
        ],
      ),
    );
  }
}
