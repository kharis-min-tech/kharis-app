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
import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/features/calendar/data/event_repository.dart';
import 'package:kharis_app/features/calendar/presentation/widgets/event_card.dart';
import 'package:kharis_app/shared/providers/sermon_provider.dart';
import 'package:kharis_app/shared/widgets/skeleton.dart';

/// One event, read fresh by document id. `null` when the doc does not exist
/// (deleted, or a stale push) or could not be read.
final eventByIdProvider = FutureProvider.autoDispose.family<Event?, String>((
  ref,
  id,
) {
  return ref.watch(eventRepositoryProvider).getEventById(id);
});

/// "Starts in 3 days" style status for [event] relative to [now].
///
/// Events carry no recurrence rule, so the next occurrence IS the event: the
/// label says how far away it is, that it is on now, or that it has ended.
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

/// "7:00 PM – 9:00 PM", or with both dates when the event spans days.
String eventTimeRange(Event event) {
  final time = DateFormat('h:mm a');
  final start = time.format(event.startTime);
  final end = event.endTime;
  if (end == null || !end.isAfter(event.startTime)) return start;
  final sameDay =
      end.year == event.startTime.year &&
      end.month == event.startTime.month &&
      end.day == event.startTime.day;
  return sameDay
      ? '$start \u2013 ${time.format(end)}'
      : '$start \u2013 ${DateFormat('EEE d MMM, h:mm a').format(end)}';
}

/// The text handed to the share sheet for [event]: title, day and time,
/// where (venue and address, else the campus), then the Kharis link.
String eventShareText(Event event) {
  String? clean(String? raw) {
    final value = raw?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  final when =
      '${DateFormat('EEEE d MMMM yyyy').format(event.startTime)}, '
      '${eventTimeRange(event)}';
  final place = [
    clean(event.location),
    clean(event.address),
  ].whereType<String>().join(', ');
  final where = place.isNotEmpty ? place : clean(event.branch);
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

/// Full event page: banner, date and time with how soon it is, venue and
/// address with directions, the description, and RSVP / add-to-calendar /
/// share actions.
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

    if (event == null) {
      return Scaffold(
        appBar: _plainBar(context),
        body: async.isLoading
            ? const _DetailSkeleton()
            : _Unavailable(
                onRetry: () => ref.invalidate(eventByIdProvider(eventId)),
              ),
      );
    }
    return Scaffold(body: _EventBody(event: event));
  }

  PreferredSizeWidget _plainBar(BuildContext context) => AppBar(
    backgroundColor: Colors.transparent,
    elevation: 0,
    leading: _BackButton(color: context.kc.onBg),
    title: Text(
      'Event',
      style: AppTypography.titleMd.copyWith(color: context.kc.onBg),
    ),
  );
}

/// Pops when there is somewhere to go back to; otherwise (a cold-start deep
/// link) lands on the Events tab instead of closing the app.
class _BackButton extends StatelessWidget {
  const _BackButton({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Back',
      icon: Icon(Icons.arrow_back_rounded, color: color),
      onPressed: () {
        final router = GoRouter.of(context);
        router.canPop() ? router.pop() : router.go('/calendar');
      },
    );
  }
}

class _EventBody extends ConsumerWidget {
  const _EventBody({required this.event});

  final Event event;

  String? get _venue => _clean(event.location);
  String? get _address => _clean(event.address);

