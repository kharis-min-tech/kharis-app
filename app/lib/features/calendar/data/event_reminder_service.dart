import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import 'package:kharis_app/core/services/cache_service.dart';
import 'package:kharis_app/features/calendar/data/event_repository.dart';

/// One reminder to show at an instant.
@immutable
class ReminderNotification {
  const ReminderNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.eventId,
    required this.at,
  });

  /// The OS notification id. Scheduling the same id again replaces it.
  final int id;
  final String title;
  final String body;

  /// The event a tap opens.
  final String eventId;

  /// When to show it.
  final DateTime at;
}

/// The phone's scheduled notifications, as far as reminders need them. The
/// app's is `LocalReminderNotifications` (flutter_local_notifications);
/// tests use a fake.
abstract interface class ReminderNotifications {
  /// Sets up the plugin. [onTap] is called with the event id whenever a
  /// reminder is tapped while the app is running. Returns the event id of
  /// the reminder whose tap launched the app, or null.
  Future<String?> init({required void Function(String eventId) onTap});

  /// Shows [reminder] at its time, replacing one with the same id.
  Future<void> schedule(ReminderNotification reminder);

  /// Withdraws a scheduled reminder. A no-op when it has already been shown.
  Future<void> cancel(int id);
}

/// What turning a reminder on or off came to.
enum ReminderOutcome {
  /// The reminder is on and scheduled.
  on,

  /// The reminder is off.
  off,

  /// Notifications are not allowed, so it stays off.
  permissionRefused,

  /// The event starts within [EventReminderService.lead] (or has started)
  /// and does not repeat: there is nothing left to remind about.
  startsTooSoon,

  /// The phone could not schedule it; it stays off.
  failed,
}

class _Record {
  _Record({
    required this.notificationId,
    required this.startsAt,
    required this.weekly,
    required this.seenAt,
  });

  final int notificationId;

  /// Start of the occurrence the scheduled reminder is for.
  DateTime startsAt;
  bool weekly;

  /// When the event was last found.
  DateTime seenAt;

  Map<String, dynamic> toJson() => {
    'n': notificationId,
    'at': startsAt.millisecondsSinceEpoch,
    'w': weekly,
    'seen': seenAt.millisecondsSinceEpoch,
  };

  static _Record? fromJson(Object? json) {
    if (json is! Map) return null;
    final n = json['n'];
    final at = json['at'];
    final seen = json['seen'];
    if (n is! int || at is! int || seen is! int) return null;
    return _Record(
      notificationId: n,
      startsAt: DateTime.fromMillisecondsSinceEpoch(at),
      weekly: json['w'] == true,
      seenAt: DateTime.fromMillisecondsSinceEpoch(seen),
    );
  }
}

