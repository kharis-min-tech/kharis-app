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
import '../../features/messages/data/motd_repository.dart';
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

// ── Sermons (paged live fetch) ────────────────────────────────────────────────

/// Paged view of the public API library.
class SermonLibrary {
  const SermonLibrary({
    this.sermons = const [],
    this.nextUrl,
    this.totalCount = 0,
    this.isLoadingMore = false,
    this.loaded = false,
    this.usedFallback = false,
  });

  /// Every sermon fetched so far, in archive order (newest first).
  final List<Sermon> sermons;

  /// `next` link of the last fetched page; `null` = archive exhausted.
  final String? nextUrl;

  /// Total sermons the server reports across all pages.
  final int totalCount;

  /// A follow-up page is currently in flight.
  final bool isLoadingMore;

  /// First page (or fallback) has landed.
  final bool loaded;

  /// First page failed and the bundled catalogue is being shown instead.
  final bool usedFallback;

  bool get hasMore => nextUrl != null;

  SermonLibrary copyWith({
    List<Sermon>? sermons,
    String? nextUrl,
    bool clearNextUrl = false,
    int? totalCount,
    bool? isLoadingMore,
    bool? loaded,
    bool? usedFallback,
  }) =>
      SermonLibrary(
        sermons: sermons ?? this.sermons,
        nextUrl: clearNextUrl ? null : (nextUrl ?? this.nextUrl),
        totalCount: totalCount ?? this.totalCount,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        loaded: loaded ?? this.loaded,
        usedFallback: usedFallback ?? this.usedFallback,
      );
}

/// Streams the archive in pages, following the server's `next` links until
/// the beginning of time (the earliest sermon), exactly as far as the user
/// scrolls. Page 1 loads eagerly; [loadMore] appends the rest.
class SermonLibraryNotifier extends StateNotifier<SermonLibrary> {
  SermonLibraryNotifier(this._repo) : super(const SermonLibrary()) {
    _firstLoad = _init();
  }

  final AbstractSermonRepository _repo;
  late final Future<void> _firstLoad;

  /// Completes when page 1 (or the offline fallback) has landed.
  Future<void> get firstLoad => _firstLoad;

  Future<void> _init() async {
    try {
      final page = await _repo.fetchPage();
      if (!mounted) return;
      state = SermonLibrary(
        sermons: page.sermons,
        nextUrl: page.nextUrl,
        totalCount: page.totalCount,
        loaded: true,
      );
    } catch (_) {
      // Offline / CI fallback — never leaves the user with an empty screen.
      final catalogue = await _repo.loadCatalogue();
      if (!mounted) return;
      state = SermonLibrary(
        sermons: catalogue,
        totalCount: catalogue.length,
        loaded: true,
        usedFallback: true,
      );
    }
  }

  /// Fetches the next page and appends it. Safe to call repeatedly from
  /// scroll notifications: no-ops while loading or once the archive ends.
  /// A failed page keeps [SermonLibrary.nextUrl] so the next scroll retries.
  Future<void> loadMore() async {
    final next = state.nextUrl;
    if (next == null || state.isLoadingMore || !state.loaded) return;
    state = state.copyWith(isLoadingMore: true);
    try {
      final page = await _repo.fetchPage(url: next);
      if (!mounted) return;
      final seen = {for (final s in state.sermons) s.id};
      state = state.copyWith(
        sermons: [
          ...state.sermons,
          ...page.sermons.where((s) => seen.add(s.id)),
        ],
        nextUrl: page.nextUrl,
        clearNextUrl: page.nextUrl == null,
        totalCount:
            page.totalCount == 0 ? state.totalCount : page.totalCount,
        isLoadingMore: false,
      );
    } catch (_) {
      if (!mounted) return;
      state = state.copyWith(isLoadingMore: false);
    }
  }

  /// Restarts from page 1 (pull-to-refresh / manual refresh).
  Future<void> refresh() async {
    state = const SermonLibrary();
    await _init();
  }
}

