import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/app_router.dart';
import '../../core/services/notification_service.dart';
import '../../features/calendar/data/branch_service_events.dart';
import '../../features/calendar/data/event_reminder_service.dart';
import '../../features/calendar/data/event_repository.dart';
import '../../features/calendar/data/local_reminder_notifications.dart';
import 'admin_provider.dart';
import 'cache_provider.dart';
import 'clock_provider.dart';
import 'notification_provider.dart';
import 'sermon_provider.dart';

export '../../features/calendar/data/event_reminder_service.dart'
    show ReminderOutcome;

/// The phone's scheduled notifications. Tests override it with a fake.
final reminderNotificationsProvider = Provider<ReminderNotifications>(
  (ref) => LocalReminderNotifications(),
);

/// How long a reminder waits for the branches list before it treats a
/// branch service as not found.
const Duration _branchesTimeout = Duration(seconds: 15);

/// "Remind me" on events. Screens turn a reminder on or off through
/// [toggleEventReminderProvider], which sets the plugin up first.
final eventReminderServiceProvider = Provider<EventReminderService>((ref) {
  final clock = ref.watch(clockProvider);
  return EventReminderService(
    ref.watch(cacheServiceProvider),
    ref.watch(reminderNotificationsProvider),
    clock: clock,
    // As the event screen resolves an id: a branch service from the
    // branches list, anything else from the Studio events.
    resolveEvent: (id) async {
      if (isBranchServiceEventId(id)) {
        final branches = await ref
            .read(branchesProvider.future)
            .timeout(_branchesTimeout);
        return branchServiceEventById(branches, id, now: clock());
      }
      return ref.read(eventRepositoryProvider).getEventById(id);
    },
    // The app's one notification prompt, and its follow-up.
    ensurePermission: () async {
      final permission = await ref.refresh(
        notificationPermissionProvider.future,
      );
      if (permission == NotificationPermission.granted) return true;
      final onAnswer = ref.read(notificationPermissionAnsweredProvider);
      final granted = await ref
          .read(notificationServiceProvider)
          .requestPermission();
      await onAnswer(granted);
      return granted;
    },
  );
});

/// Sets reminders up, once per launch: registers the tap handler (a tapped
/// reminder opens `/events/:id`, as an event push does), opens the event of
/// the reminder that launched the app, then brings every reminder up to
/// date (weekly ones move to their next occurrence, finished events are
/// dropped).
///
/// Watched by `KharisApp` so it runs on launch without holding up the first
/// frame. It never shows the notification permission prompt.
final eventReminderStartupProvider = FutureProvider<void>((ref) async {
  // Read, not watch: a rebuild would open the launching reminder twice.
  final router = ref.read(appRouterProvider);
  void open(String eventId) => openNotificationTarget(
    router,
    notificationTargetFor({'type': 'event', 'eventId': eventId}),
  );
  try {
    final launchedBy = await ref
        .read(reminderNotificationsProvider)
        .init(onTap: open);
    if (launchedBy != null) open(launchedBy);
  } on Object catch (error) {
    // A host without the plugin: turning a reminder on reports a failure.
    debugPrint('Event reminders unavailable: $error');
    return;
  }
  await ref.read(eventReminderServiceProvider).sync();
});

/// Ids of the events the member asked to be reminded about.
final remindedEventIdsProvider = Provider<Set<String>>((ref) {
  final service = ref.watch(eventReminderServiceProvider);
  void changed() => ref.invalidateSelf();
  service.changes.addListener(changed);
  ref.onDispose(() => service.changes.removeListener(changed));
  return service.remindedIds;
});

/// Whether the member asked to be reminded about one event.
final isEventRemindedProvider = Provider.autoDispose.family<bool, String>(
  (ref, eventId) => ref.watch(
    remindedEventIdsProvider.select((ids) => ids.contains(eventId)),
  ),
);

/// Turns an event's reminder on when it is off and off when it is on, and
/// says what came of it. Turning it on asks for notification permission when
/// it has not been granted; refused, the reminder stays off
/// ([ReminderOutcome.permissionRefused]).
///
/// Read it before any `await` and call it: it runs on this provider's own
/// `ref`, so it still works after the screen that asked has been popped.
final toggleEventReminderProvider =
    Provider<Future<ReminderOutcome> Function(Event event)>((ref) {
      return (event) async {
        await ref.read(eventReminderStartupProvider.future);
        return ref.read(eventReminderServiceProvider).toggle(event);
      };
    });
