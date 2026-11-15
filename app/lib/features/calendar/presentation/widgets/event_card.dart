import 'package:add_2_calendar_new/add_2_calendar_new.dart' as add2cal;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:kharis_app/features/calendar/data/event_repository.dart';
import 'package:kharis_app/features/calendar/data/rsvp_repository.dart';
import 'package:kharis_app/shared/providers/auth_provider.dart';
import 'package:kharis_app/shared/providers/branch_provider.dart';
import 'package:kharis_app/shared/providers/event_reminders_provider.dart';
import 'package:kharis_app/shared/providers/sermon_provider.dart';
import 'package:kharis_app/ui/components/components.dart';

/// Toast for event actions (reminders, RSVP, add to calendar).
SnackBar eventToast(String message, {SnackBarAction? action}) => SnackBar(
  content: Text(message),
  action: action,
  behavior: SnackBarBehavior.floating,
  duration: const Duration(milliseconds: 1900),
);

/// Where an event happens, for one-line display: the venue name, else its
/// street address, else the branch it belongs to. `null` when none is known.
String? eventPlaceLabel(Event event) {
  for (final candidate in [event.location, event.address, event.branch]) {
    final value = candidate?.trim();
    if (value != null && value.isNotEmpty) return value;
  }
  return null;
}

const _weekdays = [
  'Sunday',
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
];

/// "Every Sunday", "Every Sunday and Wednesday"; null for a one-off event.
String? eventRepeatsLabel(Event event) {
  if (!event.isWeekly) return null;
  final names = [for (final d in event.recurrenceDays) _weekdays[d]];
  final days = names.length == 1
      ? names.single
      : '${names.sublist(0, names.length - 1).join(', ')} and ${names.last}';
  return 'Every $days';
}

/// When an event is, for a list: "Every Sunday · 12:00" for a weekly event,
/// else "Sat 31 Oct · 18:00".
String eventWhenLabel(Event event) {
  final time = DateFormat('HH:mm').format(event.startTime);
  final repeats = eventRepeatsLabel(event);
  if (repeats != null) return '$repeats \u00b7 $time';
  return '${DateFormat('EEE d MMM').format(event.startTime)} \u00b7 $time';
}

/// Opens the event detail screen, handing over the loaded [event] so it
/// paints immediately. Pushed (never `go`) so Back returns to the caller.
void openEventDetail(BuildContext context, Event event) {
  context.push('/events/${Uri.encodeComponent(event.id)}', extra: event);
}

/// One event in a list: the date block, the title, when and where it is,
/// and "Remind me" while a reminder can still be set. The whole card opens
/// the event detail.
class EventCard extends ConsumerWidget {
  const EventCard({super.key, required this.event});

  final Event event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canRemind = ref.watch(eventReminderServiceProvider).canRemind(event);

    return KEventCard(
      month: DateFormat('MMM').format(event.startTime),
      day: DateFormat('d').format(event.startTime),
      dateSemanticLabel: DateFormat('EEEE d MMMM').format(event.startTime),
      title: event.title,
      meta: [eventWhenLabel(event), ?eventPlaceLabel(event)].join('\n'),
      onTap: () => openEventDetail(context, event),
      toggle: canRemind ? EventReminderToggle(event: event) : null,
    );
  }
}

/// "Remind me" / "Reminder on" for one event.
class EventReminderToggle extends ConsumerWidget {
  const EventReminderToggle({super.key, required this.event});

  final Event event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final on = ref.watch(isEventRemindedProvider(event.id));

    return KToggleButton(
      label: 'Remind me',
      selectedLabel: 'Reminder on',
      icon: KIcons.bell,
      selected: on,
      semanticLabel: on
          ? 'Reminder on for ${event.title}'
          : 'Remind me about ${event.title}',
      onChanged: (_) => toggleEventReminder(context, ref, event),
    );
  }
}

/// Turns the reminder for [event] on or off and says what came of it. The
/// button state comes from [isEventRemindedProvider].
Future<void> toggleEventReminder(
  BuildContext context,
  WidgetRef ref,
  Event event,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final toggle = ref.read(toggleEventReminderProvider);
  final outcome = await toggle(event);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      eventToast(switch (outcome) {
        ReminderOutcome.on =>
          'We\u2019ll remind you an hour before ${event.title}.',
        ReminderOutcome.off => 'Reminder off for ${event.title}.',
        ReminderOutcome.permissionRefused =>
          'Notifications are off. Turn them on in Settings to get reminders.',
        ReminderOutcome.startsTooSoon =>
          'This starts within the hour, too soon for a reminder.',
        ReminderOutcome.failed =>
          'Couldn\u2019t set the reminder. Please try again.',
      }),
    );
}

/// Toggles the persisted RSVP for [event]. Button state comes from
/// [isEventRsvpedProvider], which is driven by the Firestore stream, so the
/// UI settles on the value that was actually written.
Future<void> toggleEventRsvp(
  BuildContext context,
  WidgetRef ref,
  Event event,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final router = GoRouter.of(context);
  if (ref.read(currentUserProvider).valueOrNull == null) {
    _promptSignIn(messenger, router);
    return;
  }
  final activeBranch = ref.read(currentBranchProvider).valueOrNull;
  try {
    final going = await ref
        .read(rsvpRepositoryProvider)
        .toggleRsvp(event, branch: event.branch ?? activeBranch);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        eventToast(
          going
              ? 'You\u2019re going to ${event.title}.'
              : 'RSVP cancelled for ${event.title}.',
        ),
      );
  } on RsvpAuthRequiredException {
    _promptSignIn(messenger, router);
  } catch (_) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        eventToast('Couldn\u2019t save your RSVP. Please try again.'),
      );
  }
}

void _promptSignIn(ScaffoldMessengerState messenger, GoRouter router) {
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      eventToast(
        'Sign in to RSVP to events.',
        action: SnackBarAction(
          label: 'Sign in',
          onPressed: () => router.push('/login'),
        ),
      ),
    );
}

/// Hands [event] to the device calendar. Events may legitimately have no end
/// time; a one-hour block is the sensible default for a calendar entry.
Future<void> addEventToCalendar(BuildContext context, Event event) async {
  final messenger = ScaffoldMessenger.of(context);
  final where = [
    event.location,
    event.address,
  ].map((s) => s?.trim() ?? '').where((s) => s.isNotEmpty).join(', ');
  final calEvent = add2cal.Event(
    title: event.title,
    description: event.isWeekly
        ? [
            ?event.description,
            'Repeats weekly: ${event.recurrenceLabel}.',
          ].join('\n\n')
        : event.description,
    location: where.isEmpty ? event.branch : where,
    startDate: event.startTime,
    endDate: event.endTime ?? event.startTime.add(const Duration(hours: 1)),
  );
  try {
    await add2cal.Add2Calendar.addEvent2Cal(calEvent);
  } catch (_) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(eventToast('Couldn\u2019t open your calendar.'));
  }
}
