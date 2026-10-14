import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:kharis_app/core/services/content_api.dart';
import 'package:kharis_app/core/utils/media_url.dart';

@immutable
class Event {
  const Event({
    required this.id,
    required this.title,
    required this.startTime,
    this.endTime,
    this.description,
    this.location,
    this.address,
    this.branch,
    this.imageUrl,
    this.isFeatured = false,
    this.recurrenceDays = const [],
  });

  /// The Studio event id.
  final String id;
  final String title;
  final String? description;

  /// Where it happens, as the Studio wrote it.
  final String? location;

  /// Street address of [location], for maps and the event detail screen.
  final String? address;

  /// Branch name this event belongs to (e.g. "London", "Manchester").
  /// `null` means the event applies to all branches; a blank stored value is
  /// read as `null` too.
  final String? branch;

  /// True when a member whose branch is [memberBranch] should see this event:
  /// its branch is theirs, it is for all branches, or they follow all
  /// branches.
  bool isVisibleTo(String? memberBranch) =>
      memberBranch == null || branch == null || branch == memberBranch;

  final DateTime startTime;

  /// Optional end instant; use [effectiveEndTime].
  final DateTime? endTime;

  final String? imageUrl;
  final bool isFeatured;

  /// Weekdays a weekly event repeats on (0 = Sunday ... 6 = Saturday),
  /// sorted; empty for a one-off event. For a weekly event [startTime] is its
  /// next occurrence.
  final List<int> recurrenceDays;

  bool get isWeekly => recurrenceDays.isNotEmpty;

  static const _weekdays = [
    'Sunday',
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
  ];

  /// "Every Sunday · 9:00 AM", "Every Sunday and Wednesday · 9:00 AM";
  /// null for a one-off event.
  String? get recurrenceLabel {
    if (!isWeekly) return null;
    final names = [for (final d in recurrenceDays) _weekdays[d]];
    final days = names.length == 1
        ? names.single
        : '${names.sublist(0, names.length - 1).join(', ')} and ${names.last}';
    return 'Every $days · ${DateFormat('h:mm a').format(startTime)}';
  }

  /// The instant the event is over. Events with no explicit end are treated
  /// as ending when they start.
  DateTime get effectiveEndTime => endTime ?? startTime;

  /// True once the event has finished. An event that has started but not yet
  /// ended is deliberately *not* past, so it stays in "Upcoming" while it runs.
  bool isPastAt(DateTime now) => effectiveEndTime.isBefore(now);

  @override
  bool operator ==(Object other) =>
      other is Event && other.id == id && other.startTime == startTime;

  @override
  int get hashCode => Object.hash(id, startTime);

  @override
  String toString() => 'Event(id: $id, title: $title, branch: $branch)';
}

