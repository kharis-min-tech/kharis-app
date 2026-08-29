import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kharis_app/features/messages/data/sermon_repository_base.dart';
import 'package:kharis_app/shared/models/sermon.dart';
import 'package:kharis_app/shared/providers/sermon_provider.dart';

Sermon _sermon(String id, String title) => Sermon(
      id: id,
      title: title,
      speaker: 'David Antwi',
      audioUrl: 'https://x.test/$id.mp3',
      publishedAt: DateTime(2026, 1, int.parse(id)),
    );

/// Serves a scripted archive: page N links to page N+1 until [pages] runs out.
class _FakePagedRepo extends AbstractSermonRepository {
  _FakePagedRepo(this.pages, {this.failFirstLoad = false});

  final List<List<Sermon>> pages;
  final bool failFirstLoad;

  /// URLs requested through [fetchPage], for asserting call behaviour.
  final requested = <String?>[];

  /// When set, the next [fetchPage] call throws once.
  bool failNext = false;

  @override
  Future<List<Sermon>> getSermons() async => [for (final p in pages) ...p];

  @override
  Future<List<Sermon>> loadCatalogue() async =>
      [_sermon('99', 'Bundled Fallback')];

  @override
  Future<SermonPage> fetchPage({String? url, String? search}) async {
    requested.add(url);
    if (failFirstLoad && url == null) throw StateError('offline');
    if (failNext) {
      failNext = false;
      throw StateError('flaky page');
    }
    final index = url == null ? 0 : int.parse(url.split('page=').last) - 1;
    final isLast = index >= pages.length - 1;
    return SermonPage(
      sermons: pages[index],
      nextUrl: isLast ? null : 'https://x.test/sermons/?page=${index + 2}',
      totalCount: pages.fold(0, (n, p) => n + p.length),
    );
  }
}

