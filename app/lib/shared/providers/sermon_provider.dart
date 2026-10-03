import 'dart:async';

import 'package:flutter/widgets.dart'
    show
        AppLifecycleState,
        VoidCallback,
        WidgetsBinding,
        WidgetsBindingObserver;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/services/cache_service.dart';
import '../../core/utils/sermon_categorizer.dart';
import '../../core/services/firebase_service.dart';
import '../../features/calendar/data/event_repository.dart';
import '../../features/calendar/data/rsvp_repository.dart';
import '../../features/home/data/daily_content_repository.dart';
import '../../features/home/data/news_repository.dart';
import '../../features/home/data/kharis_api_announcement_repository.dart';
import '../../features/home/data/live_repository.dart';
import '../../features/messages/data/curation_repository.dart';
import '../../features/messages/data/firestore_sermon_repository.dart';
import '../../features/messages/data/kharis_api_sermon_repository.dart';
import '../../features/messages/data/video_repository.dart';
import '../../features/messages/data/sermon_repository_base.dart';
import '../models/sermon.dart';
import 'audio_provider.dart';
import 'branch_provider.dart';
import 'cache_provider.dart';
import 'onboarding_provider.dart';

// ── Repository ────────────────────────────────────────────────────────────────

final sermonRepositoryProvider = Provider<AbstractSermonRepository>((ref) {
  // Kharis public sermon API (yetanothersermon.host; the sermonApiProxy
  // function on web). The notifier falls back to the bundled catalogue when
  // the first page is unreachable.
  return KharisApiSermonRepository();
});

// ── Sermon library (paged live fetch + disk cache) ───────────────────────────

/// Paged view of the public API library.
class SermonLibrary {
  const SermonLibrary({
    this.sermons = const [],
    this.nextUrl,
    this.totalCount = 0,
    this.isLoadingMore = false,
    this.loaded = false,
    this.usedFallback = false,
    this.offline = false,
    this.hydrating = false,
    this.hydrationFailed = false,
    this.incomplete = false,
    this.fetchedAt,
  });

  /// Every sermon fetched so far, in archive order (newest first).
  final List<Sermon> sermons;

  /// `next` link of the last fetched page; `null` = nothing more to page in.
  final String? nextUrl;

  /// Total sermons the server reports across all pages.
  final int totalCount;

  /// A scroll-triggered page is currently in flight.
  final bool isLoadingMore;

  /// Something (cache, page 1 or the fallback) is on screen.
  final bool loaded;

  /// Page 1 failed with no cached archive, so the bundled offline catalogue
  /// is being shown instead of the live library.
  final bool usedFallback;

  /// The last attempt to reach the API failed; what is shown may be stale.
  final bool offline;

  /// The background walk of the archive is running.
  final bool hydrating;

  /// The background walk gave up after its retries; older pages stay missing
  /// until the member retries.
  final bool hydrationFailed;

  /// Every page was walked, and so were the extra gap-fill walks, yet the
  /// library still does not hold [totalCount] sermons. The UI shows the
  /// honest count with a manual retry instead of an end marker.
  final bool incomplete;

  /// When the whole archive was last walked; null before the first walk.
  final DateTime? fetchedAt;

  bool get hasMore => nextUrl != null;

  /// The library holds a different number of sermons than the server
  /// reports. Dedupe is by id, so this is never inflated by a record seen
  /// twice; it means a walk skipped (or kept) something.
  bool get countMismatch => totalCount > 0 && sermons.length != totalCount;

  /// More sermons are still expected to arrive on their own: the library has
  /// not loaded yet, or older pages are being drained and have not failed.
  bool get isFilling => !loaded || (hasMore && !hydrationFailed);

  SermonLibrary copyWith({
    List<Sermon>? sermons,
    String? nextUrl,
    bool clearNextUrl = false,
    int? totalCount,
    bool? isLoadingMore,
    bool? loaded,
    bool? usedFallback,
    bool? offline,
    bool? hydrating,
    bool? hydrationFailed,
    bool? incomplete,
    DateTime? fetchedAt,
  }) => SermonLibrary(
    sermons: sermons ?? this.sermons,
    nextUrl: clearNextUrl ? null : (nextUrl ?? this.nextUrl),
    totalCount: totalCount ?? this.totalCount,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    loaded: loaded ?? this.loaded,
    usedFallback: usedFallback ?? this.usedFallback,
    offline: offline ?? this.offline,
    hydrating: hydrating ?? this.hydrating,
    hydrationFailed: hydrationFailed ?? this.hydrationFailed,
    incomplete: incomplete ?? this.incomplete,
    fetchedAt: fetchedAt ?? this.fetchedAt,
  );
}

/// Default retry schedule for the archive: 2 s, 4 s, 8 s ... capped at 60 s.
Duration defaultArchiveBackoff(int attempt) {
  final seconds = 2 << (attempt - 1).clamp(0, 5);
  return Duration(seconds: seconds > 60 ? 60 : seconds);
}

/// Loads the whole sermon archive and keeps it fresh.
///
/// 1. Paints last session's archive from disk (decoded off the UI isolate).
/// 2. Fetches page 1 for new arrivals.
/// 3. With no cached archive, drains every `next` page in the background so
///    the whole decade is browsable without scrolling for it. With a cached
///    archive older than [maxAge] (checked at launch) or on pull-to-refresh,
///    re-walks every page and swaps the result in at the end, so edits and
///    removals upstream reach older records too.
///
/// Failures retry with [backoff] (page 1 and the archive walk alike) instead
/// of waiting for the member to scroll; after [maxAttempts] the walk stops
/// and [SermonLibrary.hydrationFailed] lets the UI offer a manual retry.
///
/// The API pages by offset, so a record that moves up a page while a walk is
/// in flight is never served to it. A walk that ends short of the server's
/// count therefore re-walks every page from page 1 and merges by id, at most
/// [maxGapFillWalks] times a session (the second after [backoff]); still
/// short, the library is marked [SermonLibrary.incomplete].
class SermonLibraryNotifier extends StateNotifier<SermonLibrary> {
  SermonLibraryNotifier(
    this._repo, {
    this.cache,
    this.autoHydrate = true,
    Duration Function(int attempt)? backoff,
    this.maxAge = const Duration(hours: 24),
    this.maxAttempts = 5,
    this.maxGapFillWalks = 2,
    DateTime Function()? clock,
  }) : _backoff = backoff ?? defaultArchiveBackoff,
       _clock = clock ?? DateTime.now,
       super(const SermonLibrary()) {
    _firstLoad = _init();
  }

