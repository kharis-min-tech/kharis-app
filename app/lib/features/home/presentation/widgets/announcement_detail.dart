import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:kharis_app/ui/components/components.dart';
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

/// Share of the screen height the announcement sheet's content may take
/// before it scrolls.
const double _sheetMaxHeight = 0.75;

/// Bottom sheet with an announcement's untruncated body, image and CTA.
Future<void> showAnnouncementDetail(BuildContext context, NewsItem item) {
  return showKBottomSheet<void>(
    context: context,
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
    final k = context.k;
    final body = item.body?.trim();
    final image = item.imageUrl?.trim();
    final uri = announcementLink(item);
    final eventId = item.eventId?.trim();
    final event = (eventId == null || eventId.isEmpty)
        ? null
        : ref.watch(linkedEventProvider(eventId));
    final published = item.publishedAt;
    final date = DateFormat(
      published.year == DateTime.now().year ? 'EEEE d MMMM' : 'EEEE d MMMM y',
    ).format(published);

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * _sheetMaxHeight,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            KOverline(item.type),
            const SizedBox(height: KSpace.sm),
            Semantics(
              header: true,
              child: Text(
                item.title,
                style: KharisText.pageTitle.copyWith(color: k.text),
              ),
            ),
            const SizedBox(height: KSpace.sm),
            Text(date, style: KharisText.meta.copyWith(color: k.muted)),
            if (image != null && image.isNotEmpty) ...[
              const SizedBox(height: KSpace.x3),
              ClipRRect(
                borderRadius: const BorderRadius.all(
                  Radius.circular(KRadius.tile),
                ),
                child: ColoredBox(
                  color: k.surface2,
                  child: CachedNetworkImage(
                    imageUrl: image,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    errorWidget: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),
              ),
            ],
            if (body != null && body.isNotEmpty) ...[
              const SizedBox(height: KSpace.x3),
              Text(body, style: KharisText.body.copyWith(color: k.text)),
            ],
            const SizedBox(height: KSpace.gutter),
            if (uri != null) ...[
              KButton(
                key: const Key('announcement-cta'),
                label: item.ctaLabel?.trim().isNotEmpty == true
                    ? item.ctaLabel!.trim()
                    : 'Open link',
                expand: true,
                onPressed: () => unawaited(
                  launchUrl(
                    uri,
                    mode: LaunchMode.inAppBrowserView,
                  ).catchError((Object _) => false),
                ),
              ),
              const SizedBox(height: KSpace.md),
            ],
            if (event != null) ...[
              KButton(
                key: const Key('announcement-event'),
                label: 'View event',
                icon: KIcons.calendar,
                variant: KButtonVariant.outline,
                expand: true,
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
              ),
              const SizedBox(height: KSpace.md),
            ],
            KButton(
              key: const Key('announcement-close'),
              label: 'Close',
              variant: KButtonVariant.text,
              expand: true,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}
