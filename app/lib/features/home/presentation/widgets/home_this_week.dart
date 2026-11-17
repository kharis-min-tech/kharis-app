import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:kharis_app/features/calendar/data/branch_service_events.dart';
import 'package:kharis_app/features/calendar/data/event_repository.dart';
import 'package:kharis_app/features/calendar/presentation/widgets/event_card.dart'
    show reminderOutcomeMessage;
import 'package:kharis_app/shared/providers/campus_config_provider.dart';
import 'package:kharis_app/shared/providers/clock_provider.dart';
import 'package:kharis_app/shared/providers/event_reminders_provider.dart';
import 'package:kharis_app/shared/providers/notification_feed_provider.dart';
import 'package:kharis_app/ui/components/components.dart';

/// How far ahead "This week" looks.
const Duration kHomeThisWeekWindow = Duration(days: 7);

/// The branch's events in the next seven days, soonest first: the list the
/// Events screen shows (Studio events for Home's branch and for all
/// branches, with the branch's weekly services), cut to this week.
final homeThisWeekEventsProvider = Provider<AsyncValue<List<Event>>>((ref) {
  final now = ref.watch(clockProvider)();
  final today = DateTime(now.year, now.month, now.day);
  final until = now.add(kHomeThisWeekWindow);
  final branch = ref.watch(homeCampusProvider);
  return ref
      .watch(campusUpcomingEventsProvider)
      .whenData(
        (events) => [
          for (final e in withBranchServiceEvents(events, branch, now: now))
            if (!e.startTime.isBefore(today) && e.startTime.isBefore(until)) e,
        ]..sort((a, b) => a.startTime.compareTo(b.startTime)),
      );
});

/// "This week" on Home: the branch's events in the next seven days, each
/// opening its event and offering "Remind me", then a link to every event.
class HomeThisWeek extends ConsumerWidget {
  const HomeThisWeek({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(homeThisWeekEventsProvider);
    final events = async.valueOrNull;

    final Widget body;
    if (events == null) {
      body = async.hasError
          ? KErrorState(
              key: const Key('home-events-error'),
              message: 'Couldn\u2019t load this week\u2019s events.',
              onRetry: () => unawaited(refreshCampusContent(ref)),
            )
          : const Column(
              key: Key('home-events-loading'),
              mainAxisSize: MainAxisSize.min,
              children: [
                KSkeleton(height: KSize.dateBlockHeight + KSpace.section),
                SizedBox(height: KSpace.md),
                KSkeleton(height: KSize.dateBlockHeight + KSpace.section),
              ],
            );
    } else if (events.isEmpty) {
      body = const KEmptyState(
        key: Key('home-events-empty'),
        icon: KIcons.calendar,
        title: 'Nothing on this week',
        hint: 'See what is coming up later.',
      );
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (i, event) in events.indexed) ...[
            if (i > 0) const SizedBox(height: KSpace.md),
            _EventRow(event),
          ],
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(header: true, child: const KOverline('This week')),
        const SizedBox(height: KSpace.lg),
        body,
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: KTextLink(
            key: const Key('home-events-see-all'),
            label: 'All events',
            showChevron: true,
            // Events is a pushed route: swipe back returns to Home.
            onTap: () => context.push('/calendar'),
          ),
        ),
      ],
    );
  }
}

class _EventRow extends ConsumerWidget {
  const _EventRow(this.event);

  final Event event;

  Future<void> _toggle(BuildContext context, WidgetRef ref) async {
    // Both read before the await: the row may be gone when it answers.
    final toggle = ref.read(toggleEventReminderProvider);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final outcome = await toggle(event);
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(reminderOutcomeMessage(outcome, event)),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reminded = ref.watch(isEventRemindedProvider(event.id));
    // A reminder already on can always be turned off.
    final canRemind =
        reminded || ref.watch(eventReminderServiceProvider).canRemind(event);
    final start = event.startTime;
    final time = DateFormat('HH:mm').format(start);
    final place = event.location?.trim();

    return KEventCard(
      key: Key('home-event-${event.id}'),
      month: DateFormat('EEE').format(start),
      day: '${start.day}',
      dateSemanticLabel: DateFormat('EEE d MMM').format(start),
      title: event.title,
      meta: place == null || place.isEmpty ? time : '$time \u00b7 $place',
      onTap: () => context.push('/events/${event.id}'),
      toggle: canRemind
          ? KToggleButton(
              key: Key('home-event-remind-${event.id}'),
              label: 'Remind me',
              selectedLabel: 'Reminder on',
              icon: KIcons.bell,
              selected: reminded,
              semanticLabel: reminded
                  ? 'Reminder on for ${event.title}'
                  : 'Remind me about ${event.title}',
              onChanged: (_) => unawaited(_toggle(context, ref)),
            )
          : null,
    );
  }
}
