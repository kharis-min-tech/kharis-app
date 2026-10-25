import 'package:kharis_app/features/calendar/data/event_repository.dart';
import 'package:kharis_app/features/onboarding/data/branch_repository.dart';
import 'package:kharis_app/shared/models/campus_config.dart';

/// Branch weekly services as Events-tab events.
///
/// Every branch meets weekly at the venues the Content Studio lists for it,
/// so the Events tab never reads "No upcoming events" for a branch that has
/// services. Each active, dated, timed [CampusService] becomes one weekly
/// [Event] with the id `service:<branchId>:<serviceId>`; the event detail
/// screen resolves that id from the branches list, not the Studio events
/// table.

const _idPrefix = 'service:';

/// The generated event id for [service] of [branch].
String branchServiceEventId(Branch branch, CampusService service) =>
    '$_idPrefix${branch.id}:${service.id}';

/// True when [id] names a generated branch service event.
bool isBranchServiceEventId(String id) => id.startsWith(_idPrefix);

/// Minutes after midnight for a Studio time: 24-hour `14:00` /
/// `14:00:00`, or an older 12-hour `2:00 PM`. Null when unreadable.
int? _minutes(String? raw) {
  final m = RegExp(
    r'^(\d{1,2}):(\d{2})(?::\d{2})?\s*([AaPp][Mm])?$',
  ).firstMatch(raw?.trim() ?? '');
  if (m == null) return null;
  var hour = int.parse(m.group(1)!);
  final minute = int.parse(m.group(2)!);
  final meridiem = m.group(3)?.toLowerCase();
  if (minute > 59) return null;
  if (meridiem != null) {
    if (hour < 1 || hour > 12) return null;
    hour = hour % 12 + (meridiem == 'pm' ? 12 : 0);
  } else if (hour > 23) {
    return null;
  }
  return hour * 60 + minute;
}

/// [branch]'s services as weekly events, soonest first.
///
/// One event per active service that names a weekday and a start time (an
/// untimed service has no instant to list). Its start is the next
/// occurrence whose end (else start) is not before [now], as
/// [EventRepository.fromRow] dates a weekly Studio event: a service stays
/// listed while it runs. An end time at or before the start is read as
/// running past midnight. Location and address come from the service's
/// venue; with no venue the address is the branch's.
List<Event> branchServiceEvents(Branch branch, {required DateTime now}) {
  final events = <Event>[];
  for (final service in branch.services) {
    if (!service.isActive) continue;
    final weekday = weekdayIndex(service.day);
    final start = _minutes(service.startTime);
    if (weekday == null || start == null) continue;
    final end = _minutes(service.endTime);
    final length = end == null
        ? null
        : Duration(minutes: end > start ? end - start : end + 24 * 60 - start);
    final venue = branch.venueById(service.venueId);
    final venueAddress = venue?.address;
    final address = venueAddress != null && venueAddress.isNotEmpty
        ? venueAddress
        : branch.address;
    // From yesterday, so a service running past midnight is still found.
    for (var offset = -1; offset <= 7; offset++) {
      final day = DateTime(now.year, now.month, now.day + offset);
      if (day.weekday % 7 != weekday) continue;
      final startTime = DateTime(
        day.year,
        day.month,
        day.day,
        start ~/ 60,
        start % 60,
      );
      final endTime = length == null ? null : startTime.add(length);
      if ((endTime ?? startTime).isBefore(now)) continue;
      events.add(
        Event(
          id: branchServiceEventId(branch, service),
          title: service.name,
          startTime: startTime,
          endTime: endTime,
          description: service.description,
          location: venue?.name,
          address: address,
          branch: branch.name,
          recurrenceDays: [weekday],
        ),
      );
      break;
    }
  }
  return events..sort((a, b) => a.startTime.compareTo(b.startTime));
}

/// The generated event [id] names among [branches]' services, or null.
Event? branchServiceEventById(
  List<Branch> branches,
  String id, {
  required DateTime now,
}) {
  for (final branch in branches) {
    if (!id.startsWith('$_idPrefix${branch.id}:')) continue;
    for (final e in branchServiceEvents(branch, now: now)) {
      if (e.id == id) return e;
    }
  }
  return null;
}

/// [studio] events plus [branch]'s service events, soonest first.
///
/// A Studio weekly event for [branch] that repeats on a service's weekday
/// stands in for that service (it carries the photo and the Studio's
/// wording), so the generated one is dropped. When several services share
/// the weekday, the Studio event replaces the one with the same title, else
/// the one starting closest to it. Studio events for all branches never
/// replace a service.
List<Event> withBranchServiceEvents(
  List<Event> studio,
  Branch? branch, {
  required DateTime now,
}) {
  if (branch == null) return studio;
  final services = branchServiceEvents(branch, now: now);
  if (services.isEmpty) return studio;
  final replaced = <String>{};
  for (final e in studio) {
    if (!e.isWeekly || e.branch != branch.name) continue;
    final title = e.title.trim().toLowerCase();
    final minutes = e.startTime.hour * 60 + e.startTime.minute;
    for (final day in e.recurrenceDays) {
      final sameDay = [
        for (final s in services)
          if (s.recurrenceDays.single == day) s,
      ];
      if (sameDay.isEmpty) continue;
      Event? match;
      for (final s in sameDay) {
        if (s.title.trim().toLowerCase() == title) match = s;
      }
      int gap(Event s) =>
          (s.startTime.hour * 60 + s.startTime.minute - minutes).abs();
      match ??= sameDay.reduce((a, b) => gap(b) < gap(a) ? b : a);
      replaced.add(match.id);
    }
  }
  return [
    ...studio,
    for (final s in services)
      if (!replaced.contains(s.id)) s,
  ]..sort((a, b) => a.startTime.compareTo(b.startTime));
}