/// Reads events from the Content Studio `events` table, one [Event] per row,
/// exactly as the Studio wrote it.
///
/// A weekly event (`recurrence == "weekly"`) stays one event, dated at its
/// next occurrence on its `recurrence_days` and dropped once
/// `recurrence_until` has passed. Past-ness is decided by
/// [Event.effectiveEndTime], so an in-progress event stays in "Upcoming"
/// until it ends.
class EventRepository {
  EventRepository({required this._api, DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final ContentApi _api;
  final DateTime Function() _clock;

  static const _table = 'events';
  static const _query = {'order': 'start_time.asc'};

  /// The Past view is a capped list, not a full history.
  static const int pastEventLimit = 15;

  // ── Reads ──────────────────────────────────────────────────────────────────

  /// Upcoming events visible to [branch], soonest (next occurrence) first:
  /// the saved list first when there is one, then the Studio's current one.
  Stream<List<Event>> watchUpcomingEvents({String? branch}) => _api
      .watch(_table, query: _query)
      .map((rows) => upcoming(rows, branch: branch, now: _clock()));

  /// The [pastEventLimit] most recently finished one-off events visible to
  /// [branch], most recent first. Weekly events are left out.
  Stream<List<Event>> watchPastEvents({String? branch}) => _api
      .watch(_table, query: _query)
      .map((rows) => past(rows, branch: branch, now: _clock()));

  /// Resolves event ids; unknown ids are dropped.
  Future<List<Event>> getEventsByIds(List<String> ids) async {
    final unique = ids.toSet();
    if (unique.isEmpty) return const [];
    try {
      final rows = await _api.load(_table, query: _query);
      final now = _clock();
      return [
        for (final id in unique) ?resolve(rows, id, now: now),
      ];
    } catch (_) {
      return const [];
    }
  }

  /// One event by its Studio id.
  Future<Event?> getEventById(String id) async {
    try {
      final rows = await _api.load(_table, query: _query);
      return resolve(rows, id, now: _clock());
    } catch (_) {
      return null;
    }
  }

  // ── Mapping (pure; tested directly) ────────────────────────────────────────

  static List<Event> upcoming(
    List<Map<String, dynamic>> rows, {
    required String? branch,
    required DateTime now,
  }) {
    final events = [
      for (final row in rows) ?fromRow(row, now: now),
    ].where((e) => !e.isPastAt(now) && e.isVisibleTo(branch)).toList();
    return events..sort((a, b) => a.startTime.compareTo(b.startTime));
  }

  static List<Event> past(
    List<Map<String, dynamic>> rows, {
    required String? branch,
    required DateTime now,
  }) {
    final events = [
      for (final row in rows)
        if (!_isWeekly(row)) ?_single(row),
    ].where((e) => e.isPastAt(now) && e.isVisibleTo(branch)).toList();
    events.sort((a, b) => b.startTime.compareTo(a.startTime));
    return events.take(pastEventLimit).toList();
  }

  /// The event [id] names in [rows], or null.
  static Event? resolve(
    List<Map<String, dynamic>> rows,
    String id, {
    required DateTime now,
  }) {
    for (final r in rows) {
      if (r['id'] == id) return fromRow(r, now: now);
    }
    return null;
  }

  /// A row as one event. A weekly event is dated at its next (or running)
  /// occurrence; once `recurrence_until` is behind it, it is null. A weekly
  /// row without days reads as a one-off.
  static Event? fromRow(Map<String, dynamic> row, {required DateTime now}) {
    final base = _single(row);
    if (base == null) return null;
    if (!_isWeekly(row)) return base;
    final days = _recurrenceDays(row);
    if (days.isEmpty) return base;
    final s = base.startTime;
    final length = base.endTime?.difference(s);
    final until = _until(row);
    var day = _dateOnly(now).subtract(const Duration(days: 1));
    if (day.isBefore(_dateOnly(s))) day = _dateOnly(s);
    for (var i = 0; i < 9; i++) {
      if (until != null && day.isAfter(until)) return null;
      if (days.contains(day.weekday % 7)) {
        final start = DateTime(day.year, day.month, day.day, s.hour, s.minute);
        final end = length == null ? null : start.add(length);
        if (!(end ?? start).isBefore(now)) {
          return Event(
            id: base.id,
            title: base.title,
            startTime: start,
            endTime: end,
            description: base.description,
            location: base.location,
            address: base.address,
            branch: base.branch,
            imageUrl: base.imageUrl,
            isFeatured: base.isFeatured,
            recurrenceDays: days.toList()..sort(),
          );
        }
      }
      day = DateTime(day.year, day.month, day.day + 1);
    }
    return null;
  }

  /// The row as one event; null without an id, a title or a start time, so
  /// one malformed row never takes out the list.
  static Event? _single(Map<String, dynamic> row) {
    final id = _text(row['id']);
    final title = _text(row['title']);
    final start = _instant(row['start_time']);
    if (id == null || title == null || start == null) return null;
    return Event(
      id: id,
      title: title,
      description: _text(row['description']),
      location: _text(row['location']),
      branch: _text(row['branch_name']),
      startTime: start,
      endTime: _instant(row['end_time']),
      imageUrl: usableMediaUrl(_text(row['image_url'])),
      isFeatured: row['is_featured'] == true,
    );
  }

  static bool _isWeekly(Map<String, dynamic> row) =>
      _text(row['recurrence'])?.toLowerCase() == 'weekly';

  /// `recurrence_days` as 0 = Sunday ... 6 = Saturday.
  static Set<int> _recurrenceDays(Map<String, dynamic> row) {
    final raw = row['recurrence_days'];
    if (raw is! List) return const {};
    return {
      for (final d in raw)
        if (d is num && d >= 0 && d <= 6) d.toInt(),
    };
  }

  /// Last day (local date) a weekly event may occur on, or null.
  static DateTime? _until(Map<String, dynamic> row) {
    final raw = _text(row['recurrence_until']);
    if (raw == null) return null;
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return null;
    // A bare date is a calendar day; a timestamp is an instant.
    return _dateOnly(raw.length <= 10 ? parsed : parsed.toLocal());
  }

  static DateTime _dateOnly(DateTime t) => DateTime(t.year, t.month, t.day);

  /// ISO instants render on the device clock.
  static DateTime? _instant(Object? raw) {
    final t = _text(raw);
    return t == null ? null : DateTime.tryParse(t)?.toLocal();
  }

  static String? _text(Object? v) {
    if (v is! String) return null;
    final t = v.trim();
    return t.isEmpty ? null : t;
  }
}