void main() {
  (ProviderContainer, _FakePagedRepo) harness({
    List<List<Sermon>>? pages,
    bool failFirstLoad = false,
    bool autoHydrate = false,
  }) {
    final repo = _FakePagedRepo(
      pages ??
          [
            [_sermon('1', 'Newest'), _sermon('2', 'Second')],
            [_sermon('3', 'Third')],
            [_sermon('4', 'Oldest')],
          ],
      failFirstLoad: failFirstLoad,
    );
    final container = ProviderContainer(overrides: [
      sermonRepositoryProvider.overrideWithValue(repo),
      // Manual-paging tests drive loadMore() themselves.
      sermonArchiveAutoHydrateProvider.overrideWithValue(autoHydrate),
      // No Firebase in tests: emit an empty CMS layer immediately so the
      // merged catalogue can settle.
      adminSermonsProvider.overrideWith((ref) => Stream.value(const <Sermon>[])),
      // Both read CacheService for their persisted value, which intentionally
      // throws unless overridden; tests only need plain defaults.
      selectedCategoryProvider.overrideWith((ref) => 'All'),
      sermonSortProvider.overrideWith((ref) => SermonSort.newest),
    ]);
    addTearDown(container.dispose);
    return (container, repo);
  }

  test('loads page 1 eagerly and reports more pages available', () async {
    final (container, _) = harness();
    final notifier = container.read(sermonLibraryProvider.notifier);
    await notifier.firstLoad;

    final lib = container.read(sermonLibraryProvider);
    expect(lib.loaded, isTrue);
    expect(lib.sermons.map((s) => s.id), ['1', '2']);
    expect(lib.hasMore, isTrue);
    expect(lib.totalCount, 4);
  });

  test('loadMore appends pages in order until the archive ends', () async {
    final (container, _) = harness();
    final notifier = container.read(sermonLibraryProvider.notifier);
    await notifier.firstLoad;

    await notifier.loadMore();
    expect(container.read(sermonLibraryProvider).sermons.length, 3);

    await notifier.loadMore();
    final lib = container.read(sermonLibraryProvider);
    expect(lib.sermons.map((s) => s.id), ['1', '2', '3', '4']);
    expect(lib.hasMore, isFalse);

    // Archive exhausted: further calls are no-ops, not requests.
    await notifier.loadMore();
    expect(container.read(sermonLibraryProvider).sermons.length, 4);
  });

  test('loadMore is single-flight under scroll-notification spam', () async {
    final (container, repo) = harness();
    final notifier = container.read(sermonLibraryProvider.notifier);
    await notifier.firstLoad;

    // A fast scroll fires the trigger many times before the page lands.
    await Future.wait([for (var i = 0; i < 8; i++) notifier.loadMore()]);
    expect(container.read(sermonLibraryProvider).sermons.length, 3,
        reason: 'only one page-2 request may be in flight');
    expect(repo.requested.where((u) => u?.contains('page=2') ?? false).length,
        1);
  });

  test('a failed page keeps nextUrl so the next scroll retries', () async {
    final (container, repo) = harness();
    final notifier = container.read(sermonLibraryProvider.notifier);
    await notifier.firstLoad;

    repo.failNext = true;
    await notifier.loadMore();
    var lib = container.read(sermonLibraryProvider);
    expect(lib.sermons.length, 2, reason: 'failure must not wipe the list');
    expect(lib.hasMore, isTrue, reason: 'retry stays possible');
    expect(lib.isLoadingMore, isFalse);

    await notifier.loadMore();
    lib = container.read(sermonLibraryProvider);
    expect(lib.sermons.length, 3);
  });

  test('falls back to the bundled catalogue when page 1 fails', () async {
    final (container, _) = harness(failFirstLoad: true);
    final notifier = container.read(sermonLibraryProvider.notifier);
    await notifier.firstLoad;

    final lib = container.read(sermonLibraryProvider);
    expect(lib.loaded, isTrue);
    expect(lib.usedFallback, isTrue);
    expect(lib.sermons.single.title, 'Bundled Fallback');
    expect(lib.hasMore, isFalse, reason: 'no paging over the bundled asset');
  });

  test('refresh restarts from page 1', () async {
    final (container, repo) = harness();
    final notifier = container.read(sermonLibraryProvider.notifier);
    await notifier.firstLoad;
    await notifier.loadMore();
    expect(container.read(sermonLibraryProvider).sermons.length, 3);

    await notifier.refresh();
    final lib = container.read(sermonLibraryProvider);
    expect(lib.sermons.length, 2);
    expect(lib.hasMore, isTrue);
    expect(repo.requested.where((u) => u == null).length, 2,
        reason: 'refresh refetches page 1');
  });

  // ── Full-archive hydration ─────────────────────────────────────────────────
  //
  // Regression guard for "I can only see as far as 2025": paging on scroll
  // alone left 1,435 of 1,485 sermons unreachable, so "Oldest" sorted only the
  // newest page. The library must reach the end of the archive on its own.

  /// Pumps until the merged catalogue has a value. [sermonsProvider] re-runs on
  /// every appended page, so awaiting `.future` races the hydration loop.
  Future<void> settleCatalogue(ProviderContainer c) async {
    c.listen(sermonsProvider, (_, _) {}, fireImmediately: true);
    for (var i = 0; i < 400; i++) {
      if (c.read(sermonsProvider).valueOrNull != null) return;
      await Future<void>.delayed(Duration.zero);
    }
  }

  /// Pumps microtasks until the background walk finishes (or gives up).
  Future<void> settleHydration(ProviderContainer c) async {
    for (var i = 0; i < 200; i++) {
      if (!c.read(sermonLibraryProvider).hasMore &&
          c.read(sermonLibraryProvider).loaded) {
        return;
      }
      await Future<void>.delayed(Duration.zero);
    }
  }

  test('hydrates the whole archive in the background, no scrolling needed',
      () async {
    final (container, repo) = harness(autoHydrate: true);
    await container.read(sermonLibraryProvider.notifier).firstLoad;
    await settleHydration(container);

    final lib = container.read(sermonLibraryProvider);
    expect(lib.sermons.map((s) => s.id), ['1', '2', '3', '4'],
        reason: 'every page must land without a single loadMore() call');
    expect(lib.hasMore, isFalse);
    expect(lib.sermons.length, lib.totalCount);
    // Each page fetched exactly once.
    expect(repo.requested.length, 3);
  });

  test('oldest-first sort spans the decade, not just page 1', () async {
    // Mirrors the real archive: newest page first, 2013 on the last page.
    Sermon dated(String id, String title, DateTime when) => Sermon(
          id: id,
          title: title,
          speaker: 'David Antwi',
          audioUrl: 'https://x.test/$id.mp3',
          publishedAt: when,
        );
    final (container, _) = harness(
      autoHydrate: true,
      pages: [
        [dated('1', 'From Acts To Us', DateTime(2026, 8, 23))],
        [dated('2', 'Hope in God\u2019s Promise', DateTime(2019, 5, 5))],
        [dated('3', 'Who You Are In Christ - 3', DateTime(2013, 9, 18))],
      ],
    );
    await container.read(sermonLibraryProvider.notifier).firstLoad;
    await settleHydration(container);

    final sermons = container.read(sermonLibraryProvider).sermons.toList()
      ..sort((a, b) => (a.publishedAt ?? DateTime(0))
          .compareTo(b.publishedAt ?? DateTime(0)));
    expect(sermons.first.title, 'Who You Are In Christ - 3',
        reason: 'oldest-first must reach the end of the archive');
    expect(sermons.first.publishedAt!.year, 2013);
    expect(sermons.length, 3);
  });

  test('archive survives a JSON round-trip for the disk cache', () {
    final original = Sermon(
      id: '23929',
      title: 'Who You Are In Christ - 3',
      speaker: 'David Antwi',
      audioUrl: 'https://yetanothersermon.host/_/kc/media/mp3/23929.mp3',
      artworkUrl: 'https://x.test/art.jpg',
      duration: const Duration(minutes: 47, seconds: 12),
      publishedAt: DateTime(2013, 9, 18),
      series: 'Who You Are In Christ',
      description: 'Identity in Christ.',
      artworkColor: 9,
      category: 'Faith',
      videoId: 'abc123',
      source: 'kharis-api',
      isFeatured: true,
    );

    final restored = Sermon.fromJson(original.toJson());
    expect(restored, original);
    expect(restored.duration, const Duration(minutes: 47, seconds: 12));
    expect(restored.publishedAt, DateTime(2013, 9, 18));
    expect(restored.videoId, 'abc123');
    expect(restored.source, 'kharis-api');
    expect(restored.isFeatured, isTrue);
  });

  // ── Year navigation ────────────────────────────────────────────────────────
  //
  // Reachable is not the same as navigable: 1,485 sermons across 2013-2026 need
  // a jump, not a scroll. These guard the year rail's data.

  test('archive years are derived newest-first with per-year counts', () async {
    Sermon dated(String id, DateTime when) => Sermon(
          id: id,
          title: 'Message $id',
          speaker: 'David Antwi',
          audioUrl: 'https://x.test/$id.mp3',
          publishedAt: when,
        );
    final (container, _) = harness(
      autoHydrate: true,
      pages: [
        [dated('1', DateTime(2026, 8, 23)), dated('2', DateTime(2026, 1, 4))],
        [dated('3', DateTime(2019, 5, 5))],
        [dated('4', DateTime(2013, 9, 18)), dated('5', DateTime(2013, 11, 20))],
      ],
    );
    await container.read(sermonLibraryProvider.notifier).firstLoad;
    await settleHydration(container);
    // The year rails derive from the merged catalogue.
    await settleCatalogue(container);

    expect(container.read(archiveYearsProvider), [2026, 2019, 2013],
        reason: 'newest year first, one entry per year');
    expect(container.read(archiveYearCountsProvider),
        {2026: 2, 2019: 1, 2013: 2});
  });

  test('selecting a year narrows the library and clearing restores it',
      () async {
    Sermon dated(String id, String title, DateTime when) => Sermon(
          id: id,
          title: title,
          speaker: 'David Antwi',
          audioUrl: 'https://x.test/$id.mp3',
          publishedAt: when,
        );
    final (container, _) = harness(
      autoHydrate: true,
      pages: [
        [dated('1', 'From Acts To Us', DateTime(2026, 8, 23))],
        [dated('2', 'Question Time - Pt 1', DateTime(2013, 11, 20))],
        [dated('3', 'Who You Are In Christ - 3', DateTime(2013, 9, 18))],
      ],
    );
    await container.read(sermonLibraryProvider.notifier).firstLoad;
    await settleHydration(container);
    await settleCatalogue(container);

    expect(container.read(librarySermonsProvider).length, 3);

    container.read(selectedArchiveYearProvider.notifier).state = 2013;
    final only2013 = container.read(librarySermonsProvider);
    expect(only2013.length, 2);
    expect(only2013.every((s) => s.publishedAt!.year == 2013), isTrue);
    expect(
      only2013.map((s) => s.title),
      containsAll(['Question Time - Pt 1', 'Who You Are In Christ - 3']),
    );

    container.read(selectedArchiveYearProvider.notifier).state = null;
    expect(container.read(librarySermonsProvider).length, 3);
  });
}
