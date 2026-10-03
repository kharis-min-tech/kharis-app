import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/features/calendar/data/event_repository.dart';
import 'package:kharis_app/features/calendar/presentation/screens/event_detail_screen.dart';
import 'package:kharis_app/features/home/data/news_repository.dart';
import 'package:kharis_app/shared/providers/notification_feed_provider.dart';

/// The event an announcement promotes: taken from the already-loaded campus
/// list when it is there (no extra read), else read by id. `null` while that
/// read is in flight or when the event no longer exists.
final linkedEventProvider = Provider.autoDispose.family<Event?, String>((
  ref,
  eventId,
) {
  final upcoming = ref.watch(campusUpcomingEventsProvider).valueOrNull;
  final hit = upcoming?.where((e) => e.id == eventId).firstOrNull;
  if (hit != null) return hit;
  return ref.watch(eventByIdProvider(eventId)).valueOrNull;
});

/// Venue line for an event: "Main Hall · 12 High St", or whichever half is
/// known. `null` when the event has neither.
String? eventVenueLine(Event event) {
  final parts = [
    event.location,
    event.address,
  ].map((s) => s?.trim() ?? '').where((s) => s.isNotEmpty).toList();
  return parts.isEmpty ? null : parts.join(' \u00b7 ');
}

/// Opens what an announcement is about: the event it promotes when it is
/// linked to one, otherwise its full text (with its call-to-action link).
/// Shared by the Home carousel, the announcements feed and push deep links so
/// a tap means the same thing everywhere.
void openAnnouncement(BuildContext context, NewsItem item) {
  final eventId = item.eventId?.trim();
  if (eventId != null && eventId.isNotEmpty) {
    context.push('/events/${Uri.encodeComponent(eventId)}');
    return;
  }
  showAnnouncementDetail(context, item);
}

/// Bottom sheet with an announcement's untruncated body, image and CTA.
Future<void> showAnnouncementDetail(BuildContext context, NewsItem item) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.kc.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (_) => AnnouncementDetailSheet(item: item),
  );
}

class AnnouncementDetailSheet extends StatelessWidget {
  const AnnouncementDetailSheet({super.key, required this.item});

  final NewsItem item;

  @override
  Widget build(BuildContext context) {
    final body = item.body?.trim();
    final image = item.imageUrl?.trim();
    final link = item.linkUrl?.trim();
    final uri = (link == null || link.isEmpty) ? null : Uri.tryParse(link);
    final canOpen =
        uri != null && (uri.scheme == 'https' || uri.scheme == 'http');

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.kc.divider,
                    borderRadius: AppRadius.pillBorder,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                item.type.toUpperCase(),
                style: AppTypography.labelMd.copyWith(
                  color: context.kc.muted,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                item.title,
                style: AppTypography.ui(
                  size: 19,
                  weight: FontWeight.w700,
                  color: context.kc.onBg,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                DateFormat('EEEE d MMMM yyyy').format(item.publishedAt),
                style: AppTypography.bodySm.copyWith(color: context.kc.muted),
              ),
              if (image != null && image.isNotEmpty) ...[
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: CachedNetworkImage(
                    imageUrl: image,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    errorWidget: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),
              ],
              if (body != null && body.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  body,
                  style: AppTypography.bodyLg.copyWith(
                    color: context.kc.onBg,
                    height: 1.5,
                  ),
                ),
              ],
              if (canOpen) ...[
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    key: const Key('announcement-cta'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.button),
                      ),
                    ),
                    onPressed: () => unawaited(
                      launchUrl(
                        uri,
                        mode: LaunchMode.externalApplication,
                      ).catchError((Object _) => false),
                    ),
                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                    label: Text(
                      item.ctaLabel?.trim().isNotEmpty == true
                          ? item.ctaLabel!.trim()
                          : 'Learn more',
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