  final AbstractSermonRepository _repo;

  /// Disk store for the drained archive; null in tests/CI.
  final SermonArchiveStore? cache;

  /// Network work in the background: draining, revalidation and retries.
  final bool autoHydrate;

  /// A cached archive older than this is re-walked.
  final Duration maxAge;

  /// Automatic retries before the walk gives up.
  final int maxAttempts;

  /// Extra whole-archive walks a session may spend recovering records a walk
  /// skipped.
  final int maxGapFillWalks;

  final Duration Function(int attempt) _backoff;
  final DateTime Function() _clock;

  bool _hydrating = false;
  int _attempt = 0;
  Timer? _retryTimer;

  /// Gap-fill walks started this session, against [maxGapFillWalks].
  int _gapFillWalks = 0;

  /// Page 1 as last fetched: the head of a revalidating walk.
  SermonPage? _firstPage;

  /// Sermon count of the archive on disk, to skip no-op writes.
  int _persistedCount = -1;

  late final Future<void> _firstLoad;
  final Completer<void> _ready = Completer<void>();

  /// Completes when page 1 (or the offline fallback) has been attempted.
  Future<void> get firstLoad => _firstLoad;

  /// Completes as soon as anything is on screen: the cached archive, page 1
  /// or the fallback. Waiting on [firstLoad] instead would hide a cached
  /// archive behind a network round-trip.
  Future<void> get ready => _ready.future;

  @override
  set state(SermonLibrary value) {
    super.state = value;
    if (value.loaded && !_ready.isCompleted) _ready.complete();
  }

  Future<void> _init() async {
    try {
      final cached = await cache?.readSermonArchive();
      if (mounted && cached != null && cached.sermons.isNotEmpty) {
        _persistedCount = cached.sermons.length;
        state = SermonLibrary(
          sermons: cached.sermons,
          totalCount: cached.sermons.length,
          loaded: true,
          fetchedAt: cached.fetchedAt,
        );
      }
    } catch (_) {
      // An unreadable cache is just a cold start.
    }
    if (!mounted) return;
    if (await _loadFirstPage() && autoHydrate) unawaited(hydrateArchive());
  }

  /// Fetches page 1 and lays it over what is shown. Returns false on failure,
  /// after showing the bundled catalogue if nothing else is on screen.
  Future<bool> _loadFirstPage() async {
    try {
      final page = await _repo.fetchPage();
      if (!mounted) return false;
      _firstPage = page;
      _attempt = 0;
      // Page 1 carries the newest arrivals; a cached tail follows it. The
      // bundled fallback is a different catalogue, so it is replaced.
      final tail = state.usedFallback ? const <Sermon>[] : state.sermons;
      final seen = <String>{};
      final merged = [
        ...page.sermons.where((s) => seen.add(s.id)),
        ...tail.where((s) => seen.add(s.id)),
      ];
      final hasArchive = state.fetchedAt != null && !state.usedFallback;
      // A held count that differs from the server's either way (a skipped
      // record, or one deleted upstream) is walked again, never trusted.
      final complete =
          page.nextUrl == null ||
          (hasArchive && merged.length == page.totalCount);
      // Page 1 only adds new arrivals at the head. A walk already past it
      // (running, or paused between retries) keeps its cursor: pointing it
      // back at page 2 would re-fetch every page the library already holds.
      final resume =
          !state.usedFallback && (_hydrating || state.nextUrl != null);
      state = state.copyWith(
        sermons: merged,
        nextUrl: resume ? null : page.nextUrl,
        clearNextUrl: complete,
        totalCount: page.totalCount,
        loaded: true,
        usedFallback: false,
        offline: false,
      );
      if (page.nextUrl == null) {
        _markWalked();
        unawaited(_afterWalk());
      }
      return true;
    } catch (_) {
      if (!mounted) return false;
      if (!state.loaded) {
        // Offline / CI fallback: never leaves the member on an empty screen.
        try {
          final catalogue = await _repo.loadCatalogue();
          if (!mounted) return false;
          state = SermonLibrary(
            sermons: catalogue,
            totalCount: catalogue.length,
            loaded: true,
            usedFallback: true,
          );
        } catch (_) {
          if (!mounted) return false;
          state = state.copyWith(loaded: true);
        }
      }
      state = state.copyWith(offline: true);
      if (_attempt + 1 >= maxAttempts) {
        // Stop polling; the offline banner's Retry takes over.
        _attempt = 0;
        return false;
      }
      _scheduleRetry(() async {
        if (await _loadFirstPage()) unawaited(hydrateArchive());
      });
      return false;
    }
  }

  /// Brings the rest of the archive in, or re-walks it when the cached copy
  /// is stale (or [revalidate] is set). Safe to call repeatedly.
  Future<void> hydrateArchive({bool revalidate = false}) async {
    if (_hydrating || !mounted || !state.loaded || state.usedFallback) return;
    if (_firstPage == null) return;
    final fetchedAt = state.fetchedAt;
    final stale = fetchedAt == null || _clock().difference(fetchedAt) > maxAge;
    if (fetchedAt != null && !revalidate && !stale && !state.hasMore) {
      _persist();
      return;
    }
    await _walk(
      fetchedAt == null ? _drain : _rewalk,
      retry: () => hydrateArchive(revalidate: revalidate),
    );
  }

  /// Re-walks every page from page 1 and merges by id, to recover records a
  /// walk skipped. Automatic gap fills spend the session's
  /// [maxGapFillWalks]; a [manual] one (the footer's Retry) does not.
  Future<void> _fillGap({bool manual = false}) async {
    if (_hydrating || !mounted || !state.loaded || state.usedFallback) return;
    if (state.hasMore || !state.countMismatch) return;
    if (!manual) {
      if (_gapFillWalks >= maxGapFillWalks) {
        state = state.copyWith(incomplete: true);
        return;
      }
      _gapFillWalks++;
    }
    await _walk(() => _rewalk(gapFill: true), retry: _fillGap);
  }

