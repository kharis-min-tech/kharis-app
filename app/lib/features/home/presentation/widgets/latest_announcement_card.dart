import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/shared/providers/notification_feed_provider.dart';
import 'package:kharis_app/shared/widgets/press_effect.dart';

import 'announcement_detail.dart';

const double _kThumbSize = 64;

/// The newest live announcement for the member's branch (plus all-branch
/// notices), from the same feed and in the same order as the full list
/// ([campusNewsProvider], newest first), as one compact card: its image when
/// it has one, the date and the title. Tapping opens it exactly as the
/// announcements list does ([openAnnouncement]).
///
/// Renders nothing (not even [padding]) while the feed is loading, when it
/// failed, or when nothing is published.
class LatestAnnouncementCard extends ConsumerWidget {
  const LatestAnnouncementCard({super.key, this.padding = EdgeInsets.zero});

  /// Space around the card, applied only when it shows.
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(campusNewsProvider).valueOrNull;
    if (items == null || items.isEmpty) return const SizedBox.shrink();
    final item = items.first;

    final kc = context.kc;
    final eventId = item.eventId;
    final event = eventId == null
        ? null
        : ref.watch(linkedEventProvider(eventId));
    // An event's own date is what matters; otherwise when it was posted.
    final when = event != null
        ? DateFormat('EEE d MMM \u00b7 h:mm a').format(event.startTime)
        : DateFormat('d MMM').format(item.publishedAt);
    final image = item.imageUrl?.trim();
    final hasImage = image != null && image.isNotEmpty;

    return Padding(
      key: const Key('home-announcement-latest'),
      padding: padding,
      child: Semantics(
        button: true,
        label: '${item.title}, $when',
        excludeSemantics: true,
        child: PressEffect(
          onTap: () => openAnnouncement(context, item),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: kc.surface,
              borderRadius: AppRadius.cardBorder,
              boxShadow: AppShadows.card,
            ),
            child: Row(
              children: [
                // Admin-set image; a failed load leaves the chip fill rather
                // than a broken frame.
                if (hasImage) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.tile),
                    child: SizedBox.square(
                      dimension: _kThumbSize,
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
                  ),
                  const SizedBox(width: 14),
                ],
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          when,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.ui(
                            size: 11.5,
                            weight: FontWeight.w600,
                          ).copyWith(color: kc.muted, height: 1.2),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          item.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.ui(
                            size: 15,
                            weight: FontWeight.w700,
                          ).copyWith(color: kc.onBg, height: 1.25),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right_rounded, size: 22, color: kc.muted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
