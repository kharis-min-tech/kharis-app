import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/sermon_categorizer.dart';
import '../../core/services/firebase_service.dart';
import '../../features/calendar/data/event_repository.dart';
import '../../features/calendar/data/rsvp_repository.dart';
import '../../features/home/data/daily_content_repository.dart';
import '../../features/home/data/news_repository.dart';
import '../../features/home/data/kharis_api_announcement_repository.dart';
import '../../features/home/data/live_repository.dart';
import '../../features/messages/data/firestore_sermon_repository.dart';
import '../../features/messages/data/kharis_api_sermon_repository.dart';
import '../../features/messages/data/sermon_collections_repository.dart';
import '../../features/messages/data/video_repository.dart';
import '../../features/messages/data/kharis_content.dart';
import '../../features/messages/data/sermon_repository_base.dart';
import '../models/sermon.dart';
import 'audio_provider.dart';
import 'cache_provider.dart';

// ── Repository ────────────────────────────────────────────────────────────────

final sermonRepositoryProvider = Provider<AbstractSermonRepository>((ref) {
  // Kharis public sermon API (yetanothersermon.host). Falls back to the bundled
  // catalogue via sermonsProvider's catch if the network is unreachable.
  return KharisApiSermonRepository();
});

// ── Sermons (live fetch) ──────────────────────────────────────────────────────
/// The public API library on its own.
///
/// Deliberately has no CMS dependency: [sermonsProvider] watches a Firestore
/// *stream*, and if the network fetch lived there too, every CMS emission —
/// including the one that lands moments after first build — would re-run four
/// more API round-trips behind an already-populated list. Keeping the fetch
/// here means a CMS change re-runs only the cheap merge below.
///
/// Invalidate this (not [sermonsProvider]) to force a real library refresh.
final apiSermonsProvider = FutureProvider<List<Sermon>>((ref) async {
  final repo = ref.watch(sermonRepositoryProvider);
  try {
    return await repo.getSermons();
  } catch (_) {
    // Offline / CI fallback - never leaves the user with an empty screen.
    return repo.loadCatalogue();
  }
});

/// All audio sermons, freshest source first.
///
/// Two sources, merged: the CMS (`sermons` collection, what the admin panel
/// writes) layered over the public Kharis sermon API, deduped by title with
/// the CMS winning. Without the merge an admin-added sermon would only ever be
/// visible inside the admin panel. Falls back to the bundled 500-episode
/// catalogue when the API is unreachable.
final sermonsProvider = FutureProvider<List<Sermon>>((ref) async {
  // Live stream, so a CMS edit re-emits the library without a manual refresh.
  final cms = ref.watch(adminSermonsProvider).valueOrNull ?? const <Sermon>[];
  final cmsAudio = cms
      .where((s) => s.source != 'youtube' && s.videoId == null)
      .toList();

  final api = await ref.watch(apiSermonsProvider.future);

  final seen = <String>{for (final s in cmsAudio) _dedupeTitle(s.title)};
  return [
    ...cmsAudio,
    ...api.where((s) => seen.add(_dedupeTitle(s.title))),
  ];
});

/// Title reduced to alphanumerics for cross-source dedupe.
String _dedupeTitle(String title) =>
    title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

// ── Library sort + filter ─────────────────────────────────────────────────────

/// Sort orders for the message library.
enum SermonSort { newest, oldest, longest, shortest, az }

extension SermonSortLabel on SermonSort {
  String get label => switch (this) {
        SermonSort.newest => 'Newest',
        SermonSort.oldest => 'Oldest',
        SermonSort.longest => 'Longest',
        SermonSort.shortest => 'Shortest',
        SermonSort.az => 'A-Z',
      };
}

/// Active sort order. Defaults to newest-first.
final sermonSortProvider = StateProvider<SermonSort>((ref) {
  final cache = ref.read(cacheServiceProvider);
  // ignore: deprecated_member_use
  ref.listenSelf((_, next) => cache.cachePreference('last_sort', next.name));
  final savedName = cache.getPreference<String>('last_sort', 'newest');
  return SermonSort.values.firstWhere(
    (e) => e.name == savedName,
    orElse: () => SermonSort.newest,
  );
});

/// Active category filter — a label from [kSermonCategories]. 'All' = none.
final selectedCategoryProvider = StateProvider<String>((ref) {
  final cache = ref.read(cacheServiceProvider);
  // ignore: deprecated_member_use
  ref.listenSelf((_, next) => cache.cachePreference('last_category', next));
  return cache.getPreference<String>('last_category', 'All');
});

/// Categories that actually occur in the loaded library, in display order.
/// Always starts with 'All'; buckets with zero sermons are hidden.
final categoryLabelsProvider = Provider<List<String>>((ref) {
  final sermonsAsync = ref.watch(sermonsProvider);
  final present = sermonsAsync.when(
    data: (sermons) => sermons.map((s) => s.category).whereType<String>().toSet(),
    loading: () => const <String>{},
    error: (_, _) => const <String>{},
  );
  return [
    'All',
    for (final c in kSermonCategories)
      if (c != 'All' && present.contains(c)) c,
  ];
});