  /// Runs one walk with the shared hydrating flag, failure retries and the
  /// gap check once it lands.
  Future<void> _walk(
    Future<void> Function() walk, {
    required Future<void> Function() retry,
  }) async {
    _hydrating = true;
    state = state.copyWith(hydrating: true, hydrationFailed: false);
    var walked = false;
    try {
      await walk();
      _attempt = 0;
      walked = true;
    } catch (_) {
      if (!mounted) return;
      if (_attempt + 1 >= maxAttempts) {
        _attempt = 0;
        // Out of automatic retries. A complete cached archive is still
        // good, so only an incomplete library reports the failure.
        state = state.copyWith(
          hydrationFailed: state.hasMore,
          incomplete: !state.hasMore && state.countMismatch,
        );
      } else {
        _scheduleRetry(retry);
      }
    } finally {
      _hydrating = false;
      if (mounted) state = state.copyWith(hydrating: false);
    }
    if (walked) await _afterWalk();
  }

  /// A walk reached the last page. A library that holds what the server
  /// reports is finished; one that does not gets a gap fill (the first at
  /// once, the next after [backoff]) until the session's extra walks run
  /// out, and is then marked [SermonLibrary.incomplete].
  Future<void> _afterWalk() async {
    if (!mounted || _hydrating || state.hasMore) return;
    if (!state.countMismatch) {
      if (state.incomplete) state = state.copyWith(incomplete: false);
      return;
    }
    if (!autoHydrate || _gapFillWalks >= maxGapFillWalks) {
      state = state.copyWith(incomplete: true);
      return;
    }
    if (_gapFillWalks == 0) return _fillGap();
    _scheduleRetry(_fillGap);
  }

  /// Appends pages in place, so the list fills as they land.
  Future<void> _drain() async {
    while (mounted && state.nextUrl != null) {
      final page = await _repo.fetchPage(url: state.nextUrl);
      if (!mounted) return;
      _append(page);
    }
    if (mounted) _markWalked();
  }

  /// Walks every page into a fresh list, then swaps it in whole. The cached
  /// archive stays on screen meanwhile; a failure mid-walk leaves it intact.
  ///
  /// A [gapFill] walk refetches page 1 too (a skipped record may have moved
  /// up onto it) and, when the walk itself comes up short, keeps what the
  /// library already holds, merged by id.
  Future<void> _rewalk({bool gapFill = false}) async {
    final head = gapFill ? await _repo.fetchPage() : _firstPage!;
    if (!mounted) return;
    if (gapFill) _firstPage = head;
    final older = <Sermon>[];
    var url = head.nextUrl;
    var total = head.totalCount;
    while (url != null) {
      final page = await _repo.fetchPage(url: url);
      if (!mounted) return;
      older.addAll(page.sermons);
      if (page.totalCount > 0) total = page.totalCount;
      url = page.nextUrl;
    }
    // Headed by page 1 as it is now: a refresh during the walk may have
    // brought newer arrivals. The walk's own page 1 follows it, since those
    // arrivals pushed its last entries onto a page 2 already walked.
    final seen = <String>{};
    final fresh = [
      ..._firstPage!.sermons.where((s) => seen.add(s.id)),
      ...head.sermons.where((s) => seen.add(s.id)),
      ...older.where((s) => seen.add(s.id)),
    ];
    var sermons = fresh;
    if (gapFill && total > 0 && fresh.length < total) {
      // Each walk can skip a different record; together they cover them.
      // A union past the server's count means something held was deleted
      // upstream, so the walk just made is kept instead: never more than
      // the server lists.
      final union = _mergeById(fresh, state.sermons);
      if (union.length <= total) sermons = union;
    }
    state = state.copyWith(
      sermons: sermons,
      clearNextUrl: true,
      totalCount: total,
    );
    _markWalked();
  }

  void _append(SermonPage page) {
    final seen = {for (final s in state.sermons) s.id};
    state = state.copyWith(
      sermons: [...state.sermons, ...page.sermons.where((s) => seen.add(s.id))],
      nextUrl: page.nextUrl,
      clearNextUrl: page.nextUrl == null,
      totalCount: page.totalCount == 0 ? state.totalCount : page.totalCount,
    );
  }

  /// The archive has been walked end to end: stamp and persist it.
  void _markWalked() {
    state = state.copyWith(fetchedAt: _clock(), hydrationFailed: false);
    _persistedCount = -1;
    _persist();
  }

  void _persist() {
    final cache = this.cache;
    final fetchedAt = state.fetchedAt;
    if (cache == null || fetchedAt == null || state.usedFallback) return;
    if (state.sermons.isEmpty || state.sermons.length == _persistedCount) {
      return;
    }
    _persistedCount = state.sermons.length;
    unawaited(
      cache
          .writeSermonArchive(
            SermonArchiveSnapshot(sermons: state.sermons, fetchedAt: fetchedAt),
          )
          .catchError((Object _) {}),
    );
  }

  void _scheduleRetry(Future<void> Function() action) {
    if (!autoHydrate || !mounted) return;
    _retryTimer?.cancel();
    _attempt++;
    final delay = _backoff(_attempt);
    _retryTimer = Timer(delay, () {
      if (mounted) unawaited(action());
    });
  }

  /// Fetches the next page and appends it. Safe to call repeatedly from
  /// scroll notifications: no-ops while loading, while the background walk
  /// runs, or once the archive ends. A failure keeps
  /// [SermonLibrary.nextUrl] so the next call retries.
  Future<void> loadMore() async {
    final next = state.nextUrl;
    if (next == null || state.isLoadingMore || !state.loaded) return;
    if (_hydrating) return;
    state = state.copyWith(isLoadingMore: true);
    try {
      final page = await _repo.fetchPage(url: next);
      if (!mounted) return;
      _append(page);
      state = state.copyWith(isLoadingMore: false);
    } catch (_) {
      if (mounted) state = state.copyWith(isLoadingMore: false);
      return;
    }
    if (!state.hasMore) {
      _markWalked();
      await _afterWalk();
    }
  }

