import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import 'package:kharis_app/features/calendar/data/event_reminder_service.dart';

/// [ReminderNotifications] on flutter_local_notifications.
///
/// It never asks for notification permission (the app's one prompt is
/// `NotificationService.requestPermission`), and it schedules inexactly, so
/// Android needs no exact-alarm permission: a reminder can arrive a few
/// minutes late while the phone dozes.
///
/// Reminders go to the channel the app already has for announcements
/// (created in `MainActivity`, named in `strings.xml`), so members see one
/// Kharis notification category, not two.
class LocalReminderNotifications implements ReminderNotifications {
  LocalReminderNotifications([FlutterLocalNotificationsPlugin? plugin])
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  static const NotificationDetails _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'kharis_announcements',
      'Church announcements',
      channelDescription:
          'Announcements, event reminders, daily readings and new sermons.',
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(),
  );

  @override
  Future<String?> init({required void Function(String eventId) onTap}) async {
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestSoundPermission: false,
          requestBadgePermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (response) {
        final eventId = response.payload;
        if (eventId != null && eventId.isNotEmpty) onTap(eventId);
      },
    );
    final launch = await _plugin.getNotificationAppLaunchDetails();
    if (launch == null || !launch.didNotificationLaunchApp) return null;
    final eventId = launch.notificationResponse?.payload;
    return eventId == null || eventId.isEmpty ? null : eventId;
  }

  @override
  Future<void> schedule(ReminderNotification reminder) => _plugin.zonedSchedule(
    id: reminder.id,
    title: reminder.title,
    body: reminder.body,
    payload: reminder.eventId,
    // An instant, so it needs no time-zone database and no device zone.
    scheduledDate: tz.TZDateTime.from(reminder.at, tz.UTC),
    notificationDetails: _details,
    androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
  );

  @override
  Future<void> cancel(int id) => _plugin.cancel(id: id);
}