/// The library list: category-filtered and sorted. Pagination happens in the UI.
final librarySermonsProvider = Provider<List<Sermon>>((ref) {
  final sermonsAsync = ref.watch(sermonsProvider);
  final category = ref.watch(selectedCategoryProvider);
  final sort = ref.watch(sermonSortProvider);

  return sermonsAsync.when(
    data: (sermons) {
      final filtered = category == 'All'
          ? List.of(sermons)
          : sermons.where((s) => s.category == category).toList();
      switch (sort) {
        case SermonSort.newest:
          filtered.sort((a, b) => (b.publishedAt ?? DateTime(0))
              .compareTo(a.publishedAt ?? DateTime(0)));
        case SermonSort.oldest:
          filtered.sort((a, b) => (a.publishedAt ?? DateTime(0))
              .compareTo(b.publishedAt ?? DateTime(0)));
        case SermonSort.longest:
          filtered.sort((a, b) =>
              (b.duration ?? Duration.zero).compareTo(a.duration ?? Duration.zero));
        case SermonSort.shortest:
          filtered.sort((a, b) =>
              (a.duration ?? Duration.zero).compareTo(b.duration ?? Duration.zero));
        case SermonSort.az:
          filtered.sort(
              (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
      }
      return filtered;
    },
    loading: () => const [],
    error: (_, _) => const [],
  );
});

// ── Videos (YouTube non-shorts, LIVE from feed) ──────────────────────────────

final videoRepositoryProvider = Provider<VideoRepository>(
  (ref) => VideoRepository(),
);

/// Live YouTube video list. Fetches the Atom feed on every read (proxy on
/// web, direct on mobile). Falls back to the embedded [kharisVideos] dataset.
final videosProvider = FutureProvider<List<Sermon>>((ref) async {
  final repo = ref.watch(videoRepositoryProvider);
  return repo.getVideos();
});

// ── Admin: sermon management (Firestore realtime) ────────────────────────────

/// The Firestore-backed sermon repository used by the admin CMS.
///
/// Deliberately separate from [sermonRepositoryProvider]: the public library
/// reads the external Kharis sermon API, while every admin write/delete must
/// land in the Firestore `sermons` collection. Sharing one provider is what
/// made the admin panel type-guard itself into a no-op.
final adminSermonRepositoryProvider = Provider<FirestoreSermonRepository>(
  (ref) => FirestoreSermonRepository(),
);

/// Admin-only realtime stream of Firestore-managed sermons for the CMS panel.
/// Only works when [kUseFirebase] is true; otherwise emits an empty list.
final adminSermonsProvider = StreamProvider<List<Sermon>>((ref) {
  if (!kUseFirebase) return Stream.value(const []);
  try {
    return ref.watch(adminSermonRepositoryProvider).watchSermons();
  } catch (_) {
    return Stream.value(const []);
  }
});

/// Featured sermons for the Messages page hero.
final featuredSermonsProvider = Provider<List<Sermon>>((ref) {
  final sermons = ref.watch(librarySermonsProvider);
  final firestoreFeatured = ref.watch(adminSermonsProvider).valueOrNull ?? [];
  // Prefer explicitly featured docs from Firestore, fall back to the 3 newest.
  final featured = firestoreFeatured.where((s) => s.isFeatured).toList();
  if (featured.isNotEmpty) return featured.take(5).toList();
  return sermons.take(3).toList();
});

// ── Recently played ───────────────────────────────────────────────────────────

/// Sermons the user has recently played, ordered most-recent first.
/// Driven by the [CacheService] playback history. Re-evaluates whenever
/// playback state changes (so the list updates right after a new play).
final recentlyPlayedProvider = Provider<List<Sermon>>((ref) {
  // Watch player state so the list refreshes after each new play.
  ref.watch(playerStateProvider);
  final cache = ref.read(cacheServiceProvider);
  final ids = cache.getRecentlyPlayed();
  if (ids.isEmpty) return const [];
  final allSermons = ref.watch(sermonsProvider).valueOrNull ?? const [];
  final byId = {for (final s in allSermons) s.id: s};
  return ids
      .map((id) => byId[id])
      .whereType<Sermon>()
      .take(10)
      .toList();
});

// ── Search ────────────────────────────────────────────────────────────────────

/// Active search query for the Messages library. Empty string = no search.
final sermonSearchProvider = StateProvider<String>((ref) => '');

/// Search results: sermons whose title, speaker, or category contains the
/// query (case-insensitive). Empty when no query is active.
final searchResultsProvider = Provider<List<Sermon>>((ref) {
  final query = ref.watch(sermonSearchProvider).trim().toLowerCase();
  if (query.isEmpty) return const [];
  final sermons = ref.watch(sermonsProvider).valueOrNull ?? const [];
  return sermons.where((s) {
    final title = s.title.toLowerCase();
    final speaker = s.speaker.toLowerCase();
    final category = (s.category ?? '').toLowerCase();
    return title.contains(query) ||
        speaker.contains(query) ||
        category.contains(query);
  }).toList()
    ..sort((a, b) => (b.publishedAt ?? DateTime(0))
        .compareTo(a.publishedAt ?? DateTime(0)));
});

// ── Events ────────────────────────────────────────────────────────────────────

final eventRepositoryProvider = Provider<EventRepository>((ref) {
  return EventRepository();
});

/// Upcoming events, optionally filtered by branch. Realtime: re-emits on
/// every Firestore change so admin-panel edits appear without refresh.
final upcomingEventsProvider =
    StreamProvider.family<List<Event>, String?>((ref, branch) {
  final repo = ref.watch(eventRepositoryProvider);
  return repo.watchUpcomingEvents(branch: branch);
});

/// Past events, optionally filtered by branch. Realtime, most recent first.
/// An event only lands here once its end time has passed.
final pastEventsProvider =
    StreamProvider.family<List<Event>, String?>((ref, branch) {
  final repo = ref.watch(eventRepositoryProvider);
  return repo.watchPastEvents(branch: branch);
});

// ── RSVPs ─────────────────────────────────────────────────────────────────────

final rsvpRepositoryProvider = Provider<RsvpRepository>((ref) {
  return RsvpRepository();
});

/// The signed-in member's RSVPs, latest event first. Empty while signed out;
/// re-subscribes on sign-in/sign-out without needing an outer watch.
final myRsvpsProvider = StreamProvider<List<Rsvp>>((ref) {
  return ref.watch(rsvpRepositoryProvider).watchMyRsvps();
});

/// Whether the signed-in member has RSVP'd to a given event id. Derived from
/// [myRsvpsProvider] so the RSVP button reflects persisted state without a
/// listener (or a read) per card. Auto-disposed so scrolling through a long
/// list does not accumulate one family entry per event for the session.
final isEventRsvpedProvider =
    Provider.autoDispose.family<bool, String>((ref, eventId) {
  final rsvps = ref.watch(myRsvpsProvider).valueOrNull ?? const <Rsvp>[];
  return rsvps.any((r) => r.eventId == eventId);
});

/// The events behind [myRsvpsProvider], in RSVP order (latest event first).
/// Resolved in `whereIn` batches, so the cost is O(n / 30) reads.
final myRsvpEventsProvider = FutureProvider<List<Event>>((ref) async {
  final rsvps = await ref.watch(myRsvpsProvider.future);
  if (rsvps.isEmpty) return const [];
  final events = await ref
      .watch(eventRepositoryProvider)
      .getEventsByIds(rsvps.map((r) => r.eventId).toList());
  final byId = {for (final e in events) e.id: e};
  return [
    for (final r in rsvps)
      if (byId[r.eventId] case final Event e) e,
  ];
});

// ── Daily content ─────────────────────────────────────────────────────────────

final dailyContentRepositoryProvider = Provider<DailyContentRepository>((ref) {
  return DailyContentRepository();
});

/// Today's reading + prayer. Realtime snapshot of dailyContent/{today}.
final dailyContentProvider = StreamProvider<DailyContent>((ref) {
  final repo = ref.watch(dailyContentRepositoryProvider);
  return repo.watchTodaysContent();
});

// ── News ──────────────────────────────────────────────────────────────────────

final newsRepositoryProvider = Provider<NewsRepository>((ref) {
  return NewsRepository();
});

/// News & announcements — API-first (getAnnouncements) with Firestore fallback.
final announcementApiRepositoryProvider =
    Provider<KharisApiAnnouncementRepository>((ref) {
  return KharisApiAnnouncementRepository();
});

/// Live announcements, expired items removed. `expiresAt` is set by the web
/// admin portal; anything past it must never reach the UI.
final newsProvider = FutureProvider<List<NewsItem>>((ref) async {
  final items =
      await ref.watch(announcementApiRepositoryProvider).getAnnouncements();
  return items.where((n) => !n.isExpired).toList();
});

/// Admin-only realtime announcement list — Firestore direct, expired items
/// INCLUDED so a lapsed notice stays editable, and live so a CMS write shows
/// up immediately (the member-facing [newsProvider] is a cached API future).
final adminNewsProvider = StreamProvider<List<NewsItem>>((ref) {
  return ref
      .watch(newsRepositoryProvider)
      .watchNews(limit: 100, includeExpired: true);
});

// ── Live status ───────────────────────────────────────────────────────────────

final liveRepositoryProvider = Provider<LiveRepository>((ref) {
  return LiveRepository();
});

/// Realtime stream of whether a service is currently live on YouTube.
final liveStatusProvider = StreamProvider<LiveStatus>((ref) {
  return ref.watch(liveRepositoryProvider).watchLiveStatus();
});

// ── Playlists & series (live collections) ────────────────────────────────────

final sermonCollectionsRepositoryProvider =
    Provider<SermonCollectionsRepository>(
  (ref) => SermonCollectionsRepository(),
);

/// Live playlists + series from the Kharis API (playlists first, then series).
/// Empty on failure so the Playlists screen falls back to its built-in set.
final sermonCollectionsProvider =
    FutureProvider<List<SermonCollection>>((ref) async {
  final repo = ref.watch(sermonCollectionsRepositoryProvider);
  final results = await Future.wait([repo.playlists(), repo.series()]);
  return [...results[0], ...results[1]];
});