  /// Retries a walk that gave up ([SermonLibrary.hydrationFailed]), or
  /// re-walks a library that came up short ([SermonLibrary.incomplete]).
  Future<void> retryHydration() {
    _retryTimer?.cancel();
    _attempt = 0;
    if (state.fetchedAt != null && !state.hasMore && state.countMismatch) {
      return _fillGap(manual: true);
    }
    return hydrateArchive();
  }

  /// Pull-to-refresh: refetches page 1 (completing when it lands) and then
  /// revalidates the whole archive in the background. What is on screen
  /// stays there throughout; nothing blanks.
  Future<void> refresh() async {
    _retryTimer?.cancel();
    _attempt = 0;
    state = state.copyWith(hydrationFailed: false);
    if (await _loadFirstPage() && autoHydrate) {
      unawaited(hydrateArchive(revalidate: true));
    }
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    super.dispose();
  }
}

/// [primary] with every sermon of [secondary] it lacks, each slotted in
/// after the sermon that preceded it in [secondary], so archive order holds.
/// One entry per id.
List<Sermon> _mergeById(List<Sermon> primary, List<Sermon> secondary) {
  final ids = {for (final s in primary) s.id};
  final added = <String>{};
  final head = <Sermon>[];
  final after = <String, List<Sermon>>{};
  String? anchor;
  for (final s in secondary) {
    if (ids.contains(s.id)) {
      anchor = s.id;
    } else if (added.add(s.id)) {
      (anchor == null ? head : after.putIfAbsent(anchor, () => [])).add(s);
    }
  }
  if (head.isEmpty && after.isEmpty) return primary;
  return [
    ...head,
    for (final s in primary) ...[s, ...?after[s.id]],
  ];
}

/// Disk cache for the hydrated archive. Overridden in `main.dart`; stays null
/// in tests and CI, where Hive is not initialised.
final sermonArchiveCacheProvider = Provider<SermonArchiveStore?>((ref) => null);

/// Whether the library walks the archive in the background (and retries on
/// its own). Tests override this to `false` to drive [loadMore] by hand.
final sermonArchiveAutoHydrateProvider = Provider<bool>((ref) => true);

/// Retry delay per attempt for the archive walk. Tests shorten it.
final sermonArchiveBackoffProvider = Provider<Duration Function(int attempt)>(
  (ref) => defaultArchiveBackoff,
);

/// The paged public-API library.
///
/// Deliberately has no CMS dependency: [sermonsProvider] watches a Firestore
/// *stream*, and if the page fetches lived there too, every CMS emission
/// would re-run the API round-trips behind an already-populated list.
final sermonLibraryProvider =
    StateNotifierProvider<SermonLibraryNotifier, SermonLibrary>(
      (ref) => SermonLibraryNotifier(
        ref.watch(sermonRepositoryProvider),
        cache: ref.watch(sermonArchiveCacheProvider),
        autoHydrate: ref.watch(sermonArchiveAutoHydrateProvider),
        backoff: ref.watch(sermonArchiveBackoffProvider),
      ),
    );

/// The member library: hand-added CMS sermons layered over the public API
/// archive, newest source first.
///
/// CMS docs mirror API sermons, so a CMS title hides its API twin. API rows
/// dedupe by id only: a 10-year archive legitimately repeats titles. Includes
/// the handful of video-only API records, which play in video mode.
final sermonsProvider = FutureProvider<List<Sermon>>((ref) async {
  // Live stream, so a CMS edit re-emits the library without a manual refresh.
  final cms = ref.watch(cmsSermonsProvider).valueOrNull ?? const <Sermon>[];
  final cmsAudio = cms.where((s) => s.hasAudio).toList();

  // Watching the state (not just the future) re-runs this cheap merge every
  // time a page lands.
  final library = ref.watch(sermonLibraryProvider);
  await ref.watch(sermonLibraryProvider.notifier).ready;
  final api = library.sermons;

  final cmsTitles = <String>{for (final s in cmsAudio) _dedupeTitle(s.title)};
  final seenIds = <String>{};
  return [
    ...cmsAudio,
    ...api.where(
      (s) => !cmsTitles.contains(_dedupeTitle(s.title)) && seenIds.add(s.id),
    ),
  ];
});

/// Title reduced to alphanumerics for cross-source dedupe.
String _dedupeTitle(String title) =>
    title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

/// The topic a library sermon is filed under; see [topicOf].
String sermonTopic(Sermon s) =>
    topicOf(title: s.title, description: s.description, category: s.category);

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

/// Active archive-year filter; `null` = every year.
///
/// Deliberately NOT persisted: waking up next launch still filtered to 2014
/// would look like the archive had shrunk again.
final selectedArchiveYearProvider = StateProvider<int?>((ref) => null);

/// Years present in the catalogue, newest first.
final archiveYearsProvider = Provider<List<int>>((ref) {
  final years = ref.watch(archiveYearCountsProvider).keys.toList()
    ..sort((a, b) => b.compareTo(a));
  return years;
});

/// How many sermons sit in each year, for the year rail's counts.
final archiveYearCountsProvider = Provider<Map<int, int>>((ref) {
  final sermons = ref.watch(sermonsProvider).valueOrNull ?? const <Sermon>[];
  final counts = <int, int>{};
  for (final s in sermons) {
    final y = s.publishedAt?.year;
    if (y != null) counts[y] = (counts[y] ?? 0) + 1;
  }
  return counts;
});

/// Active topic filter: a label from [kSermonCategories]. 'All' = none.
final selectedCategoryProvider = StateProvider<String>((ref) {
  final cache = ref.read(cacheServiceProvider);
  // ignore: deprecated_member_use
  ref.listenSelf((_, next) => cache.cachePreference('last_category', next));
  final saved = cache.getPreference<String>('last_category', 'All');
  // A label retired from the topic list must not filter to nothing.
  return kSermonCategories.contains(saved) ? saved : 'All';
});

/// Sermons per topic across the whole library. Every sermon has exactly one
/// topic, so the counts add up to the library size.
final categoryCountsProvider = Provider<Map<String, int>>((ref) {
  final sermons = ref.watch(sermonsProvider).valueOrNull ?? const <Sermon>[];
  final counts = <String, int>{};
  for (final s in sermons) {
    final topic = sermonTopic(s);
    counts[topic] = (counts[topic] ?? 0) + 1;
  }
  return counts;
});

