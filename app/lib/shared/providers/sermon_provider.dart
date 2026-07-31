import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/sermon_categorizer.dart';
import '../../core/services/firebase_service.dart';
import '../../features/calendar/data/event_repository.dart';
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
/// All audio sermons, freshest source first.
///
/// Firestore/RSS when reachable; otherwise the bundled 500-episode catalogue.
final sermonsProvider = FutureProvider<List<Sermon>>((ref) async {
  final repo = ref.watch(sermonRepositoryProvider);
  try {
    return await repo.getSermons();
  } catch (_) {
    // Offline / CI fallback - never leaves the user with an empty screen.
    return repo.loadCatalogue();
  }
});

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

/// Admin-only realtime stream of Firestore-managed sermons for the CMS panel.
/// Only works when [kUseFirebase] is true; otherwise emits an empty list.
final adminSermonsProvider = StreamProvider<List<Sermon>>((ref) {
  if (!kUseFirebase) return Stream.value(const []);
  try {
    return FirestoreSermonRepository().watchSermons();
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

final newsProvider = FutureProvider<List<NewsItem>>((ref) {
  return ref.watch(announcementApiRepositoryProvider).getAnnouncements();
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
