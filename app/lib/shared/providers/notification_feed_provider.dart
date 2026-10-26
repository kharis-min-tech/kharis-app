import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/calendar/data/branch_service_events.dart';
import '../../features/calendar/data/event_repository.dart';
import '../../features/home/data/news_repository.dart';
import 'admin_provider.dart';
import 'branch_provider.dart';
import 'campus_config_provider.dart';
import 'dismissed_notifications_provider.dart';
import 'sermon_provider.dart';

/// Row ids the notifications feed assigns to announcements and event
/// reminders. Kept here — not inside the screen — so the Home
/// bell and the feed can never disagree about what "dismissed" means.
String announcementNotificationId(String newsId) => 'news:$newsId';
String eventNotificationId(String eventId) => 'event:$eventId';

// ── Campus scoping ────────────────────────────────────────────────────────────
//
// Content Studio's campus rule (`NewsItem.isVisibleTo` / `Event.isVisibleTo`):
// an item with no campus (null, absent or blank) is all-campus and shows
// everywhere; an unscoped (`null`) view sees everything; otherwise the
// item's campus must equal the view's. The API applies the same rule
// server-side. It is re-applied here because the client also reads the
// Firestore fallback and realtime streams, and a stale API build must never
// leak another campus's notice onto this member's Home.

/// Runs [read] against [scope] once it is known and keeps only what
/// [visible] allows. While the scope is still resolving the result is
/// loading: fetching an unscoped feed first would flash every campus's
/// content and then swap it out.
AsyncValue<List<T>> _forCampus<T>(
  AsyncValue<String?> scope,
  AsyncValue<List<T>> Function(String? branch) read,
  bool Function(T item, String? branch) visible,
) {
  if (!scope.hasValue && !scope.hasError) return const AsyncLoading();
  final branch = scope.valueOrNull;
  return read(branch).whenData(
    (items) => [
      for (final item in items)
        if (visible(item, branch)) item,
    ],
  );
}

/// Announcements for Home's branch ([homeBranchProvider]) plus all-campus
/// ones that are live right now: published (scheduled posts stay hidden
/// until their time) and not expired. What Home, the bell and the feeds
/// render.
final campusNewsProvider = Provider<AsyncValue<List<NewsItem>>>((ref) {
  return _forCampus<NewsItem>(
    ref.watch(homeBranchProvider),
    (branch) => ref.watch(newsProvider(branch)),
    (n, branch) => n.isLive && n.isVisibleTo(branch),
  );
});

/// Upcoming events for Home's branch ([homeBranchProvider]) plus all-campus
/// events: Home's strip and Next service card, the bell and the feeds.
final campusUpcomingEventsProvider = Provider<AsyncValue<List<Event>>>((ref) {
  return _forCampus<Event>(
    ref.watch(homeBranchProvider),
    (branch) => ref.watch(upcomingEventsProvider(branch)),
    (e, branch) => e.isVisibleTo(branch),
  );
});

// ── Events tab ────────────────────────────────────────────────────────────────

/// The Events tab's "All branches" browse filter. Session-only and never the
/// member's branch: it resets on the next launch and leaves Home alone.
final eventsShowAllBranchesProvider = StateProvider<bool>((ref) => false);

/// The branch the Events tab lists: null (every branch) while the browse
/// filter is on or the member has not chosen one, else their branch.
final eventsBranchProvider = Provider<AsyncValue<String?>>((ref) {
  if (ref.watch(eventsShowAllBranchesProvider)) return const AsyncData(null);
  return ref.watch(currentBranchProvider);
});

/// Upcoming events the Events tab lists ([eventsBranchProvider]): the
/// Studio's events plus the weekly services of [homeCampusProvider] (the
/// member's branch, or Home's branch while browsing "All branches"), so a
/// branch that meets is never "No upcoming events". A Studio weekly event
/// for that branch on a service's weekday replaces the generated one (see
/// [withBranchServiceEvents]).
final eventsUpcomingProvider = Provider<AsyncValue<List<Event>>>((ref) {
  final studio = _forCampus<Event>(
    ref.watch(eventsBranchProvider),
    (branch) => ref.watch(upcomingEventsProvider(branch)),
    (e, branch) => e.isVisibleTo(branch),
  );
  bool pending(AsyncValue<Object?> v) => !v.hasValue && !v.hasError;
  // An empty Studio list waits for the branch's services rather than
  // flashing "No upcoming events" before they arrive.
  if (studio.valueOrNull?.isEmpty ?? false) {
    if (pending(ref.watch(homeBranchProvider)) ||
        pending(ref.watch(branchesProvider))) {
      return const AsyncLoading();
    }
  }
  final home = ref.watch(homeCampusProvider);
  return studio.whenData(
    (events) => withBranchServiceEvents(events, home, now: DateTime.now()),
  );
});

/// Recent past events the Events tab lists ([eventsBranchProvider]).
final eventsPastProvider = Provider<AsyncValue<List<Event>>>((ref) {
  return _forCampus<Event>(
    ref.watch(eventsBranchProvider),
    (branch) => ref.watch(pastEventsProvider(branch)),
    (e, branch) => e.isVisibleTo(branch),
  );
});

/// Refetches Home's announcement and event feeds ([homeBranchProvider])
/// and completes when both have answered (or given up), so a
/// pull-to-refresh spinner stays up exactly as long as the reload. Never
/// throws: failures surface through the providers' own error states.
Future<void> refreshCampusContent(WidgetRef ref) {
  final branch = ref.read(homeBranchProvider).valueOrNull;
  return Future.wait<void>([
    settleRefresh(ref.refresh(newsProvider(branch).future)),
    settleRefresh(ref.refresh(upcomingEventsProvider(branch).future)),
  ]);
}

/// Refetches the Events tab's list ([eventsBranchProvider]): upcoming, or
/// past with [pastEvents]. Never throws, like [refreshCampusContent].
Future<void> refreshEventsContent(WidgetRef ref, {bool pastEvents = false}) {
  final branch = ref.read(eventsBranchProvider).valueOrNull;
  return settleRefresh(
    pastEvents
        ? ref.refresh(pastEventsProvider(branch).future)
        : ref.refresh(upcomingEventsProvider(branch).future),
  );
}

/// Swallows the outcome of a refresh future and caps how long a spinner can
/// wait on it (a realtime stream that never emits must not pin the
/// indicator).
Future<void> settleRefresh(Future<Object?> pending) => pending
    .timeout(const Duration(seconds: 15))
    .then<void>((_) {}, onError: (Object _) {});

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
  return news.any(
        (n) => !dismissed.contains(announcementNotificationId(n.id)),
      ) ||
      events.any((e) => !dismissed.contains(eventNotificationId(e.id)));
});
