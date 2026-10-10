import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/calendar/data/event_repository.dart';
import '../../features/home/data/news_repository.dart';
import '../../features/home/data/studio_notification_repository.dart';
import 'branch_provider.dart';
import 'dismissed_notifications_provider.dart';
import 'sermon_provider.dart';

/// Row ids the notifications feed assigns to announcements, event reminders
/// and Studio notifications. Kept here — not inside the screen — so the Home
/// bell and the feed can never disagree about what "dismissed" means.
String announcementNotificationId(String newsId) => 'news:$newsId';
String eventNotificationId(String eventId) => 'event:$eventId';
String studioNotificationId(String id) => 'studio:$id';

// ── Campus scoping ────────────────────────────────────────────────────────────
//
// Content Studio's campus rule (`NewsItem.isVisibleTo` / `Event.isVisibleTo`):
// an item with no campus (null, absent or blank) is all-campus and shows
// everywhere; a member on "All campuses" sees everything; otherwise the
// item's campus must equal the member's. The API applies the same rule
// server-side. It is re-applied here because the client also reads the
// Firestore fallback and realtime streams, and a stale API build must never
// leak another campus's notice onto this member's Home.

/// Runs [read] against the member's campus once it is known and keeps only
/// what [visible] allows. While the campus is still resolving the result is
/// loading: fetching an unscoped feed first would flash every campus's
/// content and then swap it out.
AsyncValue<List<T>> _forCampus<T>(
  Ref ref,
  AsyncValue<List<T>> Function(String? branch) read,
  bool Function(T item, String? branch) visible,
) {
  final campus = ref.watch(currentBranchProvider);
  if (!campus.hasValue && !campus.hasError) return const AsyncLoading();
  final branch = campus.valueOrNull;
  return read(branch).whenData(
    (items) => [
      for (final item in items)
        if (visible(item, branch)) item,
    ],
  );
}

/// Announcements for the member's campus (plus all-campus ones) that are
/// live right now: published (scheduled posts stay hidden until their time)
/// and not expired. What Home, the bell and the feeds render.
final campusNewsProvider = Provider<AsyncValue<List<NewsItem>>>((ref) {
  return _forCampus<NewsItem>(
    ref,
    (branch) => ref.watch(newsProvider(branch)),
    (n, branch) => n.isLive && n.isVisibleTo(branch),
  );
});

/// Upcoming events for the member's campus plus all-campus events.
final campusUpcomingEventsProvider = Provider<AsyncValue<List<Event>>>((ref) {
  return _forCampus<Event>(
    ref,
    (branch) => ref.watch(upcomingEventsProvider(branch)),
    (e, branch) => e.isVisibleTo(branch),
  );
});

/// Recent past events for the member's campus plus all-campus events.
final campusPastEventsProvider = Provider<AsyncValue<List<Event>>>((ref) {
  return _forCampus<Event>(
    ref,
    (branch) => ref.watch(pastEventsProvider(branch)),
    (e, branch) => e.isVisibleTo(branch),
  );
});

/// Refetches the campus announcement and event feeds and completes when both
/// have answered (or given up), so a pull-to-refresh spinner stays up exactly
/// as long as the reload. Never throws: failures surface through the
/// providers' own error states.
Future<void> refreshCampusContent(WidgetRef ref, {bool pastEvents = false}) {
  final branch = ref.read(currentBranchProvider).valueOrNull;
  return Future.wait<void>([
    settleRefresh(ref.refresh(newsProvider(branch).future)),
    settleRefresh(ref.refresh(upcomingEventsProvider(branch).future)),
    if (pastEvents)
      settleRefresh(ref.refresh(pastEventsProvider(branch).future)),
  ]);
}

/// Swallows the outcome of a refresh future and caps how long a spinner can
/// wait on it (a realtime stream that never emits must not pin the
/// indicator).
Future<void> settleRefresh(Future<Object?> pending) => pending
    .timeout(const Duration(seconds: 15))
    .then<void>((_) {}, onError: (Object _) {});

// ── Studio notifications ──────────────────────────────────────────────────────

final studioNotificationRepositoryProvider =
    Provider<StudioNotificationRepository>(
      (ref) =>
          StudioNotificationRepository(firestore: ref.watch(firestoreProvider)),
    );

/// Sent Studio notifications for one audience (everyone, or one branch).
final sentNotificationsProvider = StreamProvider.autoDispose
    .family<List<StudioNotification>, NotificationAudience>(
      (ref, audience) =>
          ref.watch(studioNotificationRepositoryProvider).watchSent(audience),
    );

/// Merges per-audience lists into one inbox: each notification once, newest
/// send first, at most [kNotificationPageSize].
List<StudioNotification> mergeSentNotifications(
  Iterable<List<StudioNotification>> lists,
) {
  final byId = <String, StudioNotification>{
    for (final list in lists)
      for (final n in list) n.id: n,
  };
  final epoch = DateTime.fromMillisecondsSinceEpoch(0);
  final merged = byId.values.toList()
    ..sort((a, b) => (b.sentAt ?? epoch).compareTo(a.sentAt ?? epoch));
  return merged.take(kNotificationPageSize).toList(growable: false);
}

/// What Studio sent to this member: everything sent to everyone plus their
/// branch's, newest first. A member on "All branches" follows no branch
/// topic, so they get the church-wide ones only, matching their pushes.
final inboxNotificationsProvider =
    Provider<AsyncValue<List<StudioNotification>>>((ref) {
      final campus = ref.watch(currentBranchProvider);
      if (!campus.hasValue && !campus.hasError) return const AsyncLoading();
      final branch = campus.valueOrNull?.trim() ?? '';
      final sources = [
        ref.watch(sentNotificationsProvider(const NotificationAudience.all())),
        if (branch.isNotEmpty)
          ref.watch(
            sentNotificationsProvider(NotificationAudience.branch(branch)),
          ),
      ];
      final loaded = [
        for (final s in sources)
          if (s.hasValue) s.requireValue,
      ];
      if (loaded.isEmpty) {
        final failed = sources.where((s) => s.hasError).firstOrNull;
        return failed == null
            ? const AsyncLoading()
            : AsyncError(
                failed.error!,
                failed.stackTrace ?? StackTrace.current,
              );
      }
      return AsyncData(mergeSentNotifications(loaded));
    });

// ── Bell ──────────────────────────────────────────────────────────────────────

/// True while the notifications feed holds at least one row the member has
/// not dismissed. Drives the Home bell's dot (KA-023): the dot used to be
/// painted unconditionally, so a fresh install showed "you have something"
/// over a feed that said "No notifications yet". While the feed is still
/// loading this is `false` — a badge the tap can't back up is worse than none.
final hasPendingNotificationsProvider = Provider<bool>((ref) {
  final news = ref.watch(campusNewsProvider).valueOrNull ?? const [];
  final events =
      ref.watch(campusUpcomingEventsProvider).valueOrNull ?? const [];
  final dismissed = ref.watch(dismissedNotificationsProvider);
  final studio = ref.watch(inboxNotificationsProvider).valueOrNull ?? const [];
  return news.any(
        (n) => !dismissed.contains(announcementNotificationId(n.id)),
      ) ||
      events.any((e) => !dismissed.contains(eventNotificationId(e.id))) ||
      studio.any((n) => !dismissed.contains(studioNotificationId(n.id)));
});