  static String? _clean(String? raw) {
    final value = raw?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  /// What maps should search for: venue and address together locate a hall
  /// inside a larger building far better than either alone.
  String? get _mapsQuery {
    final parts = [_venue, _address].whereType<String>().toList();
    return parts.isEmpty ? null : parts.join(', ');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final isPast = event.isPastAt(now);
    final isRsvped = ref.watch(isEventRsvpedProvider(event.id));
    final campus = _clean(event.branch) ?? 'All branches';
    final description = _clean(event.description);
    final mapsQuery = _mapsQuery;

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          expandedHeight: 220,
          backgroundColor: AppColors.primaryDeep,
          leading: const _BackButton(color: Colors.white),
          actions: [
            IconButton(
              tooltip: 'Share event',
              icon: const Icon(Icons.ios_share_rounded, color: Colors.white),
              onPressed: () => _share(),
            ),
          ],
          flexibleSpace: FlexibleSpaceBar(background: _Banner(event: event)),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.marginMobile,
              22,
              AppSpacing.marginMobile,
              40,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _StatusPill(label: eventStatusLabel(event, now), past: isPast),
                const SizedBox(height: 12),
                Text(
                  event.title,
                  style: AppTypography.display(
                    size: 26,
                    weight: FontWeight.w700,
                  ).copyWith(color: context.kc.onBg, height: 1.15),
                ),
                const SizedBox(height: 20),
                _InfoBlock(
                  icon: Icons.calendar_today_rounded,
                  title: DateFormat('EEEE d MMMM yyyy').format(event.startTime),
                  subtitle: eventTimeRange(event),
                ),
                const SizedBox(height: 16),
                _InfoBlock(
                  key: const Key('event-detail-venue'),
                  icon: Icons.place_outlined,
                  title: _venue ?? _address ?? campus,
                  subtitle: _venue != null ? _address : null,
                  trailing: mapsQuery == null
                      ? null
                      : TextButton.icon(
                          onPressed: () => _openDirections(context, mapsQuery),
                          icon: const Icon(Icons.directions_rounded, size: 18),
                          label: const Text('Get directions'),
                          style: TextButton.styleFrom(
                            foregroundColor: context.kc.accentInk,
                          ),
                        ),
                ),
                const SizedBox(height: 16),
                _InfoBlock(
                  icon: Icons.church_outlined,
                  title: campus,
                  subtitle: 'Branch',
                ),
                if (description != null) ...[
                  const SizedBox(height: 26),
                  Text(
                    'About this event',
                    style: AppTypography.ui(
                      size: 15,
                      weight: FontWeight.w700,
                    ).copyWith(color: context.kc.onBg),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    description,
                    style: AppTypography.bodyLg.copyWith(
                      color: context.kc.onBg,
                      height: 1.55,
                    ),
                  ),
                ],
                const SizedBox(height: 30),
                Row(
                  children: [
                    if (!isPast) ...[
                      Expanded(
                        child: FilledButton(
                          // DESIGN.md: one CTA style, gold with gold ink.
                          style: FilledButton.styleFrom(
                            backgroundColor: isRsvped
                                ? context.kc.surfaceAlt
                                : context.kc.accent,
                            foregroundColor: isRsvped
                                ? context.kc.onBg
                                : context.kc.onAccent,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppRadius.button,
                              ),
                            ),
                          ),
                          onPressed: () => toggleEventRsvp(context, ref, event),
                          child: Text(isRsvped ? 'Going \u2713' : 'RSVP'),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: context.kc.onBg,
                          side: BorderSide(color: context.kc.outline),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppRadius.button,
                            ),
                          ),
                        ),
                        onPressed: () => addEventToCalendar(context, event),
                        icon: const Icon(
                          Icons.event_available_rounded,
                          size: 18,
                        ),
                        label: const Text('Add to calendar'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
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
        ..showSnackBar(
          const SnackBar(content: Text('Couldn\u2019t open maps.')),
        );
    }
  }

  void _share() {
    unawaited(
      SharePlus.instance.share(ShareParams(text: eventShareText(event))),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.event});

  final Event event;

  @override
  Widget build(BuildContext context) {
    // Solid brand fill when the event has no photo (or it fails).
    const fallback = ColoredBox(color: AppColors.primaryDeep);
    final url = event.imageUrl;
    final image = (url == null || url.isEmpty)
        ? fallback
        : CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.cover,
            placeholder: (_, _) => fallback,
            errorWidget: (_, _, _) => fallback,
          );
    // Top scrim keeps the white back/share icons legible over any photo.
    return Stack(
      fit: StackFit.expand,
      children: [
        image,
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.center,
              colors: [
                Colors.black.withValues(alpha: 0.45),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.past});

  final String label;
  final bool past;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: past ? context.kc.surfaceMuted : context.kc.chipBg,
        borderRadius: AppRadius.pillBorder,
      ),
      child: Text(
        label,
        style: AppTypography.ui(
          size: 12,
          weight: FontWeight.w700,
        ).copyWith(color: past ? context.kc.muted : context.kc.onChip),
      ),
    );
  }
}

class _InfoBlock extends StatelessWidget {
  const _InfoBlock({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final subtitle = this.subtitle;
    final trailing = this.trailing;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: context.kc.chipBg,
            borderRadius: BorderRadius.circular(AppRadius.tile),
          ),
          child: Icon(icon, size: 20, color: context.kc.onChip),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 2),
              Text(
                title,
                style: AppTypography.ui(
                  size: 15,
                  weight: FontWeight.w600,
                ).copyWith(color: context.kc.onBg),
              ),
              if (subtitle != null && subtitle.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppTypography.ui(
                    size: 13.5,
                  ).copyWith(color: context.kc.muted),
                ),
              ],
              if (trailing != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Transform.translate(
                    // Optically align the button text with the lines above.
                    offset: const Offset(-12, 0),
                    child: trailing,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(AppSpacing.marginMobile),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Skeleton(width: double.infinity, height: 180, radius: AppRadius.card),
          SizedBox(height: 22),
          SkeletonLine(width: 220, height: 24),
          SizedBox(height: 16),
          SkeletonLine(width: 180),
          SizedBox(height: 10),
          SkeletonLine(width: 140),
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
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_busy_outlined, color: context.kc.muted, size: 44),
            const SizedBox(height: 14),
            Text(
              'This event isn\u2019t available',
              textAlign: TextAlign.center,
              style: AppTypography.ui(
                size: 15,
                weight: FontWeight.w600,
              ).copyWith(color: context.kc.onBg),
            ),
            const SizedBox(height: 6),
            Text(
              'It may have been removed, or we couldn\u2019t reach the '
              'server. Check your connection and try again.',
              textAlign: TextAlign.center,
              style: AppTypography.ui(
                size: 13,
              ).copyWith(color: context.kc.muted),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: [
                TextButton(onPressed: onRetry, child: const Text('Try again')),
                TextButton(
                  onPressed: () => context.go('/calendar'),
                  child: const Text('All events'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
