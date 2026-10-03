import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kharis_app/core/services/cache_service.dart';
import 'package:kharis_app/features/messages/data/kharis_api_sermon_repository.dart';
import 'package:kharis_app/shared/models/sermon.dart';
import 'package:kharis_app/shared/providers/sermon_provider.dart';

/// Per-year sermon counts of the live public API (1,489 sermons, 2013-2026).
const _yearCounts = {
  2026: 64,
  2025: 162,
  2024: 137,
  2023: 130,
  2022: 165,
  2021: 234,
  2020: 161,
  2019: 64,
  2018: 54,
  2017: 50,
  2016: 52,
  2015: 107,
  2014: 74,
  2013: 35,
};

const _pageSize = 50;

/// 1,489 API-shaped records, newest first, distributed like the real archive.
List<Map<String, dynamic>> _archive() {
  final out = <Map<String, dynamic>>[];
  var id = 200000;
  for (final entry in _yearCounts.entries) {
    for (var i = 0; i < entry.value; i++) {
      // Spread across the year, newest first within it.
      final day = DateTime(
        entry.key,
        12,
        28,
      ).subtract(Duration(days: (i * 360) ~/ entry.value));
      out.add({
        'id': id--,
        'title': 'Message ${entry.key}-$i',
        'date':
            '${day.year}-${day.month.toString().padLeft(2, '0')}-'
            '${day.day.toString().padLeft(2, '0')}',
        'time': null,
        'series': null,
        'preachers': [
          {'id': 1880, 'name': 'David Antwi'},
        ],
        'audio_link': {
          'duration': 2400,
          'download_url': 'yetanothersermon.host/_/kc/media/mp3/$id.mp3',
        },
        'video_link': '',
        'image': null,
        'description': null,
      });
    }
  }
  return out;
}

/// Serves `sermons/?page=N` from [records] in pages of 50, like the API:
/// absolute `next` links, `next: null` on the last page.
class _ArchiveAdapter implements HttpClientAdapter {
  _ArchiveAdapter(this.records);

  List<Map<String, dynamic>> records;
  final requestedPages = <int>[];

  /// Pages that fail once (HTTP 500) before succeeding.
  final failOnce = <int>{};

  /// Pages that wait for their completer before answering (once).
  final hold = <int, Completer<void>>{};

  int get pageCount => (records.length / _pageSize).ceil();

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final page = int.parse(options.uri.queryParameters['page'] ?? '1');
    requestedPages.add(page);
    if (failOnce.remove(page)) {
      return ResponseBody.fromString('{}', 500);
    }
    await hold.remove(page)?.future;
    final start = (page - 1) * _pageSize;
    final end = (start + _pageSize).clamp(0, records.length);
    final body = {
      'count': records.length,
      'next': page < pageCount
          ? 'https://x.test/api/sermons/?page=${page + 1}'
          : null,
      'previous': null,
      'results': records.sublist(start, end),
    };
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// In-memory [SermonArchiveStore].
class _MemoryStore implements SermonArchiveStore {
  _MemoryStore([this.snapshot]);

  SermonArchiveSnapshot? snapshot;
  int writes = 0;

  @override
  Future<SermonArchiveSnapshot?> readSermonArchive() async => snapshot;

