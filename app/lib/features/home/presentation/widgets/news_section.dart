import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/features/home/data/news_repository.dart';
import 'package:kharis_app/shared/providers/notification_feed_provider.dart';
import 'package:kharis_app/shared/widgets/skeleton.dart';

import 'announcement_detail.dart';

// Brand gradient pairs cycled across announcement cards.
const _kCardGradients = [
  [Color(0xFF6B1E8B), Color(0xFF2A0A52)],
  [Color(0xFF1A0A3B), Color(0xFF6B34FA)],
  [Color(0xFF2A0A1A), Color(0xFFDC3F9E)],
  [Color(0xFF0A2A1A), Color(0xFF059669)],
  [Color(0xFF3B1A0A), Color(0xFFF59E0B)],
];

const double _kCardWidth = 220;
const double _kCardHeight = 164;

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
            child: _AnnouncementCard(
              item: item,
              gradientColors: _kCardGradients[i % _kCardGradients.length],
            ),
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

class _AnnouncementCard extends ConsumerWidget {
  const _AnnouncementCard({required this.item, required this.gradientColors});

  final NewsItem item;
  final List<Color> gradientColors;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventId = item.eventId;
    final event = eventId == null
        ? null
        : ref.watch(linkedEventProvider(eventId));
    final venue = event == null ? null : eventVenueLine(event);
    final cta = item.linkUrl == null ? null : item.ctaLabel;
    final body = item.body?.trim();

    return Semantics(
      button: true,
      label: item.title,
      child: GestureDetector(
        // Opens what the announcement is about: the promoted event, or the
        // full text and its call to action.
        onTap: () => openAnnouncement(context, item),
        child: Container(
          width: _kCardWidth,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.card),
            boxShadow: AppShadows.card,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gradientColors,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Admin-set image over the gradient, under the scrim.
              if (item.imageUrl != null && item.imageUrl!.isNotEmpty)
                Positioned.fill(
                  child: Image.network(
                    item.imageUrl!,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),
              // Bottom scrim
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: 120,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: .7),
                      ],
                    ),
                  ),
                ),
              ),

              // Content
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _TagPill(
                        icon: eventId != null
                            ? Icons.event_rounded
                            : Icons.campaign_rounded,
                        label: eventId != null ? 'Event' : item.type,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item.title,
                        style: AppTypography.titleMd.copyWith(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.15,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      // One supporting line: where (for an event), else the
                      // call to action, else the body.
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
    );
  }
}

class _TagPill extends StatelessWidget {
  const _TagPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: .25),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            label.toUpperCase(),
            style: AppTypography.labelMd.copyWith(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: 0.9,
              height: 1,
            ),
          ),
        ],
      ),
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
    final color = Colors.white.withValues(alpha: strong ? 1 : .85);
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
          ],
          Expanded(
            child: Text(
              text,
              style: AppTypography.bodySm.copyWith(
                fontSize: 12.5,
                fontWeight: strong ? FontWeight.w700 : FontWeight.w500,
                color: color,
                height: 1.3,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
