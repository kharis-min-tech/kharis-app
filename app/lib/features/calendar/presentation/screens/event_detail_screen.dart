import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:kharis_app/core/constants/app_links.dart';
import 'package:kharis_app/features/calendar/data/branch_service_events.dart';
import 'package:kharis_app/features/calendar/data/event_repository.dart';
import 'package:kharis_app/features/calendar/presentation/widgets/event_card.dart';
import 'package:kharis_app/shared/providers/admin_provider.dart';
import 'package:kharis_app/shared/providers/event_reminders_provider.dart';
import 'package:kharis_app/shared/providers/sermon_provider.dart';
import 'package:kharis_app/ui/components/components.dart';

/// One event, read fresh by document id. `null` when the doc does not exist
/// (deleted, or a stale push) or could not be read. A branch service id
/// (`service:<branchId>:<serviceId>`) resolves from the branches list, not
/// the Studio events table.
final eventByIdProvider = FutureProvider.autoDispose.family<Event?, String>((
  ref,
  id,
) async {
  if (isBranchServiceEventId(id)) {
    final branches = await ref.watch(branchesProvider.future);
    return branchServiceEventById(branches, id, now: DateTime.now());
  }
  return ref.watch(eventRepositoryProvider).getEventById(id);
});

/// "In 3 days" style status for [event] relative to [now].
///
/// A weekly event is dated at its next occurrence, so this is about that
/// occurrence: the label says how far away it is, that it is on now, or that
/// it has ended.
String eventStatusLabel(Event event, DateTime now) {
  if (event.isPastAt(now)) return 'This event has ended';
  if (!event.startTime.isAfter(now)) return 'Happening now';
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(
    event.startTime.year,
    event.startTime.month,
    event.startTime.day,
  );
  final days = day.difference(today).inDays;
  if (days == 0) {
    final minutes = event.startTime.difference(now).inMinutes;
    if (minutes < 60) return 'Starts in ${minutes < 1 ? 1 : minutes} min';
    return 'Today';
  }
  if (days == 1) return 'Tomorrow';
  if (days < 7) return 'In $days days';
  final weeks = (days / 7).floor();
  return weeks == 1 ? 'In 1 week' : 'In $weeks weeks';
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// "19:00 – 21:00", or with the end date when the event spans days.
String eventTimeRange(Event event) {
  final time = DateFormat('HH:mm');
  final start = time.format(event.startTime);
  final end = event.endTime;
  if (end == null || !end.isAfter(event.startTime)) return start;
  return _sameDay(event.startTime, end)
      ? '$start \u2013 ${time.format(end)}'
      : '$start \u2013 ${DateFormat('EEE d MMM, HH:mm').format(end)}';
}

String? _clean(String? raw) {
  final value = raw?.trim();
  return value == null || value.isEmpty ? null : value;
}

/// The text handed to the share sheet for [event]: title, day and time,
/// where (venue and address, else the branch), then the Kharis link.
String eventShareText(Event event) {
  final next =
      '${DateFormat('EEEE d MMMM yyyy').format(event.startTime)}, '
      '${eventTimeRange(event)}';
  final repeats = event.recurrenceLabel;
  final when = repeats == null ? next : '$repeats (next: $next)';
  final place = [
    _clean(event.location),
    _clean(event.address),
  ].whereType<String>().join(', ');
  final where = place.isNotEmpty ? place : _clean(event.branch);
  return [
    event.title.trim(),
    when,
    ?where,
    AppLinks.shareLine(AppLinks.event(event.id)),
  ].join('\n');
}

/// Maps search URL for [query]: Apple Maps on iOS/macOS, Google Maps elsewhere
/// (both open the native app when it is installed).
Uri directionsUri(String query, {required TargetPlatform platform}) {
  final apple =
      platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;
  return apple
      ? Uri.https('maps.apple.com', '/', {'q': query})
      : Uri.https('www.google.com', '/maps/search/', {
          'api': '1',
          'query': query,
        });
}

/// Full event page: photo, when and where it is with directions, the
/// description, "Remind me", and RSVP / add-to-calendar / share actions.
///
/// Reached from event cards, Home, announcements that promote an event and
/// event pushes (`/events/:id`). [initial] paints immediately when the caller
/// already holds the event; the doc is still re-read so an edit in Content
/// Studio is reflected.
class EventDetailScreen extends ConsumerWidget {
  const EventDetailScreen({super.key, required this.eventId, this.initial});

  final String eventId;
  final Event? initial;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(eventByIdProvider(eventId));
    final event = async.valueOrNull ?? initial;

    return Scaffold(
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: KSize.maxContentWidth),
            child: event != null
                ? _EventBody(event: event)
                : async.isLoading
                ? const _DetailSkeleton()
                : _Unavailable(
                    onRetry: () => ref.invalidate(eventByIdProvider(eventId)),
                  ),
          ),
        ),
      ),
    );
  }
}

