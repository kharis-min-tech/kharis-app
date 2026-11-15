import 'package:kharis_app/features/calendar/data/event_reminder_service.dart';

/// In-memory [ReminderNotifications]: what is scheduled, with no plugin.
class FakeReminderNotifications implements ReminderNotifications {
  /// Pending reminders by notification id.
  final Map<int, ReminderNotification> scheduled = {};

  /// Every id cancelled, in order.
  final List<int> cancelled = [];

  /// Event id of the reminder whose tap "launched the app".
  String? launchedBy;

  /// Makes [schedule] fail, as a phone that cannot schedule does.
  bool failScheduling = false;

  /// Makes [init] fail, as a host without the plugin does.
  bool failInit = false;

  int initCalls = 0;
  void Function(String eventId)? _onTap;

  /// Taps the reminder for [eventId] while the app is running.
  void tap(String eventId) => _onTap?.call(eventId);

  @override
  Future<String?> init({required void Function(String eventId) onTap}) async {
    initCalls++;
    if (failInit) throw StateError('no notifications plugin');
    _onTap = onTap;
    return launchedBy;
  }

  @override
  Future<void> schedule(ReminderNotification reminder) async {
    if (failScheduling) throw StateError('cannot schedule');
    scheduled[reminder.id] = reminder;
  }

  @override
  Future<void> cancel(int id) async {
    cancelled.add(id);
    scheduled.remove(id);
  }
}