/// The paged public-API library. Invalidate this to force a real refresh.
///
/// Deliberately has no CMS dependency: [sermonsProvider] watches a Firestore
/// *stream*, and if the page fetches lived there too, every CMS emission —
/// including the one that lands moments after first build — would re-run the
/// API round-trips behind an already-populated list.
final sermonLibraryProvider =
    StateNotifierProvider<SermonLibraryNotifier, SermonLibrary>(
  (ref) => SermonLibraryNotifier(ref.watch(sermonRepositoryProvider)),
);

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
  // Audio-bearing docs only. A `videoId` does NOT make a sermon a video: most
  // carry both an mp3 and a YouTube link, and excluding those hid them from
  // the library entirely.
  final cmsAudio = cms.where((s) => s.hasAudio).toList();

  // Watching the state (not just the future) re-runs this cheap merge every
  // time a scrolled-in page appends to the library.
  final library = ref.watch(sermonLibraryProvider);
  await ref.watch(sermonLibraryProvider.notifier).firstLoad;
  final api = library.sermons;

  // CMS docs mirror API sermons, so a CMS title hides its API twin. API rows
  // dedupe by id only — a 10-year archive legitimately repeats titles.
  final cmsTitles = <String>{for (final s in cmsAudio) _dedupeTitle(s.title)};
  final seenIds = <String>{};
  return [
    ...cmsAudio,
    ...api.where((s) =>
        !cmsTitles.contains(_dedupeTitle(s.title)) && seenIds.add(s.id)),
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
  // valueOrNull keeps the previous merge while a page-append reload is in
  // flight. The old `when(loading:)` form emptied this on every loadMore,
  // which collapsed the topic rails mid-scroll and shrank the scroll extent.
  final present = (sermonsAsync.valueOrNull ?? const <Sermon>[])
      .map((s) => s.category)
      .whereType<String>()
      .toSet();
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

  // Previous-data-aware: every loadMore append briefly re-runs
  // [sermonsProvider], and the old `when(loading: () => const [])` swapped
  // ~40 rows for a skeleton screen each time — the scroll extent shrank and
  // the member's position clamped back to the top (Android device, 3/3
  // repro). valueOrNull carries the prior list through reload cycles.
  final sermons = sermonsAsync.valueOrNull ?? const <Sermon>[];
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
      filtered.sort((a, b) => (b.duration ?? Duration.zero)
          .compareTo(a.duration ?? Duration.zero));
    case SermonSort.shortest:
      filtered.sort((a, b) => (a.duration ?? Duration.zero)
          .compareTo(b.duration ?? Duration.zero));
    case SermonSort.az:
      filtered.sort(
          (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
  }
  return filtered;
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
///
/// Studio-controlled ONLY: the Content Studio writes `isFeatured` on
/// Firestore `sermons` docs, and this is the sole source. No newest-N
/// heuristic — zero featured docs means the hero carousel is absent.
final featuredSermonsProvider = Provider<List<Sermon>>((ref) {
  final firestoreSermons =
      ref.watch(adminSermonsProvider).valueOrNull ?? const <Sermon>[];
  return firestoreSermons.where((s) => s.isFeatured).take(5).toList();
});

// ── Message of the Day (Studio-controlled) ───────────────────────────────────

final motdRepositoryProvider = Provider<MotdRepository>(
  (ref) => MotdRepository(),
);

/// Realtime `config/messageOfTheDay` sermonId. Null when unset.
final motdSermonIdProvider = StreamProvider<String?>((ref) {
  if (!kUseFirebase) return Stream.value(null);
  try {
    return ref.watch(motdRepositoryProvider).watchSermonId();
  } catch (_) {
    return Stream.value(null);
  }
});

/// The Message of the Day sermon, resolved against loaded sermons.
///
/// The Studio picks a Firestore `sermons` doc, so its id is matched against
/// the live CMS stream first, then the merged library (which carries API
/// ids). Null when no doc is set or the id no longer resolves — the Messages
/// tab shows no MOTD card in that case.
final motdSermonProvider = Provider<Sermon?>((ref) {
  final id = ref.watch(motdSermonIdProvider).valueOrNull;
  if (id == null) return null;
  final cms = ref.watch(adminSermonsProvider).valueOrNull ?? const <Sermon>[];
  final library = ref.watch(sermonsProvider).valueOrNull ?? const <Sermon>[];
  for (final sermon in cms.followedBy(library)) {
    if (sermon.id == id) return sermon;
  }
  return null;
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

/// Server-side hits for the active query (`?search=`), so search covers the
/// whole 1,400+ sermon archive — not just the pages scrolled in so far.
/// Debounced; failures degrade silently to local-only results.
final apiSearchProvider = FutureProvider.autoDispose<List<Sermon>>((ref) async {
  final query = ref.watch(sermonSearchProvider).trim();
  if (query.length < 2) return const [];
  // Debounce: wait out the typing burst; the provider rebuilds per keystroke
  // and only the build matching the settled query proceeds to the network.
  await Future<void>.delayed(const Duration(milliseconds: 350));
  if (query != ref.read(sermonSearchProvider).trim()) return const [];
  try {
    final repo = ref.read(sermonRepositoryProvider);
    return (await repo.fetchPage(search: query)).sermons;
  } catch (_) {
    return const [];
  }
});

/// Search results: local matches (title, speaker, or category contains the
/// query, case-insensitive) merged with server-archive hits, newest first.
/// Empty when no query is active.
final searchResultsProvider = Provider<List<Sermon>>((ref) {
  final query = ref.watch(sermonSearchProvider).trim().toLowerCase();
  if (query.isEmpty) return const [];
  final sermons = ref.watch(sermonsProvider).valueOrNull ?? const [];
  final local = sermons.where((s) {
    final title = s.title.toLowerCase();
    final speaker = s.speaker.toLowerCase();
    final category = (s.category ?? '').toLowerCase();
    return title.contains(query) ||
        speaker.contains(query) ||
        category.contains(query);
  }).toList();

  final remote = ref.watch(apiSearchProvider).valueOrNull ?? const <Sermon>[];
  final seenIds = {for (final s in local) s.id};
  final seenTitles = {for (final s in local) _dedupeTitle(s.title)};
  return [
    ...local,
    ...remote.where(
        (s) => seenIds.add(s.id) && seenTitles.add(_dedupeTitle(s.title))),
  ]..sort((a, b) => (b.publishedAt ?? DateTime(0))
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

/// The [EventRepository.pastEventLimit] most recent past events, optionally
/// filtered by branch. Realtime, most recent first.
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

/// The events behind [myRsvpsProvider], split into upcoming and past on the
/// same cutoff the Events tabs use, so an RSVP'd event whose date has passed
/// is never shown as upcoming. Resolved in `whereIn` batches, so the cost is
/// O(n / 30) reads. RSVPs whose event has since been deleted drop out.
///
/// The past group carries the same [EventRepository.pastEventLimit] cap as
/// the Past tab — a member with years of RSVPs sees the recent ones, not an
/// unbounded archive. Upcoming is never capped.
final myRsvpEventsProvider = FutureProvider<RsvpEvents>((ref) async {
  final rsvps = await ref.watch(myRsvpsProvider.future);
  if (rsvps.isEmpty) return RsvpEvents.empty;
  final events = await ref
      .watch(eventRepositoryProvider)
      .getEventsByIds(rsvps.map((r) => r.eventId).toList());
  final grouped = RsvpEvents.split(events, DateTime.now());
  return RsvpEvents(
    upcoming: grouped.upcoming,
    past: grouped.past.take(EventRepository.pastEventLimit).toList(),
  );
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

/// Live announcements for a campus, expired items removed. Pass the member's
/// active branch (`currentBranchProvider`) and the API returns that branch's
/// announcements plus all-campus ones; pass null for the unscoped feed. The
/// scoping is server-side, so a branch notice is never lost behind a global
/// page limit and callers must not re-filter by branch.
///
/// `expiresAt` is set by the web admin portal; anything past it must never
/// reach the UI.
final newsProvider =
    FutureProvider.family<List<NewsItem>, String?>((ref, branch) async {
  final items = await ref
      .watch(announcementApiRepositoryProvider)
      .getAnnouncements(branch: branch);
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