/// Topics that occur in the library, in display order, 'All' first and
/// [kOtherCategory] last. Empty buckets are hidden.
final categoryLabelsProvider = Provider<List<String>>((ref) {
  // valueOrNull (via the counts) keeps the previous merge while a page
  // append is in flight, so the topic rail never collapses mid-scroll.
  final counts = ref.watch(categoryCountsProvider);
  return [
    'All',
    for (final c in kSermonCategories)
      if (c != 'All' && (counts[c] ?? 0) > 0) c,
  ];
});

/// One API sermon series and how many messages it holds.
typedef SermonSeries = ({String name, int count, DateTime? latest});

/// The API's series (from each sermon's `series`), most recently preached
/// first. Sermons outside any series are not represented.
final seriesListProvider = Provider<List<SermonSeries>>((ref) {
  final sermons = ref.watch(sermonsProvider).valueOrNull ?? const <Sermon>[];
  final counts = <String, int>{};
  final latest = <String, DateTime?>{};
  for (final s in sermons) {
    final name = s.series;
    if (name == null || name.isEmpty) continue;
    counts[name] = (counts[name] ?? 0) + 1;
    final when = s.publishedAt;
    final prev = latest[name];
    if (when != null && (prev == null || when.isAfter(prev))) {
      latest[name] = when;
    }
  }
  final list =
      [
        for (final e in counts.entries)
          (name: e.key, count: e.value, latest: latest[e.key]),
      ]..sort(
        (a, b) => (b.latest ?? DateTime(0)).compareTo(a.latest ?? DateTime(0)),
      );
  return list;
});

/// Active series filter; null = every series.
final selectedSeriesProvider = StateProvider<String?>((ref) => null);

/// The library list: topic, series and year filtered, then sorted.
final librarySermonsProvider = Provider<List<Sermon>>((ref) {
  final sermonsAsync = ref.watch(sermonsProvider);
  final category = ref.watch(selectedCategoryProvider);
  final series = ref.watch(selectedSeriesProvider);
  final year = ref.watch(selectedArchiveYearProvider);
  final sort = ref.watch(sermonSortProvider);

  // Previous-data-aware: every page append briefly re-runs [sermonsProvider];
  // an empty list during that reload shrank the scroll extent and threw the
  // member back to the top. valueOrNull carries the prior list through.
  final sermons = sermonsAsync.valueOrNull ?? const <Sermon>[];
  final filtered = [
    for (final s in sermons)
      if ((category == 'All' || sermonTopic(s) == category) &&
          (series == null || s.series == series) &&
          (year == null || s.publishedAt?.year == year))
        s,
  ];
  switch (sort) {
    case SermonSort.newest:
      filtered.sort(
        (a, b) => (b.publishedAt ?? DateTime(0)).compareTo(
          a.publishedAt ?? DateTime(0),
        ),
      );
    case SermonSort.oldest:
      filtered.sort(
        (a, b) => (a.publishedAt ?? DateTime(0)).compareTo(
          b.publishedAt ?? DateTime(0),
        ),
      );
    case SermonSort.longest:
      filtered.sort(
        (a, b) => (b.duration ?? Duration.zero).compareTo(
          a.duration ?? Duration.zero,
        ),
      );
    case SermonSort.shortest:
      filtered.sort(
        (a, b) => (a.duration ?? Duration.zero).compareTo(
          b.duration ?? Duration.zero,
        ),
      );
    case SermonSort.az:
      filtered.sort(
        (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
      );
  }
  return filtered;
});

// ── Videos (YouTube non-shorts, LIVE from feed) ──────────────────────────────

final videoRepositoryProvider = Provider<VideoRepository>(
  (ref) => VideoRepository(),
);

/// Live YouTube uploads, newest first (Shorts excluded). Falls back to the
/// embedded dataset when the API and feed are unreachable.
final videosProvider = FutureProvider<List<Sermon>>((ref) async {
  final repo = ref.watch(videoRepositoryProvider);
  return repo.getVideos();
});

// ── Video/audio twins ─────────────────────────────────────────────────────────

/// Library sermons that carry both an mp3 and a YouTube link, keyed by the
/// YouTube id. A YouTube upload maps to its "audio twin" here, so a video
/// entry point (Home hero, featured, Message of the Day) can offer Audio.
/// Newest wins when the API links one video from two records.
final audioTwinByVideoIdProvider = Provider<Map<String, Sermon>>((ref) {
  final cms = ref.watch(cmsSermonsProvider).valueOrNull ?? const <Sermon>[];
  final api = ref.watch(sermonLibraryProvider).sermons;
  final twins = <String, Sermon>{};
  for (final s in [...api, ...cms]) {
    final vid = s.videoId;
    if (vid == null || vid.isEmpty || !s.hasAudio) continue;
    twins.putIfAbsent(vid, () => s);
  }
  return twins;
});

/// [sermon] as its audio twin when it is a video-only entry with one: the
/// twin's id, audio, speaker and description, keeping the video's (sharper)
/// thumbnail. Anything else comes back unchanged.
Sermon withAudioTwin(Sermon sermon, Map<String, Sermon> twins) {
  if (sermon.hasAudio) return sermon;
  final twin = twins[sermon.videoId];
  if (twin == null) return sermon;
  return twin.copyWith(artworkUrl: sermon.artworkUrl ?? twin.artworkUrl);
}

// ── CMS (Firestore realtime) ──────────────────────────────────────────────────

/// The Firestore-backed sermon repository used by the CMS.
///
/// Deliberately separate from [sermonRepositoryProvider]: the public library
/// reads the external Kharis sermon API, while every admin write/delete must
/// land in the Firestore `sermons` collection.
final adminSermonRepositoryProvider = Provider<FirestoreSermonRepository>(
  (ref) => FirestoreSermonRepository(firestore: ref.watch(firestoreProvider)),
);

/// Admin-only realtime stream of every `sermons` doc for the Studio.
final adminSermonsProvider = StreamProvider<List<Sermon>>((ref) {
  if (!kUseFirebase) return Stream.value(const []);
  try {
    return ref.watch(adminSermonRepositoryProvider).watchSermons();
  } catch (_) {
    return Stream.value(const []);
  }
});

/// Hand-added CMS sermons for the member library. Filtered by source, so the
/// YouTube mirrors in the same collection cannot fill the window.
final cmsSermonsProvider = StreamProvider<List<Sermon>>((ref) {
  if (!kUseFirebase) return Stream.value(const []);
  try {
    return ref.watch(adminSermonRepositoryProvider).watchCmsSermons();
  } catch (_) {
    return Stream.value(const []);
  }
});

// ── Featured + Message of the Day (Studio-controlled) ────────────────────────

final curationRepositoryProvider = Provider<CurationRepository>(
  (ref) => CurationRepository(firestore: ref.watch(firestoreProvider)),
);

/// Studio `config/featured` mode. Missing doc or field means auto.
final featuredModeProvider = StreamProvider<FeaturedMode>((ref) {
  if (!kUseFirebase) return Stream.value(FeaturedMode.auto);
  try {
    return ref.watch(curationRepositoryProvider).watchFeaturedMode();
  } catch (_) {
    return Stream.value(FeaturedMode.auto);
  }
});

/// Studio-starred `sermons` docs, newest first, at most 5.
final pinnedFeaturedProvider = StreamProvider<List<Sermon>>((ref) {
  if (!kUseFirebase) return Stream.value(const []);
  try {
    return ref.watch(adminSermonRepositoryProvider).watchPinnedFeatured();
  } catch (_) {
    return Stream.value(const []);
  }
});

/// Maximum cards in the featured carousel.
const int kFeaturedLimit = 5;

/// The Messages featured carousel.
///
/// - auto (default): the newest YouTube uploads, each as its audio twin when
///   the archive has one;
/// - pinned: the Studio-starred docs, newest first, as audio twins where
///   possible; falls back to auto when nothing is starred.
///
/// Empty while the mode (or, in pinned mode, the starred docs) is still
/// loading, so pinned picks never flash auto content first.
final featuredSermonsProvider = Provider<List<Sermon>>((ref) {
  final mode = ref.watch(featuredModeProvider);
  if (mode.isLoading && !mode.hasValue) return const [];
  final twins = ref.watch(audioTwinByVideoIdProvider);

  if (mode.valueOrNull == FeaturedMode.pinned) {
    final pinnedAsync = ref.watch(pinnedFeaturedProvider);
    if (pinnedAsync.isLoading && !pinnedAsync.hasValue) return const [];
    final pinned = pinnedAsync.valueOrNull ?? const [];
    if (pinned.isNotEmpty) {
      return _distinct([
        for (final s in pinned.take(kFeaturedLimit)) withAudioTwin(s, twins),
      ]);
    }
  }

  final videos = [...ref.watch(videosProvider).valueOrNull ?? const <Sermon>[]]
    ..sort(
      (a, b) => (b.publishedAt ?? DateTime(0)).compareTo(
        a.publishedAt ?? DateTime(0),
      ),
    );
  return _distinct([
    for (final v in videos.take(kFeaturedLimit)) withAudioTwin(v, twins),
  ]);
});

List<Sermon> _distinct(List<Sermon> sermons) {
  final seen = <String>{};
  return [
    for (final s in sermons)
      if (seen.add(s.id)) s,
  ];
}

/// Wall clock behind [todayProvider]; tests override it.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// The member's local calendar date, at midnight.
///
/// Rolls over at local midnight while the app is alive, and is re-evaluated
/// whenever the app returns to the foreground: a suspended app's timers do
/// not fire on time. Dependents only rebuild when the date actually changes.
final todayProvider = Provider<DateTime>((ref) {
  final now = ref.watch(clockProvider)();
  final midnight = Timer(
    DateTime(now.year, now.month, now.day + 1).difference(now),
    ref.invalidateSelf,
  );
  final resume = _OnResume(ref.invalidateSelf);
  WidgetsBinding.instance.addObserver(resume);
  ref.onDispose(() {
    midnight.cancel();
    WidgetsBinding.instance.removeObserver(resume);
  });
  return DateTime(now.year, now.month, now.day);
});

class _OnResume with WidgetsBindingObserver {
  _OnResume(this.onResume);

  final VoidCallback onResume;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) onResume();
  }
}

