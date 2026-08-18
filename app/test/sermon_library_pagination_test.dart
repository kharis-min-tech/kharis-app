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
  (ProviderContainer, _FakePagedRepo) harness(
      {List<List<Sermon>>? pages, bool failFirstLoad = false}) {
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
}
