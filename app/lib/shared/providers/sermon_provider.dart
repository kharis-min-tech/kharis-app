import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/sermon_categorizer.dart';
import '../../core/services/firebase_service.dart';
import '../../features/calendar/data/event_repository.dart';
import '../../features/home/data/daily_content_repository.dart';
import '../../features/home/data/news_repository.dart';
import '../../features/home/data/live_repository.dart';
import '../../features/messages/data/firestore_sermon_repository.dart';
import '../../features/messages/data/video_repository.dart';
import '../../features/messages/data/kharis_content.dart';
import '../../features/messages/data/sermon_repository.dart';
import '../../features/messages/data/sermon_repository_base.dart';
import '../models/sermon.dart';
import 'cache_provider.dart';

// ── Repository ────────────────────────────────────────────────────────────────

final sermonRepositoryProvider = Provider<AbstractSermonRepository>((ref) {
  if (kUseFirebase) return FirestoreSermonRepository();
  return SermonRepository();
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

// ── Currently playing sermon ──────────────────────────────────────────────────

final currentSermonProvider = StateProvider<Sermon?>((ref) => null);

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

/// News & announcements, realtime.
final newsProvider = StreamProvider<List<NewsItem>>((ref) {
  final repo = ref.watch(newsRepositoryProvider);
  return repo.watchNews();
});

// ── Live status ───────────────────────────────────────────────────────────────

final liveRepositoryProvider = Provider<LiveRepository>((ref) {
  return LiveRepository();
});

/// Realtime stream of whether a service is currently live on YouTube.
final liveStatusProvider = StreamProvider<LiveStatus>((ref) {
  return ref.watch(liveRepositoryProvider).watchLiveStatus();
});