/// `YYYY-MM-DD` key of a local calendar date (the `motdSchedule` doc id).
String motdDateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

/// The sermon id the Studio scheduled for today, or null. Read errors count
/// as "nothing scheduled".
final motdScheduledIdProvider = StreamProvider<String?>((ref) {
  if (!kUseFirebase) return Stream.value(null);
  final key = motdDateKey(ref.watch(todayProvider));
  try {
    return ref.watch(curationRepositoryProvider).watchScheduledMotd(key);
  } catch (_) {
    return Stream.value(null);
  }
});

/// How far back the automatic Message of the Day looks.
const Duration kMotdWindow = Duration(days: 90);

/// Message of the Day.
///
/// Today's `motdSchedule` doc when it resolves to a sermon (as its audio twin
/// where possible). Otherwise [dailyMotdPick]. Null while today's schedule
/// or a scheduled sermon is still loading, so the card never swaps.
final motdSermonProvider = Provider<Sermon?>((ref) {
  final schedule = ref.watch(motdScheduledIdProvider);
  if (schedule.isLoading && !schedule.hasValue) return null;
  final scheduledId = schedule.hasError ? null : schedule.valueOrNull;
  if (scheduledId != null) {
    final hit = ref.watch(sermonByIdProvider(scheduledId));
    if (hit.isLoading) return null;
    final sermon = hit.valueOrNull;
    if (sermon != null) {
      return withAudioTwin(sermon, ref.watch(audioTwinByVideoIdProvider));
    }
  }
  final library = ref.watch(sermonsProvider).valueOrNull ?? const <Sermon>[];
  return dailyMotdPick(library, ref.watch(todayProvider));
});

