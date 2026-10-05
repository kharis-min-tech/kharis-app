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
/// linked to one that still exists, otherwise its full text (with its
/// call-to-action link). Shared by the Home carousel, the announcements feed
/// and push deep links so a tap means the same thing everywhere.
///
/// Never a dead end: an event that has been deleted (or cannot be read) falls
/// back to the announcement itself, and a legacy item carrying both an event
/// and a link opens the full text with both actions, so neither is lost.
Future<void> openAnnouncement(BuildContext context, NewsItem item) async {
  final eventId = item.eventId?.trim();
  if (eventId == null || eventId.isEmpty || announcementLink(item) != null) {
    await showAnnouncementDetail(context, item);
    return;
  }
  final event = await _findEvent(
    ProviderScope.containerOf(context, listen: false),
    eventId,
  );
  if (!context.mounted) return;
  if (event == null) {
    await showAnnouncementDetail(context, item);
    return;
  }
  unawaited(
    context.push('/events/${Uri.encodeComponent(eventId)}', extra: event),
  );
}

/// The event [id], from the loaded campus list when it is there, else read
/// once. `null` when it no longer exists or cannot be read.
Future<Event?> _findEvent(ProviderContainer container, String id) async {
  final cached = container
      .read(campusUpcomingEventsProvider)
      .valueOrNull
      ?.where((e) => e.id == id)
      .firstOrNull;
  if (cached != null) return cached;
  // Listened, not read: an unlistened autoDispose provider can be torn down
  // before its future completes.
  final sub = container.listen(eventByIdProvider(id).future, (_, _) {});
  try {
    return await sub.read();
  } catch (_) {
    return null;
  } finally {
    sub.close();
  }
}

/// The announcement's call-to-action link when it is an http(s) address.
Uri? announcementLink(NewsItem item) {
  final link = item.linkUrl?.trim();
  if (link == null || link.isEmpty) return null;
  final uri = Uri.tryParse(link);
  return uri != null && (uri.scheme == 'https' || uri.scheme == 'http')
      ? uri
      : null;
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

/// The full announcement: untruncated body, image, its call-to-action link
/// and, when it promotes an event that still exists, a way to open it.
class AnnouncementDetailSheet extends ConsumerWidget {
  const AnnouncementDetailSheet({super.key, required this.item});

  final NewsItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final body = item.body?.trim();
    final image = item.imageUrl?.trim();
    final uri = announcementLink(item);
    final eventId = item.eventId?.trim();
    final event = (eventId == null || eventId.isEmpty)
        ? null
        : ref.watch(linkedEventProvider(eventId));

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
              if (event != null) ...[
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    key: const Key('announcement-event'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: context.kc.onBg,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.button),
                      ),
                    ),
                    onPressed: () {
                      final router = GoRouter.of(context);
                      Navigator.of(context).pop();
                      unawaited(
                        router.push(
                          '/events/${Uri.encodeComponent(event.id)}',
                          extra: event,
                        ),
                      );
                    },
                    icon: const Icon(Icons.event_rounded, size: 18),
                    label: const Text('View event'),
                  ),
                ),
              ],
              if (uri != null) ...[
                SizedBox(height: event != null ? 10 : 22),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    key: const Key('announcement-cta'),
                    // DESIGN.md: one CTA style, gold with gold ink.
                    style: FilledButton.styleFrom(
                      backgroundColor: context.kc.accent,
                      foregroundColor: context.kc.onAccent,
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
                          : 'Open link',
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