  @override
  Future<void> writeSermonArchive(SermonArchiveSnapshot s) async {
    writes++;
    snapshot = s;
  }
}

void main() {
  (ProviderContainer, _ArchiveAdapter) harness({
    _MemoryStore? store,
    List<Map<String, dynamic>>? records,
    Duration backoff = Duration.zero,
  }) {
    final adapter = _ArchiveAdapter(records ?? _archive());
    final dio = Dio(BaseOptions(baseUrl: 'https://x.test/api/'))
      ..httpClientAdapter = adapter;
    final container = ProviderContainer(
      overrides: [
        sermonRepositoryProvider.overrideWithValue(
          KharisApiSermonRepository(dio: dio),
        ),
        sermonArchiveCacheProvider.overrideWithValue(store),
        sermonArchiveBackoffProvider.overrideWithValue((_) => backoff),
        cmsSermonsProvider.overrideWith(
          (ref) => Stream.value(const <Sermon>[]),
        ),
        selectedCategoryProvider.overrideWith((ref) => 'All'),
        sermonSortProvider.overrideWith((ref) => SermonSort.newest),
      ],
    );
    addTearDown(container.dispose);
    return (container, adapter);
  }

  /// Pages are mapped in a background isolate, so this waits on wall-clock
  /// time rather than a fixed number of event-loop turns.
  Future<void> settle(ProviderContainer c, bool Function() done) async {
    c.listen(sermonsProvider, (_, _) {}, fireImmediately: true);
    final clock = Stopwatch()..start();
    while (!done() && clock.elapsed < const Duration(seconds: 30)) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
    expect(done(), isTrue, reason: 'library never settled');
  }

  bool complete(ProviderContainer c) {
    final lib = c.read(sermonLibraryProvider);
    return lib.loaded &&
        !lib.hasMore &&
        !lib.hydrating &&
        lib.fetchedAt != null;
  }

  test('hydrates all 1,489 sermons across 30 pages back to 2013', () async {
    final (container, adapter) = harness();
    await settle(container, () => complete(container));
    await settle(
      container,
      () => container.read(sermonsProvider).valueOrNull?.length == 1489,
    );

    expect(adapter.pageCount, 30);
    expect(
      adapter.requestedPages,
      [for (var p = 1; p <= 30; p++) p],
      reason: 'each page exactly once, in order, stopping at next == null',
    );
    final lib = container.read(sermonLibraryProvider);
    expect(lib.sermons.length, 1489);
    expect(lib.totalCount, 1489);
    expect(lib.sermons.last.publishedAt!.year, 2013);

    // Year rail: every year present, with the API's counts.
    expect(
      container.read(archiveYearsProvider),
      _yearCounts.keys.toList()..sort((a, b) => b.compareTo(a)),
    );
    expect(container.read(archiveYearCountsProvider), _yearCounts);

    // Jumping to any year shows exactly that year's sermons.
    for (final year in [2013, 2019, 2026]) {
      container.read(selectedArchiveYearProvider.notifier).state = year;
      final list = container.read(librarySermonsProvider);
      expect(list.length, _yearCounts[year]);
      expect(list.every((s) => s.publishedAt!.year == year), isTrue);
    }
  });

  test(
    'a failed page retries on its own (no scrolling) and completes',
    () async {
      final (container, adapter) = harness();
      adapter.failOnce.addAll({7, 19});
      await settle(container, () => complete(container));

      final lib = container.read(sermonLibraryProvider);
      expect(lib.sermons.length, 1489);
      expect(lib.hydrationFailed, isFalse);
      expect(adapter.requestedPages.where((p) => p == 7).length, 2);
      expect(adapter.requestedPages.where((p) => p == 19).length, 2);
    },
  );

  test('persists the walked archive with its fetch time', () async {
    final store = _MemoryStore();
    final (container, _) = harness(store: store);
    await settle(container, () => complete(container));
    await settle(container, () => store.snapshot != null);

    expect(store.snapshot!.sermons.length, 1489);
    expect(
      store.snapshot!.fetchedAt,
      container.read(sermonLibraryProvider).fetchedAt,
    );
  });

  test(
    'a fresh cached archive paints without re-walking older pages',
    () async {
      final records = _archive();
      final cached = [for (final r in records) mapApiSermon(r)];
      final store = _MemoryStore(
        SermonArchiveSnapshot(sermons: cached, fetchedAt: DateTime.now()),
      );
      final (container, adapter) = harness(store: store, records: records);
      await container.read(sermonLibraryProvider.notifier).firstLoad;
      await settle(container, () => complete(container));

      expect(adapter.requestedPages, [1], reason: 'only new arrivals');
      expect(container.read(sermonLibraryProvider).sermons.length, 1489);
    },
  );

  test('a stale cached archive is re-walked: edits and removals reach '
      'older pages', () async {
    final records = _archive();
    final cached = [for (final r in records) mapApiSermon(r)];
    // Upstream since: an old record was retitled and another was deleted.
    final live = [...records];
    live[1400] = {...live[1400], 'title': 'Retitled 2013 message'};
    final removedId = live.removeAt(1300)['id'].toString();

    final store = _MemoryStore(
      SermonArchiveSnapshot(
        sermons: cached,
        fetchedAt: DateTime.now().subtract(const Duration(days: 3)),
      ),
    );
    final (container, adapter) = harness(store: store, records: live);
    final before = DateTime.now();
    await settle(
      container,
      () =>
          complete(container) &&
          container.read(sermonLibraryProvider).fetchedAt!.isAfter(before),
    );

    final lib = container.read(sermonLibraryProvider);
    expect(adapter.requestedPages.length, 30, reason: 'full re-walk');
    expect(lib.sermons.length, 1488);
    expect(lib.sermons.any((s) => s.id == removedId), isFalse);
    expect(lib.sermons.any((s) => s.title == 'Retitled 2013 message'), isTrue);
  });

  test('a refresh while the drain waits to retry resumes where it stopped, '
      'not from page 2', () async {
    // A long backoff keeps the failed walk parked until the refresh.
    final (container, adapter) = harness(backoff: const Duration(hours: 1));
    adapter.failOnce.add(6);
    final notifier = container.read(sermonLibraryProvider.notifier);
    await settle(
      container,
      () =>
          adapter.requestedPages.contains(6) &&
          !container.read(sermonLibraryProvider).hydrating,
    );
    expect(container.read(sermonLibraryProvider).sermons.length, 250);

    await notifier.refresh();
    await settle(container, () => complete(container));

    final lib = container.read(sermonLibraryProvider);
    expect(lib.sermons.length, 1489);
    for (var p = 2; p <= 5; p++) {
      expect(
        adapter.requestedPages.where((r) => r == p),
        hasLength(1),
        reason: 'page $p was already held; refetching it is wasted work',
      );
    }
    expect(adapter.requestedPages.where((r) => r == 6), hasLength(2));
    expect(adapter.requestedPages.where((r) => r == 1), hasLength(2));
  });

  test('a refresh during a re-walk keeps its new arrivals when the walk '
      'swaps in', () async {
    final records = _archive();
    final store = _MemoryStore(
      SermonArchiveSnapshot(
        sermons: [for (final r in records) mapApiSermon(r)],
        fetchedAt: DateTime.now().subtract(const Duration(days: 3)),
      ),
    );
    final (container, adapter) = harness(store: store, records: records);
    final held = Completer<void>();
    adapter.hold[10] = held;
    final before = DateTime.now();
    await settle(container, () => adapter.requestedPages.contains(10));

    // A message is published while the walk is parked on page 10, and the
    // member pulls to refresh.
    adapter.records = [
      {...records.first, 'id': 300000, 'title': 'Brand new message'},
      ...records,
    ];
    await container.read(sermonLibraryProvider.notifier).refresh();
    expect(
      container
          .read(sermonLibraryProvider)
          .sermons
          .any((s) => s.title == 'Brand new message'),
      isTrue,
    );

    held.complete();
    await settle(
      container,
      () =>
          complete(container) &&
          container.read(sermonLibraryProvider).fetchedAt!.isAfter(before),
    );
    final lib = container.read(sermonLibraryProvider);
    expect(lib.sermons.first.title, 'Brand new message');
    expect(lib.sermons.length, 1490);
  });
}