/// The automatic Message of the Day for [today] from [library].
///
/// A deterministic pick among audio sermons published in the [kMotdWindow]
/// before [today], excluding [today] itself, so a same-day upload cannot
/// reshuffle the pick mid-day. The pool is ordered by id before hashing the
/// date, so the pick does not depend on load order and is the same on every
/// device that holds the same messages. With nothing that recent, the newest
/// audio sermon from before [today] (or, failing that, from [today]).
Sermon? dailyMotdPick(List<Sermon> library, DateTime today) {
  final day = DateTime(today.year, today.month, today.day);
  final start = DateTime(day.year, day.month, day.day - kMotdWindow.inDays);
  final end = DateTime(day.year, day.month, day.day + 1);
  final audio = [
    for (final s in library)
      if (s.hasAudio && s.publishedAt != null && s.publishedAt!.isBefore(end))
        s,
  ];
  final pool = [
    for (final s in audio)
      if (!s.publishedAt!.isBefore(start) && s.publishedAt!.isBefore(day)) s,
  ]..sort((a, b) => a.id.compareTo(b.id));
  if (pool.isNotEmpty) return pool[_fnv1a(motdDateKey(day)) % pool.length];
  if (audio.isEmpty) return null;
  audio.sort((a, b) {
    final byDate = b.publishedAt!.compareTo(a.publishedAt!);
    return byDate != 0 ? byDate : a.id.compareTo(b.id);
  });
  return audio.firstWhere(
    (s) => s.publishedAt!.isBefore(day),
    orElse: () => audio.first,
  );
}

/// 32-bit FNV-1a. Unlike [String.hashCode] it is identical on every platform,
/// which the "same pick for everyone" rule depends on.
int _fnv1a(String input) {
  var hash = 0x811c9dc5;
  for (final unit in input.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return hash;
}

// ── Lookup by id ──────────────────────────────────────────────────────────────

/// Sermon snapshots the player recorded for recent plays, newest first.
/// Empty when the cache is unavailable (tests).
final recentSermonSnapshotsProvider = Provider<List<Sermon>>((ref) {
  try {
    // A new play rewrites the snapshots; re-read on track changes.
    ref.watch(currentSermonProvider);
    return ref.watch(playbackHistoryProvider).snapshots();
  } catch (_) {
    return const [];
  }
});

/// One CMS doc by id, for ids no loaded list carries.
final _cmsSermonDocProvider = FutureProvider.autoDispose
    .family<Sermon?, String>((ref, id) async {
      if (!kUseFirebase) return null;
      try {
        return await ref.watch(adminSermonRepositoryProvider).getSermonById(id);
      } catch (_) {
        return null;
      }
    });

/// Resolves a sermon id from anywhere it can come from: the library (CMS and
/// API archive), the YouTube feed, a `yt_<videoId>` mirror id (as the audio
/// twin when there is one), the player's recent snapshots and finally the
/// CMS doc itself.
///
/// `AsyncLoading` while the id is not found yet but could still arrive (the
/// archive is still filling, or the feed or doc is loading); `AsyncData(null)`
/// once it is definitively missing. Callers can therefore tell "still
/// loading" from "no longer in the library".
final sermonByIdProvider = Provider.autoDispose
    .family<AsyncValue<Sermon?>, String>((ref, id) {
      final library = ref.watch(sermonLibraryProvider);
      final merged = ref.watch(sermonsProvider);
      final videos = ref.watch(videosProvider);
      final twins = ref.watch(audioTwinByVideoIdProvider);

      for (final s in merged.valueOrNull ?? const <Sermon>[]) {
        if (s.id == id) return AsyncData(s);
      }
      final videoId = id.startsWith('yt_') ? id.substring(3) : id;
      final twin = twins[videoId];
      if (twin != null) return AsyncData(twin);
      for (final v in videos.valueOrNull ?? const <Sermon>[]) {
        if (v.id == id || v.videoId == videoId) return AsyncData(v);
      }
      for (final s in ref.watch(recentSermonSnapshotsProvider)) {
        if (s.id == id) return AsyncData(s);
      }

      var pending = library.isFilling || !merged.hasValue || videos.isLoading;
      // Archive and feed ids never live in Firestore; anything else may be a
      // CMS doc outside the loaded windows.
      final apiShaped =
          RegExp(r'^\d+$').hasMatch(id) || id.startsWith('archive_');
      if (!apiShaped) {
        final doc = ref.watch(_cmsSermonDocProvider(id));
        final found = doc.valueOrNull;
        if (found != null) return AsyncData(withAudioTwin(found, twins));
        pending = pending || doc.isLoading;
      }
      return pending ? const AsyncLoading() : const AsyncData(null);
    });

// ── Recently played ───────────────────────────────────────────────────────────

/// Sermons the member has recently played, most recent first (at most 10).
/// Entries still loading or gone are skipped; snapshots make most of them
/// resolve immediately.
final recentlyPlayedProvider = Provider<List<Sermon>>((ref) {
  final List<String> ids;
  try {
    // Re-evaluate after each new play.
    ref.watch(currentSermonProvider);
    ids = ref.read(cacheServiceProvider).getRecentlyPlayed();
  } catch (_) {
    return const [];
  }
  final out = <Sermon>[];
  for (final id in ids) {
    final sermon = ref.watch(sermonByIdProvider(id)).valueOrNull;
    if (sermon != null) out.add(sermon);
    if (out.length == 10) break;
  }
  return out;
});

// ── Search ────────────────────────────────────────────────────────────────────

/// Active search query for the Messages library. Empty string = no search.
final sermonSearchProvider = StateProvider<String>((ref) => '');

/// Lower-cased, quote-normalised, whitespace-collapsed form for matching.
String _normaliseForSearch(String s) => s
    .toLowerCase()
    .replaceAll(RegExp('[\u2018\u2019]'), "'")
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

/// The one search predicate: every word of [query] must appear in the
/// sermon's title, speaker, series or description.
bool sermonMatchesQuery(Sermon s, String query) {
  final words = _normaliseForSearch(
    query,
  ).split(' ').where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) return false;
  final haystack = _normaliseForSearch(
    [s.title, s.speaker, s.series ?? '', s.description ?? ''].join(' \u0000 '),
  );
  return words.every(haystack.contains);
}

/// Server-side search state for one query.
class RemoteSearch {
  const RemoteSearch({
    required this.query,
    this.results = const [],
    this.nextUrl,
    this.isLoading = false,
    this.isLoadingMore = false,
  });

  final String query;
  final List<Sermon> results;
  final String? nextUrl;

  /// Waiting out the debounce or the first page.
  final bool isLoading;
  final bool isLoadingMore;

  bool get hasMore => nextUrl != null;

