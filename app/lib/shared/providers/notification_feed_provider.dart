import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'branch_provider.dart';
import 'dismissed_notifications_provider.dart';
import 'sermon_provider.dart';

/// Row ids the notifications feed assigns to announcements and event
/// reminders. Kept here — not inside the screen — so the Home bell and the
/// feed can never disagree about what "dismissed" means.
String announcementNotificationId(String newsId) => 'news:$newsId';
String eventNotificationId(String eventId) => 'event:$eventId';

/// True while the notifications feed holds at least one row the member has
/// not dismissed. Drives the Home bell's dot (KA-023): the dot used to be
/// painted unconditionally, so a fresh install showed "you have something"
/// over a feed that said "No notifications yet". While the feed is still
/// loading this is `false` — a badge the tap can't back up is worse than none.
final hasPendingNotificationsProvider = Provider<bool>((ref) {
  final branch = ref.watch(currentBranchProvider).valueOrNull;
  final news = ref.watch(newsProvider(branch)).valueOrNull ?? const [];
  final events =
      ref.watch(upcomingEventsProvider(branch)).valueOrNull ?? const [];
  final dismissed = ref.watch(dismissedNotificationsProvider);
  return news.any(
        (n) => !dismissed.contains(announcementNotificationId(n.id)),
      ) ||
      events.any((e) => !dismissed.contains(eventNotificationId(e.id)));
});
