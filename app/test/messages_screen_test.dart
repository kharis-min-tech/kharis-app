import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kharis_app/features/messages/presentation/screens/downloads_screen.dart';
import 'package:kharis_app/features/messages/presentation/screens/listening_history_screen.dart';
import 'package:kharis_app/features/messages/presentation/screens/message_search_screen.dart';
import 'package:kharis_app/features/messages/presentation/screens/messages_screen.dart';
import 'package:kharis_app/features/home/data/bible_repository.dart';
import 'package:kharis_app/features/playlists/data/playlist_repository.dart';
import 'package:kharis_app/features/playlists/providers/playlist_providers.dart';
import 'package:kharis_app/shared/models/sermon.dart';
import 'package:kharis_app/shared/providers/audio_provider.dart';
import 'package:kharis_app/shared/providers/branch_provider.dart';
import 'package:kharis_app/shared/providers/cache_provider.dart';
import 'package:kharis_app/shared/providers/downloads_provider.dart';
import 'package:kharis_app/shared/providers/listening_history_provider.dart';
import 'package:kharis_app/shared/providers/sermon_provider.dart';
import 'package:kharis_app/ui/components/components.dart';

import 'support/design_harness.dart';
import 'support/fake_audio_player_service.dart';
import 'support/fake_cache_service.dart';
import 'support/fake_sermon_repository.dart';