  RemoteSearch copyWith({
    List<Sermon>? results,
    String? nextUrl,
    bool clearNextUrl = false,
    bool? isLoading,
    bool? isLoadingMore,
  }) => RemoteSearch(
    query: query,
    results: results ?? this.results,
    nextUrl: clearNextUrl ? null : (nextUrl ?? this.nextUrl),
    isLoading: isLoading ?? this.isLoading,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
  );
}

/// Debounced `?search=` against the whole archive, following `next` on
/// demand. A new query builds a new notifier, which cancels the old timer,
/// so only the settled query reaches the network. Failures end loading with
/// whatever local results exist.
class RemoteSearchNotifier extends StateNotifier<RemoteSearch> {
  RemoteSearchNotifier(this._repo, String query, {required Duration debounce})
    : super(RemoteSearch(query: query, isLoading: query.length >= 2)) {
    if (state.isLoading) _timer = Timer(debounce, _fetchFirst);
  }

  final AbstractSermonRepository _repo;
  Timer? _timer;

  Future<void> _fetchFirst() async {
    try {
      final page = await _repo.fetchPage(search: state.query);
      if (!mounted) return;
      state = state.copyWith(
        results: page.sermons,
        nextUrl: page.nextUrl,
        clearNextUrl: page.nextUrl == null,
        isLoading: false,
      );
    } catch (_) {
      if (mounted) state = state.copyWith(isLoading: false);
    }
  }

  /// Fetches the next page of server hits, if any.
  Future<void> loadMore() async {
    final next = state.nextUrl;
    if (next == null || state.isLoading || state.isLoadingMore) return;
    state = state.copyWith(isLoadingMore: true);
    try {
      final page = await _repo.fetchPage(url: next);
      if (!mounted) return;
      final seen = {for (final s in state.results) s.id};
      state = state.copyWith(
        results: [
          ...state.results,
          ...page.sermons.where((s) => seen.add(s.id)),
        ],
        nextUrl: page.nextUrl,
        clearNextUrl: page.nextUrl == null,
        isLoadingMore: false,
      );
    } catch (_) {
      if (mounted) state = state.copyWith(isLoadingMore: false);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

/// Typing pause before a server search; tests shorten it.
final searchDebounceProvider = Provider<Duration>(
  (ref) => const Duration(milliseconds: 350),
);

final remoteSearchProvider =
    StateNotifierProvider.autoDispose<RemoteSearchNotifier, RemoteSearch>(
      (ref) => RemoteSearchNotifier(
        ref.watch(sermonRepositoryProvider),
        ref.watch(sermonSearchProvider).trim(),
        debounce: ref.watch(searchDebounceProvider),
      ),
    );

/// Search results: library matches for [sermonMatchesQuery] merged with the
/// server's hits, newest first. Empty when no query is active.
final searchResultsProvider = Provider<List<Sermon>>((ref) {
  final query = ref.watch(sermonSearchProvider).trim();
  if (query.isEmpty) return const [];
  final sermons = ref.watch(sermonsProvider).valueOrNull ?? const <Sermon>[];
  final local = [
    for (final s in sermons)
      if (sermonMatchesQuery(s, query)) s,
  ];
  final remote = ref.watch(remoteSearchProvider).results;
  final seenIds = {for (final s in local) s.id};
  return [...local, ...remote.where((s) => seenIds.add(s.id))]..sort(
    (a, b) =>
        (b.publishedAt ?? DateTime(0)).compareTo(a.publishedAt ?? DateTime(0)),
  );
});

/// Search is still producing results: the debounce or the server's first
/// page is pending. The UI shows a spinner, never "no results", meanwhile.
final searchLoadingProvider = Provider<bool>((ref) {
  if (ref.watch(sermonSearchProvider).trim().isEmpty) return false;
  final library = ref.watch(sermonsProvider);
  return ref.watch(remoteSearchProvider).isLoading ||
      (library.isLoading && !library.hasValue);
});

/// The member's last searches, newest first, persisted in SharedPreferences.
class RecentSearchesNotifier extends StateNotifier<List<String>> {
  RecentSearchesNotifier(this._prefs)
    : super(_prefs?.getStringList(_key) ?? const []);

  final SharedPreferences? _prefs;
  static const _key = 'recent_sermon_searches';

  /// Searches kept.
  static const int limit = 8;

  /// Records [query] at the front (case-insensitively deduped).
  void add(String query) {
    final q = query.trim();
    if (q.length < 2) return;
    final next = [
      q,
      ...state.where((s) => s.toLowerCase() != q.toLowerCase()),
    ].take(limit).toList();
    state = next;
    _prefs?.setStringList(_key, next);
  }

  void remove(String query) {
    state = [...state.where((s) => s != query)];
    _prefs?.setStringList(_key, state);
  }

  void clear() {
    state = const [];
    _prefs?.remove(_key);
  }
}

final recentSearchesProvider =
    StateNotifierProvider<RecentSearchesNotifier, List<String>>((ref) {
      try {
        return RecentSearchesNotifier(ref.watch(sharedPreferencesProvider));
      } catch (_) {
        // No SharedPreferences (tests without the override): session-only.
        return RecentSearchesNotifier(null);
      }
    });

// ── Events ────────────────────────────────────────────────────────────────────

final eventRepositoryProvider = Provider<EventRepository>((ref) {
  return EventRepository();
});

/// Upcoming events, optionally filtered by branch. Realtime: re-emits on
/// every Firestore change so admin-panel edits appear without refresh.
final upcomingEventsProvider = StreamProvider.family<List<Event>, String?>((
  ref,
  branch,
) {
  final repo = ref.watch(eventRepositoryProvider);
  return repo.watchUpcomingEvents(branch: branch);
});

/// The [EventRepository.pastEventLimit] most recent past events, optionally
/// filtered by branch. Realtime, most recent first.
/// An event only lands here once its end time has passed.
final pastEventsProvider = StreamProvider.family<List<Event>, String?>((
  ref,
  branch,
) {
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
final isEventRsvpedProvider = Provider.autoDispose.family<bool, String>((
  ref,
  eventId,
) {
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
final newsProvider = FutureProvider.family<List<NewsItem>, String?>((
  ref,
  branch,
) async {
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
