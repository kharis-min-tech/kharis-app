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

const double _kTileWidth = 250;
const double _kTileHeight = 96;

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
        height: _kTileHeight,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 2,
          separatorBuilder: (_, _) => const SizedBox(width: 12),
          itemBuilder: (_, _) => const Skeleton(
            width: _kTileWidth,
            height: _kTileHeight,
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
      height: _kTileHeight,
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
    final place = eventPlaceLabel(event);
    final when =
        '${DateFormat('EEE').format(event.startTime)} \u00b7 '
        '${DateFormat('h:mm a').format(event.startTime)}';
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: AppRadius.cardBorder,
        boxShadow: AppShadows.card,
      ),
      child: Material(
        color: context.kc.surface,
        borderRadius: AppRadius.cardBorder,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => openEventDetail(context, event),
          child: SizedBox(
            width: _kTileWidth,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: context.kc.chipBg,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          DateFormat('d').format(event.startTime),
                          style: AppTypography.ui(
                            size: 19,
                            weight: FontWeight.w800,
                            height: 1,
                          ).copyWith(color: context.kc.onChip),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          DateFormat(
                            'MMM',
                          ).format(event.startTime).toUpperCase(),
                          style: AppTypography.ui(
                            size: 10,
                            weight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ).copyWith(color: context.kc.onChip),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          event.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.ui(
                            size: 14.5,
                            weight: FontWeight.w700,
                          ).copyWith(color: context.kc.onBg),
                        ),
                        const SizedBox(height: 4),
                        _Line(icon: Icons.schedule_rounded, text: when),
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
      ),
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
