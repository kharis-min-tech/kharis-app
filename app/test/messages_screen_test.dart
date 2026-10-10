import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/features/messages/data/curation_repository.dart';
import 'package:kharis_app/features/messages/data/sermon_repository_base.dart';
import 'package:kharis_app/features/messages/presentation/screens/messages_screen.dart';
import 'package:kharis_app/shared/models/sermon.dart';
import 'package:kharis_app/shared/providers/audio_provider.dart';
import 'package:kharis_app/shared/providers/branch_provider.dart';
import 'package:kharis_app/shared/providers/cache_provider.dart';
import 'package:kharis_app/shared/providers/sermon_provider.dart';

import 'support/fake_audio_player_service.dart';
import 'support/fake_cache_service.dart';
import 'support/fake_sermon_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  final live = [
    for (var i = 1; i <= 3; i++)
      testSermon(
        '$i',
        title: 'Live message $i',
        publishedAt: DateTime(2026, 9, i),
      ),
  ];

  Widget app(
    FakePagedSermonRepository repo, {
    Duration? debounce,
    List<Sermon> videos = const [],
    List<Override> extra = const [],
  }) => ProviderScope(
    overrides: [
      sermonRepositoryProvider.overrideWithValue(repo),
      sermonArchiveAutoHydrateProvider.overrideWithValue(false),
      cmsSermonsProvider.overrideWith((ref) => Stream.value(const <Sermon>[])),
      videosProvider.overrideWith((ref) async => videos),
      firestoreProvider.overrideWithValue(FakeFirebaseFirestore()),
      cacheServiceProvider.overrideWithValue(FakeCacheService()),
      audioPlayerServiceProvider.overrideWithValue(FakeAudioPlayerService()),
      if (debounce != null) searchDebounceProvider.overrideWithValue(debounce),
      ...extra,
    ],
    child: const MaterialApp(home: MessagesScreen()),
  );

  testWidgets('offline fallback shows a banner whose Retry goes live', (
    tester,
  ) async {
    final repo = FakePagedSermonRepository(
      [live],
      failFirstLoad: true,
      catalogue: [testSermon('archive_1', title: 'Bundled message')],
    );
    await tester.pumpWidget(app(repo));
    await tester.pumpAndSettle();

    expect(find.text('Offline archive'), findsOneWidget);
    expect(find.text('Bundled message'), findsOneWidget);

    repo.failFirstLoad = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.text('Offline archive'), findsNothing);
    expect(find.text('Live message 3'), findsWidgets);
    expect(find.text('Bundled message'), findsNothing);
  });

  testWidgets('pull to refresh refetches page 1', (tester) async {
    final repo = FakePagedSermonRepository([live]);
    await tester.pumpWidget(app(repo));
    await tester.pumpAndSettle();
    expect(repo.requested.where((u) => u == null), hasLength(1));

    await tester.fling(find.text('Messages').first, const Offset(0, 400), 1000);
    await tester.pumpAndSettle();
    expect(repo.requested.where((u) => u == null), hasLength(2));
    expect(find.text('Live message 3'), findsWidgets);
  });

  testWidgets('the search field stays a pill when idle and focused (KA-014)', (
    tester,
  ) async {
    await tester.pumpWidget(app(FakePagedSermonRepository([live])));
    await tester.pumpAndSettle();

    final field = find.byWidgetPredicate(
      (w) =>
          w is TextField &&
          (w.decoration?.hintText ?? '').startsWith('Search titles'),
    );
    final decoration = tester.widget<TextField>(field).decoration!;
    // The fill is painted in the border's shape: a non-pill idle border
    // paints a rectangle behind the rounded search bar.
    for (final border in [
      decoration.border,
      decoration.enabledBorder,
      decoration.focusedBorder,
    ]) {
      expect(border, isA<OutlineInputBorder>());
      expect(
        (border! as OutlineInputBorder).borderRadius,
        BorderRadius.circular(AppRadius.pill),
      );
    }
  });

  testWidgets('search shows a spinner while loading, never "no results"', (
    tester,
  ) async {
    final repo = FakePagedSermonRepository(
      [live],
      searchPages: {
        'zebra': [
          [testSermon('99', title: 'Zebra on the server')],
        ],
      },
    );
    await tester.pumpWidget(
      app(repo, debounce: const Duration(milliseconds: 300)),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'zebra');
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsWidgets);
    expect(find.textContaining('No messages match'), findsNothing);

    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text('Zebra on the server'), findsOneWidget);
    expect(find.textContaining('No messages match'), findsNothing);
  });

  testWidgets('recent searches appear on focus and refill the field', (
    tester,
  ) async {
    final repo = FakePagedSermonRepository([live]);
    await tester.pumpWidget(app(repo, debounce: Duration.zero));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Live message 2');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Clear search'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    expect(find.text('Recent searches'), findsOneWidget);

    await tester.tap(find.text('Live message 2').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('1 result for'), findsOneWidget);
  });

  testWidgets('the featured dots stay in range when the carousel shrinks', (
    tester,
  ) async {
    final cards = StateProvider<List<Sermon>>(
      (ref) => [
        for (var i = 0; i < 5; i++) testSermon('f$i', title: 'Featured $i'),
      ],
    );
    await tester.pumpWidget(
      app(
        FakePagedSermonRepository([live]),
        extra: [
          featuredSermonsProvider.overrideWith((ref) => ref.watch(cards)),
        ],
      ),
    );
    await tester.pumpAndSettle();

    /// Index of the highlighted page dot, or -1 when none is.
    int activeDot() {
      final dots = tester
          .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
          .where((w) => w.constraints?.maxHeight == 6)
          .toList();
      return dots.indexWhere((w) => w.constraints?.maxWidth == 18);
    }

    for (var i = 0; i < 4; i++) {
      await tester.drag(find.byType(PageView), const Offset(-400, 0));
      await tester.pumpAndSettle();
    }
    expect(activeDot(), 4);

    ProviderScope.containerOf(
      tester.element(find.byType(MessagesScreen)),
    ).read(cards.notifier).state = [
      testSermon('p0', title: 'Pinned 0'),
      testSermon('p1', title: 'Pinned 1'),
    ];
    await tester.pumpAndSettle();
    expect(activeDot(), 1, reason: 'the last card is the one on screen');
  });

  testWidgets('a library short of the server count shows the honest count '
      'and its Retry re-walks the archive', (tester) async {
    final archive = [
      for (var i = 1; i <= 25; i++)
        testSermon(
          'a$i',
          title: 'Archive message $i',
          publishedAt: DateTime(2026, 8, i),
        ),
    ];
    final repo = _ShortRepo([archive]);
    await tester.pumpWidget(app(repo));
    await tester.pumpAndSettle();

    final short = find.text('25 of 26 messages \u2022');
    await tester.scrollUntilVisible(
      short,
      600,
      scrollable: find.byType(Scrollable).first,
    );
    expect(short, findsOneWidget);
    expect(find.textContaining('reached the beginning'), findsNothing);

    repo.missing = 0;
    final pageOnes = repo.requested.where((u) => u == null).length;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(repo.requested.where((u) => u == null), hasLength(pageOnes + 1));
    expect(short, findsNothing);
    expect(
      find.text('You\'ve reached the beginning \u00b7 25 messages'),
      findsOneWidget,
    );
  });

  group('featured mode', () {
    final videos = [
      testSermon(
        'v1',
        title: 'Featured upload',
        audioUrl: '',
        videoId: 'v1',
        publishedAt: DateTime(2026, 9, 20),
        source: 'youtube',
      ),
    ];

    testWidgets('auto leads with the featured carousel', (tester) async {
      await tester.pumpWidget(
        app(
          FakePagedSermonRepository([live]),
          videos: videos,
          extra: [
            featuredModeProvider.overrideWith(
              (ref) => Stream.value(FeaturedMode.auto),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('FEATURED'), findsWidgets);
      expect(find.byKey(const ValueKey('messages-latest')), findsNothing);
    });

    testWidgets('off hides the carousel and leads with the latest messages', (
      tester,
    ) async {
      await tester.pumpWidget(
        app(
          FakePagedSermonRepository([live]),
          videos: videos,
          extra: [
            featuredModeProvider.overrideWith(
              (ref) => Stream.value(FeaturedMode.off),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('FEATURED'), findsNothing);
      expect(find.text('Featured upload'), findsNothing);
      expect(find.text('Latest messages'), findsOneWidget);
      // Newest first, ahead of the topics and the full list.
      final latest = tester.getTopLeft(find.text('Latest messages'));
      final newest = find.text('Live message 3').first;
      expect(tester.getTopLeft(newest).dy, greaterThan(latest.dy));
      expect(
        tester.getTopLeft(newest).dy,
        lessThan(tester.getTopLeft(find.text('Browse by topic')).dy),
      );
    });
  });
}

/// Reports [missing] more sermons than it serves, like an archive with a
/// record no walk ever sees.
class _ShortRepo extends FakePagedSermonRepository {
  _ShortRepo(super.pages);

  int missing = 1;

  @override
  Future<SermonPage> fetchPage({String? url, String? search}) async {
    final page = await super.fetchPage(url: url, search: search);
    return SermonPage(
      sermons: page.sermons,
      nextUrl: page.nextUrl,
      totalCount: page.totalCount + missing,
    );
  }
}
