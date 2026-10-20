import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/features/calendar/data/event_repository.dart';
import 'package:kharis_app/features/calendar/presentation/widgets/event_card.dart';
import 'package:kharis_app/shared/providers/branch_provider.dart';
import 'package:kharis_app/shared/providers/notification_feed_provider.dart';
import 'package:kharis_app/shared/widgets/skeleton.dart';

/// How many upcoming events Home previews; the Events tab has the rest.
const int kHomeEventPreviewCount = 5;

const double _kTileWidth = 236;

/// A tile's height: the picture plus its text block, which grows with the
/// member's text size.
double _tileHeight(BuildContext context) =>
    _kTileMedia + MediaQuery.textScalerOf(context).scale(100);

/// Height of a tile's picture: the flyer, or the date when there is none.
const double _kTileMedia = 136;

/// "Today", "Tomorrow", else "Sat 11 Oct", then the start (and end, when
/// set) time: `Tomorrow · 7:00 PM – 9:00 PM`. A weekly event shows its
/// next day and its rule: `Sun 18 Oct · Every Sunday · 10:00 AM`.
@visibleForTesting
String eventWhenLabel(Event event, {DateTime? now}) {
  final today = DateUtils.dateOnly(now ?? DateTime.now());
  final day = DateUtils.dateOnly(event.startTime);
  final diff = day.difference(today).inDays;
  final dayLabel = switch (diff) {
    0 => 'Today',
    1 => 'Tomorrow',
    _ => DateFormat('EEE d MMM').format(event.startTime),
  };
  if (event.recurrenceLabel case final repeats?) {
    return '$dayLabel \u00b7 $repeats';
  }
  final time = DateFormat('h:mm a');
  final end = event.endTime;
  final range = end != null && DateUtils.isSameDay(end, event.startTime)
      ? '${time.format(event.startTime)} \u2013 ${time.format(end)}'
      : time.format(event.startTime);
  return '$dayLabel \u00b7 $range';
}

/// Home's "Upcoming events" strip: the next few events Content Studio has
/// published for the member's campus plus all-campus events, each showing
/// when and where (venue) and opening the event detail on tap.
class UpcomingEventsStrip extends ConsumerWidget {
  const UpcomingEventsStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(campusUpcomingEventsProvider);
    final events = async.valueOrNull;

    if (events == null) {
      if (async.hasError) {
        return _StripMessage(
          text: 'Couldn\u2019t load events.',
          actionLabel: 'Retry',
          onAction: () => refreshCampusContent(ref),
        );
      }
      return SizedBox(
        key: const Key('events-strip-skeleton'),
        height: _tileHeight(context),
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 2,
          separatorBuilder: (_, _) => const SizedBox(width: 12),
          itemBuilder: (_, _) => Skeleton(
            width: _kTileWidth,
            height: _tileHeight(context),
            radius: AppRadius.card,
          ),
        ),
      );
    }

    if (events.isEmpty) {
      final campus = ref.watch(currentBranchProvider).valueOrNull;
      return _StripMessage(
        text: campus == null
            ? 'No upcoming events yet.'
            : 'No upcoming events at $campus yet.',
      );
    }

    final preview = events.take(kHomeEventPreviewCount).toList();
    return SizedBox(
      height: _tileHeight(context),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(right: 20),
        itemCount: preview.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, i) => _EventTile(event: preview[i]),
      ),
    );
  }
}

class _EventTile extends StatelessWidget {
  const _EventTile({required this.event});

  final Event event;

  @override
  Widget build(BuildContext context) {
    final kc = context.kc;
    final place = eventPlaceLabel(event);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: AppRadius.cardBorder,
        boxShadow: AppShadows.card,
      ),
      child: Material(
        color: kc.surface,
        borderRadius: AppRadius.cardBorder,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => openEventDetail(context, event),
          child: SizedBox(
            width: _kTileWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: _kTileMedia,
                  child: _TileMedia(event: event),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.ui(
                          size: 15,
                          weight: FontWeight.w700,
                        ).copyWith(color: kc.onBg, height: 1.25),
                      ),
                      const SizedBox(height: 6),
                      _Line(
                        icon: Icons.schedule_rounded,
                        text: eventWhenLabel(event),
                      ),
                      if (place != null) ...[
                        const SizedBox(height: 2),
                        _Line(icon: Icons.place_outlined, text: place),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The top of an event tile: the Studio's flyer filling it, else the date
/// set large on the brand tint.
class _TileMedia extends StatelessWidget {
  const _TileMedia({required this.event});

  final Event event;

  @override
  Widget build(BuildContext context) {
    final kc = context.kc;
    final date = Container(
      color: kc.chipBg,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            DateFormat('EEEE').format(event.startTime).toUpperCase(),
            style: AppTypography.ui(
              size: 11,
              weight: FontWeight.w700,
              letterSpacing: 1.2,
            ).copyWith(color: kc.onChip, height: 1),
          ),
          const SizedBox(height: 6),
          Text(
            DateFormat('d MMM').format(event.startTime),
            style: AppTypography.display(
              size: 40,
              weight: FontWeight.w700,
            ).copyWith(color: kc.onChip, height: 1),
          ),
        ],
      ),
    );
    final url = event.imageUrl;
    if (url == null) return date;
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      alignment: Alignment.topCenter,
      placeholder: (_, _) => ColoredBox(color: kc.chipBg),
      errorWidget: (_, _, _) => date,
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 12, color: context.kc.muted),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.ui(size: 12).copyWith(color: context.kc.muted),
          ),
        ),
      ],
    );
  }
}

class _StripMessage extends StatelessWidget {
  const _StripMessage({required this.text, this.actionLabel, this.onAction});

  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final actionLabel = this.actionLabel;
    return Padding(
      padding: const EdgeInsets.only(right: 20),
      child: Container(
        constraints: const BoxConstraints(minHeight: 64),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: context.kc.surface,
          borderRadius: AppRadius.cardBorder,
          boxShadow: AppShadows.card,
        ),
        child: Row(
          children: [
            Icon(Icons.event_note_outlined, color: context.kc.muted, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: AppTypography.ui(
                  size: 13.5,
                ).copyWith(color: context.kc.muted),
              ),
            ),
            if (actionLabel != null)
              TextButton(
                onPressed: onAction,
                child: Text(
                  actionLabel,
                  style: AppTypography.ui(
                    size: 13,
                    weight: FontWeight.w700,
                  ).copyWith(color: context.kc.accentInk),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