/// Returns to the events list: pops when it is the screen underneath,
/// otherwise (a deep link or push tap opened this event directly) pushes it.
void _backToEvents(BuildContext context) {
  final router = GoRouter.of(context);
  final stack = router.routerDelegate.currentConfiguration.matches;
  final onEvents =
      stack.length > 1 &&
      Uri.parse(stack[stack.length - 2].matchedLocation).path == '/calendar';
  onEvents ? router.pop() : router.push('/calendar');
}

const EdgeInsets _pagePadding = EdgeInsets.fromLTRB(
  KSpace.gutter,
  KSpace.md,
  KSpace.gutter,
  KSpace.section,
);

class _EventBody extends ConsumerWidget {
  const _EventBody({required this.event});

  final Event event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final k = context.k;
    final now = DateTime.now();
    final isPast = event.isPastAt(now);
    final isRsvped = ref.watch(isEventRsvpedProvider(event.id));
    final reminded = ref.watch(isEventRemindedProvider(event.id));
    final canRemind =
        !isPast && ref.watch(eventReminderServiceProvider).canRemind(event);
    final imageUrl = _clean(event.imageUrl);
    final venue = _clean(event.location);
    final address = _clean(event.address);
    final place = venue ?? address;
    // Venue and address together locate a hall inside a larger building far
    // better than either alone.
    final mapsQuery = [venue, address].whereType<String>().join(', ');
    final description = _clean(event.description);
    final date = DateFormat('EEEE d MMMM yyyy').format(event.startTime);

    return SingleChildScrollView(
      padding: _pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (imageUrl != null) ...[
            ClipRRect(
              borderRadius: const BorderRadius.all(
                Radius.circular(KRadius.card),
              ),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: KImageFill(image: CachedNetworkImageProvider(imageUrl)),
              ),
            ),
            const SizedBox(height: KSpace.x3),
          ],
          KOverline(
            eventRepeatsLabel(event) ?? eventStatusLabel(event, now),
            key: event.isWeekly ? const Key('event-detail-recurrence') : null,
          ),
          const SizedBox(height: KSpace.sm),
          Semantics(
            header: true,
            child: Text(
              event.title,
              style: KharisText.pageTitle.copyWith(color: k.text),
            ),
          ),
          const SizedBox(height: KSpace.x3),
          _InfoRow(
            icon: KIcons.calendar,
            title: event.isWeekly ? 'Next: $date' : date,
            meta: eventTimeRange(event),
          ),
          if (place != null) ...[
            const SizedBox(height: KSpace.xl),
            _InfoRow(
              key: const Key('event-detail-venue'),
              icon: KIcons.pin,
              title: place,
              meta: venue != null ? address : null,
              action: KTextLink(
                label: 'Get directions',
                showChevron: true,
                onTap: () => _openDirections(context, mapsQuery),
              ),
            ),
          ],
          const SizedBox(height: KSpace.xl),
          _InfoRow(
            icon: KIcons.users,
            title: _clean(event.branch) ?? 'All branches',
            meta: 'Branch',
          ),
          if (description != null) ...[
            const SizedBox(height: KSpace.section),
            Text(description, style: KharisText.body.copyWith(color: k.text)),
          ],
          const SizedBox(height: KSpace.section),
          if (canRemind) ...[
            MergeSemantics(
              child: Semantics(
                toggled: reminded,
                child: KButton(
                  key: const Key('event-detail-remind'),
                  label: reminded ? 'Reminder on' : 'Remind me',
                  icon: reminded ? KIcons.check : KIcons.bell,
                  variant: reminded
                      ? KButtonVariant.tonal
                      : KButtonVariant.primary,
                  size: KButtonSize.cta,
                  expand: true,
                  onPressed: () => toggleEventReminder(context, ref, event),
                ),
              ),
            ),
            const SizedBox(height: KSpace.md),
          ],
          if (!isPast) ...[
            MergeSemantics(
              child: Semantics(
                toggled: isRsvped,
                child: KButton(
                  key: const Key('event-detail-rsvp'),
                  label: isRsvped ? 'Going' : 'RSVP',
                  icon: isRsvped ? KIcons.check : null,
                  variant: KButtonVariant.outline,
                  expand: true,
                  onPressed: () => toggleEventRsvp(context, ref, event),
                ),
              ),
            ),
            const SizedBox(height: KSpace.md),
          ],
          KButton(
            label: 'Add to calendar',
            icon: KIcons.calendar,
            variant: KButtonVariant.outline,
            expand: true,
            onPressed: () => addEventToCalendar(context, event),
          ),
          const SizedBox(height: KSpace.md),
          KButton(
            label: 'Share',
            icon: KIcons.share,
            variant: KButtonVariant.text,
            expand: true,
            onPressed: _share,
          ),
          Center(
            child: KTextLink(
              label: 'All events',
              showChevron: true,
              onTap: () => _backToEvents(context),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openDirections(BuildContext context, String query) async {
    final messenger = ScaffoldMessenger.of(context);
    final uri = directionsUri(query, platform: defaultTargetPlatform);
    final opened = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    ).catchError((Object _) => false);
    if (!opened) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(eventToast('Couldn\u2019t open maps.'));
    }
  }