/// "Remind me" on events: a local notification [lead] before the start.
///
/// The member opts in per event. A weekly event (a Studio one, or a branch
/// service with a `service:` id) is reminded about its next occurrence;
/// [sync], run when the app starts, moves each weekly reminder on to the
/// occurrence after the one that has passed, picks up a changed time or
/// venue, and drops reminders for events that are over.
///
/// Reminders are scheduled for an instant, so a daylight-saving change or a
/// changed clock cannot move them. Which events are reminded is a
/// [CacheService] preference.
class EventReminderService {
  /// [resolveEvent] looks an event up by id (null when it is not found).
  /// [ensurePermission] says whether notifications are allowed, asking the
  /// member when they have not answered yet.
  EventReminderService(
    this._cache,
    this._notifications, {
    required this.resolveEvent,
    required this.ensurePermission,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final CacheService _cache;
  final ReminderNotifications _notifications;
  final Future<Event?> Function(String eventId) resolveEvent;
  final Future<bool> Function() ensurePermission;
  final DateTime Function() _clock;

  /// How long before the start a reminder is shown.
  static const Duration lead = Duration(hours: 1);

  /// A weekly reminder whose event has not been found for this long is
  /// dropped: the event was removed.
  static const Duration forgetAfter = Duration(days: 60);

  /// Preference key of the reminded events, as JSON.
  static const String remindersKey = 'event_reminders';

  /// First notification id reminders use. Ids run from here to
  /// `0x1FFFFFFF`, clear of the audio player's notification.
  static const int _idBase = 0x10000000;
  static const int _idMask = 0x0FFFFFFF;

  /// Bumped when the set of reminded events changes.
  final ValueNotifier<int> changes = ValueNotifier(0);

  Map<String, _Record>? _loaded;

  // ── Reads ──────────────────────────────────────────────────────────────────

  /// Ids of the events the member asked to be reminded about.
  Set<String> get remindedIds => Set.unmodifiable(_records().keys);

  bool isReminded(String eventId) => _records().containsKey(eventId);

  /// Whether a reminder for [event] can still be scheduled: it repeats
  /// weekly, or starts more than [lead] from now.
  bool canRemind(Event event) => nextReminder(event, _clock()) != null;

  /// Start of the occurrence of [event] to remind about: the first whose
  /// reminder time is still ahead of [now]. Null for a one-off event that
  /// starts within [lead] or has started.
  @visibleForTesting
  static DateTime? nextReminder(Event event, DateTime now) {
    bool ahead(DateTime start) => start.subtract(lead).isAfter(now);
    final first = event.startTime;
    if (ahead(first)) return first;
    if (!event.isWeekly) return null;
    // Same time of day on the following days it repeats on. Stepping the
    // calendar date keeps the wall-clock time across a daylight-saving
    // change.
    for (var offset = 1; offset <= DateTime.daysPerWeek; offset++) {
      final start = DateTime(
        first.year,
        first.month,
        first.day + offset,
        first.hour,
        first.minute,
      );
      if (event.recurrenceDays.contains(start.weekday % 7) && ahead(start)) {
        return start;
      }
    }
    return null;
  }

  // ── Writes ─────────────────────────────────────────────────────────────────

  /// Turns [event]'s reminder on when it is off and off when it is on.
  Future<ReminderOutcome> toggle(Event event) =>
      isReminded(event.id) ? disable(event.id) : enable(event);

  /// Turns [event]'s reminder on. Asks for notification permission when it
  /// has not been granted; refused, the reminder stays off.
  Future<ReminderOutcome> enable(Event event) async {
    final start = nextReminder(event, _clock());
    if (start == null) return ReminderOutcome.startsTooSoon;
    if (!await ensurePermission()) return ReminderOutcome.permissionRefused;
    final records = _records();
    final record =
        records[event.id] ??
        _Record(
          notificationId: _newNotificationId(event.id),
          startsAt: start,
          weekly: event.isWeekly,
          seenAt: _clock(),
        );
    try {
      await _notifications.schedule(_reminder(event, start, record));
    } on Object catch (error) {
      debugPrint('EventReminderService: could not schedule: $error');
      return ReminderOutcome.failed;
    }
    record
      ..startsAt = start
      ..weekly = event.isWeekly
      ..seenAt = _clock();
    records[event.id] = record;
    _persist();
    changes.value++;
    return ReminderOutcome.on;
  }

  /// Turns the reminder for [eventId] off.
  Future<ReminderOutcome> disable(String eventId) async {
    final record = _records().remove(eventId);
    if (record == null) return ReminderOutcome.off;
    _persist();
    changes.value++;
    await _cancel(record.notificationId);
    return ReminderOutcome.off;
  }

  /// Brings every reminder up to date. Run when the app starts.
  ///
  /// Each reminded event is looked up again. Found: its reminder is
  /// scheduled for its next occurrence with its current time and place, or
  /// removed when it is over. Not found (removed, or no connection): a
  /// one-off reminder is removed once its start has passed, a weekly one
  /// after [forgetAfter]; until then what is scheduled is left alone.
  Future<void> sync() async {
    final records = _records();
    var changed = false;
    for (final eventId in records.keys.toList()) {
      Event? event;
      try {
        event = await resolveEvent(eventId);
      } on Object {
        event = null;
      }
      // Turned off, or off and on again, while the lookup ran.
      final record = records[eventId];
      if (record == null) continue;
      final now = _clock();
      final start = event == null ? null : nextReminder(event, now);
      if (event != null && start != null) {
        try {
          await _notifications.schedule(_reminder(event, start, record));
        } on Object catch (error) {
          debugPrint('EventReminderService: could not re-schedule: $error');
          continue;
        }
        if (!identical(records[eventId], record)) continue;
        record
          ..startsAt = start
          ..weekly = event.isWeekly
          ..seenAt = now;
        _persist();
        continue;
      }
      final over = event != null
          // Found, with nothing left to remind about: gone once it starts.
          ? !event.startTime.isAfter(now)
          : record.weekly
          ? now.difference(record.seenAt) > forgetAfter
          : !record.startsAt.isAfter(now);
      if (!over) continue;
      records.remove(eventId);
      _persist();
      changed = true;
      await _cancel(record.notificationId);
    }
    if (changed) changes.value++;
  }

  // ── Internals ──────────────────────────────────────────────────────────────

  static ReminderNotification _reminder(
    Event event,
    DateTime start,
    _Record record,
  ) {
    final time = DateFormat('h:mm a').format(start);
    final place = [event.location, event.address]
        .map((value) => value?.trim() ?? '')
        .where((value) => value.isNotEmpty)
        .firstOrNull;
    return ReminderNotification(
      id: record.notificationId,
      title: event.title,
      body: place == null ? 'Starts at $time' : 'Starts at $time · $place',
      eventId: event.id,
      at: start.subtract(lead),
    );
  }

  Future<void> _cancel(int notificationId) async {
    try {
      await _notifications.cancel(notificationId);
    } on Object catch (error) {
      debugPrint('EventReminderService: could not cancel: $error');
    }
  }

  /// A notification id for [eventId] that no other reminder holds. FNV-1a,
  /// not [String.hashCode]: the id is stored and must mean the same thing on
  /// every launch.
  int _newNotificationId(String eventId) {
    var hash = 0x811C9DC5;
    for (final unit in eventId.codeUnits) {
      hash = ((hash ^ unit) * 0x01000193) & 0xFFFFFFFF;
    }
    final taken = {for (final r in _records().values) r.notificationId};
    var id = _idBase | (hash & _idMask);
    while (taken.contains(id)) {
      id = _idBase | ((id + 1) & _idMask);
    }
    return id;
  }

  Map<String, _Record> _records() => _loaded ??= _load();

  Map<String, _Record> _load() {
    final raw = _cache.getPreference<Object?>(remindersKey, null);
    if (raw is! String) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      return {
        for (final entry in decoded.entries)
          if (entry.key is String)
            entry.key as String: ?_Record.fromJson(entry.value),
      };
    } on FormatException {
      return {};
    }
  }

  void _persist() => _cache.cachePreference(
    remindersKey,
    jsonEncode({
      for (final entry in _records().entries) entry.key: entry.value.toJson(),
    }),
  );
}