void main() {
  setUpAll(loadDesignAssets);

  final library = [
    testSermon(
      '1',
      title: 'Faith part one',
      series: 'Faith',
      speaker: 'David Antwi',
      publishedAt: DateTime(2026, 9, 1),
    ).copyWith(duration: const Duration(minutes: 15)),
    testSermon(
      '2',
      title: 'Faith part two',
      series: 'Faith',
      speaker: 'David Antwi',
      publishedAt: DateTime(2026, 9, 8),
    ).copyWith(duration: const Duration(minutes: 45)),
    testSermon(
      '3',
      title: 'The good shepherd',
      speaker: 'Grace Mensah',
      publishedAt: DateTime(2025, 3, 2),
    ).copyWith(passages: ['John 10:1-18']),
  ];

  Widget app(
    Widget home, {
    List<Sermon> sermons = const [],
    FakePagedSermonRepository? repo,
    List<Override> extra = const [],
  }) {
    return ProviderScope(
      overrides: [
        sermonRepositoryProvider.overrideWithValue(
          repo ?? FakePagedSermonRepository([sermons]),
        ),
        sermonArchiveAutoHydrateProvider.overrideWithValue(false),
        cmsSermonsProvider.overrideWith(
          (ref) => Stream.value(const <Sermon>[]),
        ),
        videosProvider.overrideWith((ref) async => const <Sermon>[]),
        firestoreProvider.overrideWithValue(FakeFirebaseFirestore()),
        cacheServiceProvider.overrideWithValue(FakeCacheService()),
        audioPlayerServiceProvider.overrideWithValue(FakeAudioPlayerService()),
        searchDebounceProvider.overrideWithValue(Duration.zero),
        playlistsProvider.overrideWith(
          (ref) => Stream.value(const <Playlist>[]),
        ),
        ...extra,
      ],
      child: MaterialApp(theme: KharisTheme.light(), home: home),
    );
  }

  Future<void> pump(WidgetTester tester, Widget widget) async {
    tester.view.physicalSize = const Size(390, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();
  }

  group('Messages', () {
    testWidgets('lays out at 200% text on a phone, on every tab', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        app(
          Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2)),
              child: const MessagesScreen(),
            ),
          ),
          sermons: library,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      final vertical = find.byWidgetPredicate(
        (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
      );
      for (final tab in ['For you', 'Books', 'Themes', 'Series', 'Downloads']) {
        await tester.ensureVisible(find.text(tab));
        await tester.pumpAndSettle();
        await tester.tap(find.text(tab));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: tab);
        for (var i = 0; i < 4; i++) {
          await tester.drag(vertical.first, const Offset(0, -400));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: tab);
        }
        await tester.drag(vertical.first, const Offset(0, 4000));
        await tester.pumpAndSettle();
      }
    });

    testWidgets('leads with the newest series part; Books shows only once a '
        'message names a passage', (tester) async {
      await pump(tester, app(const MessagesScreen(), sermons: library));

      final hero = find.byKey(const Key('messages-hero'));
      expect(
        find.descendant(of: hero, matching: find.text('Faith part two')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: hero, matching: find.text('New \u00b7 Part 2')),
        findsOneWidget,
      );
      for (final tab in ['For you', 'Books', 'Themes', 'Series', 'Downloads']) {
        expect(find.text(tab), findsOneWidget, reason: tab);
      }

      await pump(
        tester,
        app(
          const MessagesScreen(),
          sermons: [for (final s in library) s.copyWith(passages: const [])],
        ),
      );
      expect(find.text('Books'), findsNothing);
    });

    testWidgets('Books lists the books messages are preached from and opens '
        'their messages', (tester) async {
      await pump(tester, app(const MessagesScreen(), sermons: library));

      await tester.tap(find.text('Books'));
      await tester.pumpAndSettle();
      expect(find.text('John'), findsOneWidget);
      expect(find.text('1 message'), findsOneWidget);

      await tester.tap(find.text('John'));
      await tester.pumpAndSettle();
      expect(find.text('The good shepherd'), findsOneWidget);
      expect(find.text('John 10:1-18'), findsOneWidget);
    });

    testWidgets('Series opens the parts in preaching order', (tester) async {
      await pump(tester, app(const MessagesScreen(), sermons: library));

      await tester.tap(find.text('Series'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Faith'));
      await tester.pumpAndSettle();

      final one = tester.getTopLeft(find.text('Faith part one'));
      final two = tester.getTopLeft(find.text('Faith part two'));
      expect(one.dy, lessThan(two.dy));
    });

    testWidgets('Downloads shows its empty state', (tester) async {
      await pump(tester, app(const MessagesScreen(), sermons: library));

      await tester.tap(find.text('Downloads'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('downloads-empty')), findsOneWidget);
    });

    testWidgets('offline with nothing saved offers a Retry that goes live', (
      tester,
    ) async {
      final repo = FakePagedSermonRepository([library], failFirstLoad: true);
      await pump(tester, app(const MessagesScreen(), repo: repo));
      expect(find.text('Retry'), findsOneWidget);

      repo.failFirstLoad = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('messages-hero')), findsOneWidget);
    });

    testWidgets('an empty archive, loaded online, shows an empty state that '
        'leads to Downloads', (tester) async {
      await pump(tester, app(const MessagesScreen(), sermons: const []));
      expect(find.byKey(const Key('messages-empty')), findsOneWidget);
      expect(find.text('Retry'), findsNothing);

      await tester.tap(find.text('Your downloads'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('downloads-empty')), findsOneWidget);
    });

    testWidgets('the tabs sit on the gutter, inset once', (tester) async {
      await pump(tester, app(const MessagesScreen(), sermons: library));
      expect(tester.getTopLeft(find.text('For you')).dx, KSpace.gutter);
    });
  });

  group('Search', () {
    testWidgets('finds by word, says how it is sorted, and narrows by '
        'length; unknown lengths drop out only then', (tester) async {
      await pump(tester, app(const MessageSearchScreen(), sermons: library));

      final row = tester.widget<KChipRow>(
        find.byKey(const Key('search-filters')),
      );
      expect(
        [for (final c in row.children) (c.key! as ValueKey<String>).value],
        [
          for (final f in ['sort', 'book', 'theme', 'series', 'date', 'length'])
            'search-filter-$f',
        ],
      );

      await tester.enterText(find.byType(TextField), 'faith');
      await tester.pumpAndSettle();
      expect(
        find.text('2 messages \u00b7 Sorted by most relevant'),
        findsOneWidget,
      );

      await tester.enterText(find.byType(TextField), '');
      await tester.pumpAndSettle();
      await tester.dragUntilVisible(
        find.byKey(const ValueKey('search-filter-length')),
        find.byKey(const Key('search-filters')),
        const Offset(-200, 0),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('search-filter-length')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Under 20 min'));
      await tester.tap(find.text('Show results'));
      await tester.pumpAndSettle();

      expect(find.text('Faith part one'), findsOneWidget);
      expect(find.text('Faith part two'), findsNothing);
      expect(find.text('The good shepherd'), findsNothing);
      expect(find.text('Under 20 min'), findsOneWidget, reason: 'chip');
    });

    testWidgets('Sort orders the results and names the order', (tester) async {
      await pump(tester, app(const MessageSearchScreen(), sermons: library));
      await tester.enterText(find.byType(TextField), 'faith');
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('search-filter-sort')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Oldest first'));
      await tester.tap(find.text('Show results'));
      await tester.pumpAndSettle();

      expect(
        find.text('2 messages \u00b7 Sorted by oldest first'),
        findsOneWidget,
      );
      expect(
        tester.getTopLeft(find.text('Faith part one')).dy,
        lessThan(tester.getTopLeft(find.text('Faith part two')).dy),
      );
    });

    testWidgets('a submitted search is kept and refills the field', (
      tester,
    ) async {
      await pump(tester, app(const MessageSearchScreen(), sermons: library));

      await tester.enterText(find.byType(TextField), 'shepherd');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('search-clear')));
      await tester.pumpAndSettle();

      expect(find.text('Recent searches'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('recent-shepherd')));
      await tester.pumpAndSettle();
      expect(find.text('The good shepherd'), findsOneWidget);
    });

    test('matchesFilters needs every filter to pass', () {
      final s = library[2];
      expect(
        matchesFilters(s, {
          SearchFilter.book: {'JHN'},
          SearchFilter.date: {'2025'},
        }, BibleIndex.bundled()),
        isTrue,
      );
      expect(
        matchesFilters(s, {
          SearchFilter.book: {'JHN'},
          SearchFilter.date: {'2026'},
        }, BibleIndex.bundled()),
        isFalse,
      );
      expect(matchesFilters(s, {}, BibleIndex.bundled()), isTrue);
      expect(
        matchesFilters(s, {
          SearchFilter.length: {'under20', 'from20to40', 'over40'},
        }, BibleIndex.bundled()),
        isFalse,
        reason: 'no known length',
      );
    });
  });

  group('History and Downloads', () {
    testWidgets('History lists the messages played', (tester) async {
      await pump(
        tester,
        app(
          const ListeningHistoryScreen(),
          extra: [
            listeningHistoryProvider.overrideWithValue([
              UnfinishedPlay(
                sermon: library[0],
                position: const Duration(minutes: 10),
                duration: const Duration(minutes: 40),
              ),
            ]),
          ],
        ),
      );
      expect(find.text('Faith part one'), findsOneWidget);
    });

    testWidgets('History with nothing played shows its empty state', (
      tester,
    ) async {
      await pump(
        tester,
        app(
          const ListeningHistoryScreen(),
          extra: [listeningHistoryProvider.overrideWithValue(const [])],
        ),
      );
      expect(find.byKey(const Key('history-empty')), findsOneWidget);
    });

    testWidgets('Downloads totals the saved files', (tester) async {
      await pump(
        tester,
        app(
          const DownloadsScreen(),
          extra: [
            downloadsProvider.overrideWithValue([
              DownloadedMessage(
                sermon: library[0],
                fileName: '1.mp3',
                bytes: 40 * 1024 * 1024,
                savedAt: DateTime(2026, 9, 2),
              ),
              DownloadedMessage(
                sermon: library[2],
                fileName: '3.mp3',
                bytes: 8 * 1024 * 1024,
                savedAt: DateTime(2026, 9, 3),
              ),
            ]),
          ],
        ),
      );
      expect(
        find.text('2 messages \u00b7 48 MB on this phone'),
        findsOneWidget,
      );
      expect(find.text('40 MB'), findsOneWidget);
    });

    test('formatBytes', () {
      expect(formatBytes(800 * 1024), '800 KB');
      expect(formatBytes(48 * 1024 * 1024), '48 MB');
      expect(formatBytes(1288490189), '1.2 GB');
    });
  });
}
