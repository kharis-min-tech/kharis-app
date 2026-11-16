import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:kharis_app/features/home/data/news_repository.dart';
import 'package:kharis_app/features/home/presentation/widgets/announcement_detail.dart';
import 'package:kharis_app/shared/providers/notification_feed_provider.dart';
import 'package:kharis_app/ui/components/components.dart';

/// Width of a carousel item that leaves [KSize.edgeFade] of the next one
/// showing: [perView] items, their gaps and the peek fit the screen.
double homeCarouselItemWidth(
  BuildContext context, {
  required double gap,
  int perView = 1,
}) {
  final width = MediaQuery.sizeOf(context).width;
  final room = width > KSize.maxContentWidth ? KSize.maxContentWidth : width;
  return (room - KSpace.gutter - KSize.edgeFade - gap * perView) / perView;
}

/// The branch's announcements as a carousel of cards (date, title, the
/// start of the text, a link to the whole announcement), the next card
/// peeking in. A single announcement takes the full width. Renders
/// nothing until there is at least one.
class HomeBranchNews extends ConsumerWidget {
  const HomeBranchNews({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(campusNewsProvider).valueOrNull;
    if (items == null || items.isEmpty) return const SizedBox.shrink();

    if (items.length == 1) {
      return Padding(
        key: const Key('home-announcements'),
        padding: const EdgeInsets.symmetric(horizontal: KSpace.gutter),
        child: _NewsCard(items.single),
      );
    }

    final width = homeCarouselItemWidth(context, gap: KSpace.xl);
    return SingleChildScrollView(
      key: const Key('home-announcements'),
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: KSpace.gutter),
      // Shadows of the cards are not cut off at the bottom.
      clipBehavior: Clip.none,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (i, item) in items.indexed) ...[
              if (i > 0) const SizedBox(width: KSpace.xl),
              SizedBox(width: width, child: _NewsCard(item)),
            ],
          ],
        ),
      ),
    );
  }
}

class _NewsCard extends ConsumerWidget {
  const _NewsCard(this.item);

  final NewsItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventId = item.eventId;
    final event = eventId == null
        ? null
        : ref.watch(linkedEventProvider(eventId));
    // An event's own date is what matters; otherwise when it was posted.
    final date = event?.startTime ?? item.publishedAt;
    final body = item.body?.trim();
    final cta = item.ctaLabel?.trim();

    return KAnnouncementCard(
      key: Key('home-announcement-${item.id}'),
      month: DateFormat('MMM').format(date),
      day: '${date.day}',
      dateSemanticLabel: DateFormat('EEE d MMM').format(date),
      title: item.title,
      snippet: body == null || body.isEmpty ? null : body,
      actionLabel: cta == null || cta.isEmpty ? 'Read more' : cta,
      onTap: () => openAnnouncement(context, item),
    );
  }
}
