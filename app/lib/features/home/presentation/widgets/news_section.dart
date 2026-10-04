import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/features/home/data/news_repository.dart';
import 'package:kharis_app/shared/providers/notification_feed_provider.dart';
import 'package:kharis_app/shared/widgets/skeleton.dart';

import 'announcement_detail.dart';

const double _kCardWidth = 252;
const double _kCardHeight = 204;
const double _kImageHeight = 92;

/// "Announcements" horizontal carousel: exactly what Content Studio has
/// published for the member's campus plus all-campus notices
/// ([campusNewsProvider]). Loading, empty and failed are three different
/// states — "No announcements" is only ever said when it is true.
class AnnouncementsCarousel extends ConsumerWidget {
  const AnnouncementsCarousel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final newsAsync = ref.watch(campusNewsProvider);
    final items = newsAsync.valueOrNull;

    if (items == null) {
      if (newsAsync.hasError) {
        return _CarouselMessage(
          icon: Icons.wifi_off_rounded,
          text: 'Couldn\u2019t load announcements.',
          actionLabel: 'Retry',
          onAction: () => refreshCampusContent(ref),
        );
      }
      return const _CarouselSkeleton();
    }

    if (items.isEmpty) {
      return const _CarouselMessage(
        icon: Icons.campaign_outlined,
        text: 'No announcements',
      );
    }

    return SizedBox(
      height: _kCardHeight,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(right: 20),
        itemCount: items.length,
        itemBuilder: (context, i) {
          final item = items[i];
          return Padding(
            padding: EdgeInsets.only(right: i < items.length - 1 ? 12 : 0),
            child: _AnnouncementCard(item: item),
          );
        },
      ),
    );
  }
}

class _CarouselSkeleton extends StatelessWidget {
  const _CarouselSkeleton();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const Key('announcements-skeleton'),
      height: _kCardHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 2,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (_, _) => const Skeleton(
          width: _kCardWidth,
          height: _kCardHeight,
          radius: AppRadius.card,
        ),
      ),
    );
  }
}

class _CarouselMessage extends StatelessWidget {
  const _CarouselMessage({
    required this.icon,
    required this.text,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final actionLabel = this.actionLabel;
    return Padding(
      padding: const EdgeInsets.only(right: 20),
      child: Container(
        constraints: const BoxConstraints(minHeight: 72),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: context.kc.surface,
          borderRadius: AppRadius.cardBorder,
          boxShadow: AppShadows.card,
        ),
        child: Row(
          children: [
            Icon(icon, color: context.kc.muted, size: 20),
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

/// One announcement: optional Studio image on top, then what it is and
/// when, the title, and one supporting line (where, for an event; else the
/// call to action; else the opening of the body). Opens the promoted event
/// or the full announcement.
class _AnnouncementCard extends ConsumerWidget {
  const _AnnouncementCard({required this.item});

  final NewsItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kc = context.kc;
    final eventId = item.eventId;
    final event = eventId == null
        ? null
        : ref.watch(linkedEventProvider(eventId));
    final venue = event == null ? null : eventVenueLine(event);
    final cta = item.linkUrl == null ? null : item.ctaLabel;
    final body = item.body?.trim();
    final image = item.imageUrl?.trim();
    final hasImage = image != null && image.isNotEmpty;
    // An event's own date is what matters; otherwise when it was posted.
    final when = event != null
        ? DateFormat('EEE d MMM \u00b7 h:mm a').format(event.startTime)
        : DateFormat('d MMM').format(item.publishedAt);

    return Semantics(
      button: true,
      label: item.title,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: AppRadius.cardBorder,
          boxShadow: AppShadows.card,
        ),
        child: Material(
          color: kc.surface,
          borderRadius: AppRadius.cardBorder,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            // Opens what the announcement is about: the promoted event, or
            // the full text and its call to action.
            onTap: () => openAnnouncement(context, item),
            child: SizedBox(
              width: _kCardWidth,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Admin-set image; a failed load collapses to the chip
                  // fill rather than a broken frame.
                  if (hasImage)
                    SizedBox(
                      height: _kImageHeight,
                      width: double.infinity,
                      child: ColoredBox(
                        color: kc.chipBg,
                        child: Image.network(
                          image,
                          fit: BoxFit.cover,
                          gaplessPlayback: true,
                          errorBuilder: (_, _, _) => const SizedBox.shrink(),
                        ),
                      ),
                    ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _MetaRow(
                            icon: eventId != null
                                ? Icons.event_rounded
                                : Icons.campaign_rounded,
                            label: eventId != null ? 'Event' : item.type,
                            when: when,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            item.title,
                            style: AppTypography.ui(
                              size: hasImage ? 15 : 17,
                              weight: FontWeight.w700,
                            ).copyWith(color: kc.onBg, height: 1.25),
                            maxLines: hasImage ? 2 : 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const Spacer(),
                          // One supporting line: where (for an event), else
                          // the call to action, else the body.
                          if (venue != null)
                            _CardLine(icon: Icons.place_outlined, text: venue)
                          else if (cta != null)
                            _CardLine(
                              icon: Icons.arrow_forward_rounded,
                              text: cta,
                              strong: true,
                            )
                          else if (body != null && body.isNotEmpty)
                            _CardLine(text: body),
                        ],
                      ),
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

/// "EVENT · Sat 11 Oct · 7:00 PM" / "NEWS · 3 Oct": the kind in brand
/// purple, the date in muted text.
class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.icon, required this.label, required this.when});

  final IconData icon;
  final String label;
  final String when;

  @override
  Widget build(BuildContext context) {
    final kc = context.kc;
    return Row(
      children: [
        Icon(icon, size: 13, color: kc.onChip),
        const SizedBox(width: 5),
        Text(
          label.toUpperCase(),
          style: AppTypography.ui(
            size: 10.5,
            weight: FontWeight.w800,
            letterSpacing: 0.9,
          ).copyWith(color: kc.onChip, height: 1),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            when,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.ui(
              size: 11.5,
              weight: FontWeight.w600,
            ).copyWith(color: kc.muted, height: 1),
          ),
        ),
      ],
    );
  }
}

class _CardLine extends StatelessWidget {
  const _CardLine({required this.text, this.icon, this.strong = false});

  final String text;
  final IconData? icon;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final icon = this.icon;
    final color = strong ? context.kc.onChip : context.kc.muted;
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
        ],
        Expanded(
          child: Text(
            text,
            style: AppTypography.ui(
              size: 12.5,
              weight: strong ? FontWeight.w700 : FontWeight.w500,
            ).copyWith(color: color, height: 1.3),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
