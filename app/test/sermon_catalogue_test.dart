import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kharis_app/core/utils/sermon_categorizer.dart';
import 'package:kharis_app/features/messages/data/kharis_api_sermon_repository.dart';
import 'package:kharis_app/shared/models/sermon.dart';
import 'package:kharis_app/shared/providers/onboarding_provider.dart';
import 'package:kharis_app/shared/providers/sermon_provider.dart';

import 'support/fake_sermon_repository.dart';

/// ~200 real records from the public API (all years, the video-only and
/// media-less records, every youtu.be/bare-link shape, three complete series).
List<Map<String, dynamic>> _fixture() =>
    (jsonDecode(File('test/fixtures/sermons_sample.json').readAsStringSync())
            as List)
        .cast<Map<String, dynamic>>();

void main() {
  late List<Map<String, dynamic>> records;
  late List<Sermon> sermons;

  setUpAll(() {
    records = _fixture();
    sermons = [for (final r in records) mapApiSermon(r)];
  });

  Future<ProviderContainer> library(
    List<Sermon> catalogue, {
    FakePagedSermonRepository? repo,
    List<Override> extra = const [],
  }) async {
    final container = ProviderContainer(
      overrides: [
        sermonRepositoryProvider.overrideWithValue(
          repo ?? FakePagedSermonRepository([catalogue]),
        ),
        sermonArchiveAutoHydrateProvider.overrideWithValue(false),
        cmsSermonsProvider.overrideWith(
          (ref) => Stream.value(const <Sermon>[]),
        ),
        selectedCategoryProvider.overrideWith((ref) => 'All'),
        sermonSortProvider.overrideWith((ref) => SermonSort.newest),
        searchDebounceProvider.overrideWithValue(Duration.zero),
        ...extra,
      ],
    );
    addTearDown(container.dispose);
    container.listen(sermonsProvider, (_, _) {});
    await container.read(sermonLibraryProvider.notifier).firstLoad;
    await container.read(sermonsProvider.future);
    return container;
  }

  group('topics', () {
    test('every fixture sermon lands in exactly one known topic', () async {
      expect(records.length, greaterThanOrEqualTo(200));
      final c = await library(sermons);
      expect(
        c.read(sermonsProvider).value,
        hasLength(records.length),
        reason: 'no record is dropped, media or not',
      );

      final counts = c.read(categoryCountsProvider);
      expect(counts.keys.every(kTopicCategories.contains), isTrue);
      expect(
        counts.values.fold(0, (a, b) => a + b),
        records.length,
        reason: 'chip counts sum to the library size',
      );

      // Filtering by each chip partitions the library.
      final seen = <String>{};
      for (final label in c.read(categoryLabelsProvider).skip(1)) {
        c.read(selectedCategoryProvider.notifier).state = label;
        final list = c.read(librarySermonsProvider);
        expect(list.length, counts[label]);
        for (final s in list) {
          expect(seen.add(s.id), isTrue, reason: '${s.id} in two topics');
        }
      }
      expect(seen.length, records.length);
      expect(
        c.read(categoryLabelsProvider).last,
        kOtherCategory,
        reason: 'catch-all is the last chip when present',
      );
    });

    test('series names never become topics (old bug: series as category)', () {
      for (final s in sermons) {
        expect(kTopicCategories, contains(s.category));
      }
      final withSeries = sermons.where((s) => s.series != null);
      expect(withSeries, isNotEmpty);
      expect(withSeries.any((s) => s.category == s.series), isFalse);
    });

    test('keyword coverage on the fixture stays high', () {
      final other = sermons.where((s) => s.category == kOtherCategory).length;
      expect(other / sermons.length, lessThan(0.05));
    });

    test('title beats description; placeholder descriptions are ignored', () {
      expect(
        sermonCategory(
          'The Mystery Of Fasting',
          description: 'Jesus, God, Christ, mystery and more.',
        ),
        'Prayer & Fasting',
      );
      expect(
        sermonCategory('Unclassifiable', description: '#Podcast'),
        kOtherCategory,
      );
      expect(
        sermonCategory(
          'Unclassifiable',
          description: 'Learn how to pray without ceasing.',
        ),
        'Prayer & Fasting',
      );
    });

    test('topicOf keeps known labels and re-derives legacy ones', () {
      expect(topicOf(title: 'x', category: 'Holy Spirit'), 'Holy Spirit');
      expect(
        topicOf(title: 'Grace Abounds', category: 'Messages'),
        'Grace & Salvation',
      );
      expect(
        topicOf(title: 'Grace Abounds', category: 'Book of Acts'),
        'Grace & Salvation',
      );
    });
  });

  group('series', () {
    test('series rail lists every API series with its member count', () async {
      final c = await library(sermons);
      final expected = <String, int>{};
      for (final r in records) {
        final name = (r['series'] as Map?)?['name'] as String?;
        if (name != null && name.trim().isNotEmpty) {
          expected[name.trim()] = (expected[name.trim()] ?? 0) + 1;
        }
      }
      final rail = {
        for (final s in c.read(seriesListProvider)) s.name: s.count,
      };
      expect(rail, expected);
    });

    test('series filter returns exactly the API series members', () async {
      final c = await library(sermons);
      for (final series in c.read(seriesListProvider)) {
        c.read(selectedSeriesProvider.notifier).state = series.name;
        final ids = c.read(librarySermonsProvider).map((s) => s.id).toSet();
        final expected = {
          for (final r in records)
            if (((r['series'] as Map?)?['name'] as String?)?.trim() ==
                series.name)
              r['id'].toString(),
        };
        expect(ids, expected, reason: series.name);
      }
    });
  });

  group('years', () {
    test('year counts and the year filter match the record dates', () async {
      final c = await library(sermons);
      final expected = <int, int>{};
      for (final r in records) {
        final y = int.parse((r['date'] as String).substring(0, 4));
        expected[y] = (expected[y] ?? 0) + 1;
      }
      expect(c.read(archiveYearCountsProvider), expected);
      expect(c.read(archiveYearsProvider).first, 2026);
      expect(c.read(archiveYearsProvider).last, 2013);
      for (final year in expected.keys) {
        c.read(selectedArchiveYearProvider.notifier).state = year;
        final list = c.read(librarySermonsProvider);
        expect(list.length, expected[year]);
        expect(list.every((s) => s.publishedAt!.year == year), isTrue);
      }
    });
  });

  group('search predicate', () {
    final s = testSermon(
      '1',
      title: 'Christ: The Eternally Blessed God',
      speaker: 'David Antwi',
      series: 'Book of Acts',
      description: 'The truth of the Gospel is meant to be understood.',
    );

    test('matches title, speaker, series and description', () {
      expect(sermonMatchesQuery(s, 'eternally'), isTrue);
      expect(sermonMatchesQuery(s, 'antwi'), isTrue);
      expect(sermonMatchesQuery(s, 'book of acts'), isTrue);
      expect(sermonMatchesQuery(s, 'gospel'), isTrue);
    });

    test('every word must match somewhere; case and quotes ignored', () {
      expect(sermonMatchesQuery(s, 'ACTS gospel'), isTrue);
      expect(sermonMatchesQuery(s, 'acts marriage'), isFalse);
      final quoted = testSermon('2', title: 'God\u2019s Masterpiece');
      expect(sermonMatchesQuery(quoted, "god's"), isTrue);
    });

    test('empty query matches nothing', () {
      expect(sermonMatchesQuery(s, '   '), isFalse);
    });
  });

  group('search results', () {
    test(
      'loading while the server search is pending, never "no results"',
      () async {
        final remoteHit = testSermon(
          '900',
          title: 'Server only hit',
          publishedAt: DateTime(2014, 1, 1),
        );
        final repo = FakePagedSermonRepository(
          [
            [
              testSermon(
                '1',
                title: 'Local grace',
                publishedAt: DateTime(2026),
              ),
            ],
          ],
          searchPages: {
            'zebra': [
              [remoteHit],
              [testSermon('901', title: 'Page two hit')],
            ],
          },
        );
        final c = await library(const [], repo: repo);
        c.listen(remoteSearchProvider, (_, _) {});
        c.read(sermonSearchProvider.notifier).state = 'zebra';

        expect(c.read(searchResultsProvider), isEmpty);
        expect(
          c.read(searchLoadingProvider),
          isTrue,
          reason: 'empty + loading must render a spinner',
        );

        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(c.read(searchLoadingProvider), isFalse);
        expect(c.read(searchResultsProvider).map((s) => s.id), ['900']);

        // Following `next` brings in the second server page.
        expect(c.read(remoteSearchProvider).hasMore, isTrue);
        await c.read(remoteSearchProvider.notifier).loadMore();
        expect(
          c.read(searchResultsProvider).map((s) => s.id),
          containsAll(['900', '901']),
        );
        expect(c.read(remoteSearchProvider).hasMore, isFalse);
      },
    );

    test('local matches cover series and description', () async {
      final c = await library(sermons);
      c.read(sermonSearchProvider.notifier).state = 'Oil Campaign';
      final results = c.read(searchResultsProvider);
      expect(results, isNotEmpty);
      expect(
        results.every((s) => sermonMatchesQuery(s, 'Oil Campaign')),
        isTrue,
      );
    });
  });

  group('recent searches', () {
    test('keeps the last 8, newest first, deduped, and persists', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final c = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(c.dispose);
      final notifier = c.read(recentSearchesProvider.notifier);
      for (var i = 0; i < 10; i++) {
        notifier.add('query $i');
      }
      notifier.add('QUERY 5');
      notifier.add(' ');
      final list = c.read(recentSearchesProvider);
      expect(list, hasLength(8));
      expect(list.first, 'QUERY 5');
      expect(list.where((q) => q.toLowerCase() == 'query 5'), hasLength(1));

      // A new session reads them back.
      final c2 = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(c2.dispose);
      expect(c2.read(recentSearchesProvider), list);
    });
  });
}