  void _share() {
    unawaited(
      SharePlus.instance.share(ShareParams(text: eventShareText(event))),
    );
  }
}

/// One fact about the event: a small icon, the fact, and an optional second
/// line and link under it.
class _InfoRow extends StatelessWidget {
  const _InfoRow({
    super.key,
    required this.icon,
    required this.title,
    this.meta,
    this.action,
  });

  final String icon;
  final String title;
  final String? meta;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: KSpace.xxs),
          child: KIcon(icon, size: KSize.iconMd, color: k.muted),
        ),
        const SizedBox(width: KSpace.xl),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: KharisText.body.copyWith(color: k.text)),
              if (meta != null)
                Text(meta!, style: KharisText.meta.copyWith(color: k.muted)),
              ?action,
            ],
          ),
        ),
      ],
    );
  }
}

/// Blocks where the overline, title, facts and main button will be.
class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();

  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(
      physics: NeverScrollableScrollPhysics(),
      padding: _pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FractionallySizedBox(
            widthFactor: 0.3,
            child: KSkeleton(height: KSize.iconXs, radius: KRadius.xs),
          ),
          SizedBox(height: KSpace.sm),
          FractionallySizedBox(
            widthFactor: 0.7,
            child: KSkeleton(height: KSize.iconLg),
          ),
          SizedBox(height: KSpace.x3),
          FractionallySizedBox(
            widthFactor: 0.6,
            child: KSkeleton(height: KSize.icon, radius: KRadius.xs),
          ),
          SizedBox(height: KSpace.xl),
          FractionallySizedBox(
            widthFactor: 0.5,
            child: KSkeleton(height: KSize.icon, radius: KRadius.xs),
          ),
          SizedBox(height: KSpace.section),
          KSkeleton(height: KSize.cta, radius: KRadius.button),
        ],
      ),
    );
  }
}

class _Unavailable extends StatelessWidget {
  const _Unavailable({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: KEmptyState(
          icon: KIcons.calendar,
          title: 'This event isn\u2019t available',
          hint:
              'It may have been removed. Check your connection and try '
              'again.',
          action: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              KButton(
                label: 'Try again',
                variant: KButtonVariant.outline,
                onPressed: onRetry,
              ),
              const SizedBox(height: KSpace.xs),
              KTextLink(
                label: 'All events',
                showChevron: true,
                onTap: () => _backToEvents(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
