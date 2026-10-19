import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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

  testWidgets(
    'offline with nothing saved shows a banner whose Retry goes live',
    (tester) async {
      final repo = FakePagedSermonRepository([live], failFirstLoad: true);
      await tester.pumpWidget(app(repo));
      await tester.pumpAndSettle();

      expect(find.text('You are offline'), findsOneWidget);
      expect(
        find.text('Messages will appear here once you are back online.'),
        findsOneWidget,
      );

      repo.failFirstLoad = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.text('You are offline'), findsNothing);
      expect(find.text('Live message 3'), findsWidgets);
    },
  );

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
    expect(find.text('That\'s all 25 messages'), findsOneWidget);
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

  for (final reduceMotion in [false, true]) {
    testWidgets('back to top appears well down the list and returns to the top '
        '(reduced motion: $reduceMotion)', (tester) async {
      final many = [
        for (var i = 1; i <= 60; i++)
          testSermon(
            'm$i',
            title: 'Message $i',
            publishedAt: DateTime(2026, 1, 1).add(Duration(days: i)),
          ),
      ];
      final repo = FakePagedSermonRepository([many]);
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(disableAnimations: reduceMotion),
          child: app(repo),
        ),
      );
      await tester.pumpAndSettle();

      bool shown() =>
          tester
              .widget<IgnorePointer>(
                find
                    .ancestor(
                      of: find.byKey(const Key('messages-back-to-top')),
                      matching: find.byType(IgnorePointer),
                    )
                    .first,
              )
              .ignoring ==
          false;

      expect(shown(), isFalse);
      expect(find.bySemanticsLabel('Back to top'), findsNothing);

      final scrollable = tester.state<ScrollableState>(
        find.byType(Scrollable).first,
      );
      scrollable.position.jumpTo(2000);
      await tester.pumpAndSettle();
      expect(shown(), isTrue);

      await tester.tap(find.byKey(const Key('messages-back-to-top')));
      await tester.pumpAndSettle();
      expect(scrollable.position.pixels, 0);
      expect(shown(), isFalse);
    });
  }

  group('chip rows are never clipped', () {
    final archive = [
      testSermon(
        'a',
        title: 'Older message',
        series: 'Faith Walk',
        publishedAt: DateTime(2025, 3, 2),
      ),
      testSermon(
        'b',
        title: 'Newer message',
        series: 'Faith Walk',
        publishedAt: DateTime(2026, 9, 6),
      ),
    ];

    /// The label is laid out at its full height and sits wholly inside its
    /// nearest [box] ancestor: nothing cuts the text.
    void expectUnclipped(WidgetTester tester, Finder text, Type box) {
      final paragraph = tester.renderObject<RenderParagraph>(text);
      final full = paragraph.getMaxIntrinsicHeight(paragraph.size.width);
      expect(
        paragraph.size.height,
        greaterThanOrEqualTo(full - 0.5),
        reason: '$text squeezed to ${paragraph.size.height} of $full',
      );
      final rect = tester.getRect(text);
      final outer = tester.getRect(
        find.ancestor(of: text, matching: find.byType(box)).first,
      );
      expect(rect.top, greaterThanOrEqualTo(outer.top - 0.5), reason: '$text');
      expect(
        rect.bottom,
        lessThanOrEqualTo(outer.bottom + 0.5),
        reason: '$text',
      );
    }

    for (final scale in [1.0, 2.0]) {
      testWidgets('filter sheet choices and active chips at ${scale}x text', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(1170, 2532);
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sermonRepositoryProvider.overrideWithValue(
                FakePagedSermonRepository([archive]),
              ),
              sermonArchiveAutoHydrateProvider.overrideWithValue(false),
              cmsSermonsProvider.overrideWith(
                (ref) => Stream.value(const <Sermon>[]),
              ),
              videosProvider.overrideWith((ref) async => const <Sermon>[]),
              firestoreProvider.overrideWithValue(FakeFirebaseFirestore()),
              cacheServiceProvider.overrideWithValue(FakeCacheService()),
              audioPlayerServiceProvider.overrideWithValue(
                FakeAudioPlayerService(),
              ),
            ],
            child: MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: const MessagesScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final filters = find.byKey(const Key('messages-filters-button'));
        await tester.scrollUntilVisible(
          filters,
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tester.tap(filters);
        await tester.pumpAndSettle();
        for (final label in ['All years', '2025 (1)', 'Newest']) {
          await tester.ensureVisible(find.text(label));
          await tester.pumpAndSettle();
          expectUnclipped(tester, find.text(label), AnimatedContainer);
        }
        await tester.tap(find.text('2025 (1)'));
        await tester.tap(find.byKey(const Key('message-filters-apply')));
        await tester.pumpAndSettle();

        // The year chip (the header reads "All messages · 2025").
        expectUnclipped(tester, find.text('2025'), Container);
        expectUnclipped(tester, find.text('Filters \u00b7 1'), Container);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('the topic cards take their full height at 2x text', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sermonRepositoryProvider.overrideWithValue(
              FakePagedSermonRepository([archive]),
            ),
            sermonArchiveAutoHydrateProvider.overrideWithValue(false),
            cmsSermonsProvider.overrideWith(
              (ref) => Stream.value(const <Sermon>[]),
            ),
            videosProvider.overrideWith((ref) async => const <Sermon>[]),
            firestoreProvider.overrideWithValue(FakeFirebaseFirestore()),
            cacheServiceProvider.overrideWithValue(FakeCacheService()),
            audioPlayerServiceProvider.overrideWithValue(
              FakeAudioPlayerService(),
            ),
          ],
          child: MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: const MessagesScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('2 messages').first,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      final count = find.text('2 messages').first;
      final row = find
          .ancestor(of: count, matching: find.byType(SingleChildScrollView))
          .first;
      expect(
        tester.getRect(count).bottom,
        lessThanOrEqualTo(tester.getRect(row).bottom + 0.5),
      );
      expect(tester.takeException(), isNull);
    });
  });

  ProviderContainer containerOf(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(MessagesScreen)));

  /// A phone-sized view, so the sheet holds every section.
  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  /// A view tall enough that the first pages fit without scrolling, so only
  /// the Load more button (not the near-the-end scroll) adds rows.
  void tallView(WidgetTester tester) {
    tester.view.physicalSize = const Size(1000, 10000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Future<void> openFilters(WidgetTester tester) async {
    final button = find.byKey(const Key('messages-filters-button'));
    await tester.scrollUntilVisible(
      button,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  Future<void> tapInSheet(WidgetTester tester, Finder target) async {
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    await tester.tap(target);
    await tester.pump();
  }

  Future<void> apply(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('message-filters-apply')));
    await tester.pumpAndSettle();
  }

  group('filter sheet', () {
    final catalogue = [
      testSermon(
        's1',
        title: 'Faith one',
        series: 'Faith Walk',
        publishedAt: DateTime(2025, 3, 2),
      ),
      testSermon(
        's2',
        title: 'Faith two',
        series: 'Faith Walk',
        speaker: 'Grace Owusu',
        publishedAt: DateTime(2026, 2, 1),
      ),
      testSermon(
        's3',
        title: 'Kingdom one',
        series: 'Kingdom Life',
        speaker: 'Grace Owusu',
        publishedAt: DateTime(2026, 5, 1),
      ),
      testSermon('s4', title: 'Loose message', publishedAt: DateTime(2024, 6)),
    ];

    testWidgets('replaces the inline series, sort and year rows', (
      tester,
    ) async {
      phone(tester);
      await tester.pumpWidget(app(FakePagedSermonRepository([catalogue])));
      await tester.pumpAndSettle();

      expect(find.text('Series'), findsNothing);
      expect(find.text('All years'), findsNothing);
      expect(find.text('Oldest'), findsNothing);
      expect(find.text('Filters'), findsOneWidget);
      expect(find.text('Newest first'), findsOneWidget);

      await openFilters(tester);
      for (final section in ['Sort', 'Year', 'Speaker', 'Series']) {
        await tester.ensureVisible(find.text(section));
        expect(find.text(section), findsOneWidget);
      }
      expect(find.text('Grace Owusu (2)'), findsOneWidget);
      expect(find.text('David Antwi (2)'), findsOneWidget);
    });

    testWidgets('applies year and series, badges the count and shows '
        'removable chips', (tester) async {
      phone(tester);
      await tester.pumpWidget(app(FakePagedSermonRepository([catalogue])));
      await tester.pumpAndSettle();
      await openFilters(tester);

      await tapInSheet(tester, find.text('2026 (2)'));
      await tapInSheet(
        tester,
        find.byKey(const ValueKey('series-option-Faith Walk')),
      );
      // Nothing is applied until Apply.
      final c = containerOf(tester);
      expect(c.read(selectedArchiveYearProvider), isNull);
      await apply(tester);

      expect(c.read(selectedArchiveYearProvider), 2026);
      expect(c.read(selectedSeriesProvider), 'Faith Walk');
      expect(c.read(librarySermonsProvider).map((s) => s.id), ['s2']);
      expect(find.text('Filters \u00b7 2'), findsOneWidget);
      expect(find.text('Faith Walk \u00b7 2026'), findsOneWidget);
      expect(find.text('Clear all'), findsOneWidget);

      await tester.tap(find.text('2026'));
      await tester.pumpAndSettle();
      expect(c.read(selectedArchiveYearProvider), isNull);
      expect(find.text('Filters \u00b7 1'), findsOneWidget);
      expect(c.read(librarySermonsProvider).map((s) => s.id), ['s2', 's1']);

      await tester.tap(find.text('Faith Walk').last);
      await tester.pumpAndSettle();
      expect(c.read(selectedSeriesProvider), isNull);
      expect(find.text('Filters'), findsOneWidget);
    });

    testWidgets('filters by speaker and sorts oldest first', (tester) async {
      phone(tester);
      await tester.pumpWidget(app(FakePagedSermonRepository([catalogue])));
      await tester.pumpAndSettle();
      // The sort label opens the same sheet.
      await tester.scrollUntilVisible(
        find.byKey(const Key('messages-sort-button')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const Key('messages-sort-button')));
      await tester.pumpAndSettle();

      await tapInSheet(tester, find.text('Oldest'));
      await tapInSheet(tester, find.text('Grace Owusu (2)'));
      await apply(tester);

      final c = containerOf(tester);
      expect(c.read(sermonSortProvider), SermonSort.oldest);
      expect(c.read(selectedSpeakerProvider), 'Grace Owusu');
      expect(c.read(librarySermonsProvider).map((s) => s.id), ['s2', 's3']);
      expect(find.text('Oldest first'), findsOneWidget);
      expect(find.text('Filters \u00b7 1'), findsOneWidget);
      expect(find.text('Grace Owusu'), findsOneWidget);
    });

    testWidgets('Reset clears the draft; dismissing changes nothing', (
      tester,
    ) async {
      phone(tester);
      await tester.pumpWidget(app(FakePagedSermonRepository([catalogue])));
      await tester.pumpAndSettle();
      final c = containerOf(tester);
      c.read(selectedArchiveYearProvider.notifier).state = 2025;
      c.read(selectedSeriesProvider.notifier).state = 'Faith Walk';
      c.read(selectedSpeakerProvider.notifier).state = 'David Antwi';
      c.read(sermonSortProvider.notifier).state = SermonSort.oldest;
      await tester.pumpAndSettle();
      expect(find.text('Filters \u00b7 3'), findsOneWidget);

      // Dismissed without Apply: the draft is dropped.
      await openFilters(tester);
      await tapInSheet(tester, find.text('2024 (1)'));
      await tester.tapAt(const Offset(195, 20));
      await tester.pumpAndSettle();
      expect(c.read(selectedArchiveYearProvider), 2025);

      await openFilters(tester);
      await tester.tap(find.byKey(const Key('message-filters-reset')));
      await tester.pump();
      expect(c.read(selectedSeriesProvider), 'Faith Walk');
      await apply(tester);

      expect(c.read(selectedArchiveYearProvider), isNull);
      expect(c.read(selectedSeriesProvider), isNull);
      expect(c.read(selectedSpeakerProvider), isNull);
      expect(c.read(sermonSortProvider), SermonSort.newest);
      expect(find.text('Filters'), findsOneWidget);
      expect(find.text('Newest first'), findsOneWidget);
      expect(c.read(librarySermonsProvider), hasLength(4));
    });

    testWidgets('a long series list is searchable, accents ignored', (
      tester,
    ) async {
      phone(tester);
      final many = [
        for (var i = 1; i <= 10; i++)
          testSermon(
            'r$i',
            series: 'Series $i',
            publishedAt: DateTime(2026, 1, i),
          ),
        testSermon(
          'g',
          series: 'Grâce Abounding',
          publishedAt: DateTime(2026, 2),
        ),
      ];
      await tester.pumpWidget(app(FakePagedSermonRepository([many])));
      await tester.pumpAndSettle();
      await openFilters(tester);

      final search = find.byKey(const Key('message-filters-series-search'));
      await tester.ensureVisible(search);
      await tester.enterText(search, 'grace');
      await tester.pumpAndSettle();
      expect(find.text('Grâce Abounding'), findsOneWidget);
      expect(find.text('Series 3'), findsNothing);

      await tester.enterText(search, 'zzz');
      await tester.pumpAndSettle();
      expect(find.text('No series match "zzz"'), findsOneWidget);

      await tester.enterText(search, 'abound');
      await tester.pumpAndSettle();
      await tapInSheet(
        tester,
        find.byKey(const ValueKey('series-option-Grâce Abounding')),
      );
      await apply(tester);
      expect(
        containerOf(tester).read(librarySermonsProvider).map((s) => s.id),
        ['g'],
      );
    });
  });

  group('paging', () {
    final many = [
      for (var i = 1; i <= 75; i++)
        testSermon(
          'p$i',
          title: 'Paged message $i',
          publishedAt: DateTime(2025, 1, 1).add(Duration(days: i)),
        ),
    ];

    testWidgets('shows page 1 of 3; numbers, Next and Previous switch pages '
        'and bring the list back into view', (tester) async {
      tallView(tester);
      await tester.pumpWidget(app(FakePagedSermonRepository([many])));
      await tester.pumpAndSettle();
      final c = containerOf(tester);

      expect(c.read(libraryPageProvider), 0);
      expect(find.text('1–30 of 75 messages'), findsOneWidget);
      expect(find.text('Paged message 75'), findsOneWidget);
      expect(find.text('Paged message 45'), findsNothing);
      // Previous is disabled on the first page; the end marker only shows on
      // the last one.
      expect(
        tester
            .widget<OutlinedButton>(find.byKey(const Key('messages-page-prev')))
            .onPressed,
        isNull,
      );
      expect(find.text('That\'s all 75 messages'), findsNothing);

      await tester.tap(find.byKey(const Key('messages-page-next')));
      await tester.pumpAndSettle();
      expect(c.read(libraryPageProvider), 1);
      expect(find.text('31–60 of 75 messages'), findsOneWidget);
      expect(find.text('Paged message 45'), findsOneWidget);
      expect(find.text('Paged message 75'), findsNothing);

      await tester.tap(find.byKey(const Key('messages-page-3')));
      await tester.pumpAndSettle();
      expect(find.text('61–75 of 75 messages'), findsOneWidget);
      expect(find.text('Paged message 1'), findsOneWidget);
      expect(find.text('That\'s all 75 messages'), findsOneWidget);
      expect(
        tester
            .widget<OutlinedButton>(find.byKey(const Key('messages-page-next')))
            .onPressed,
        isNull,
      );

      await tester.tap(find.byKey(const Key('messages-page-prev')));
      await tester.pumpAndSettle();
      expect(find.text('31–60 of 75 messages'), findsOneWidget);
    });

    testWidgets('a filter or sort change goes back to page 1', (tester) async {
      tallView(tester);
      await tester.pumpWidget(app(FakePagedSermonRepository([many])));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('messages-page-next')));
      await tester.pumpAndSettle();
      expect(find.text('31–60 of 75 messages'), findsOneWidget);

      await openFilters(tester);
      await tapInSheet(tester, find.text('Oldest'));
      await apply(tester);
      expect(find.text('1–30 of 75 messages'), findsOneWidget);
      expect(find.text('Paged message 1'), findsOneWidget);
    });

    testWidgets('changing page from the bottom returns to the top of the '
        'list; scrolling does not load more pages by itself', (tester) async {
      await tester.pumpWidget(app(FakePagedSermonRepository([many])));
      await tester.pumpAndSettle();
      final c = containerOf(tester);
      final next = find.byKey(const Key('messages-page-next'));
      await tester.scrollUntilVisible(
        next,
        600,
        scrollable: find.byType(Scrollable).first,
        maxScrolls: 200,
      );
      await tester.pumpAndSettle();
      expect(c.read(libraryPageProvider), 0);

      await tester.tap(next);
      await tester.pumpAndSettle();
      expect(c.read(libraryPageProvider), 1);
      // The first row of the new page is on screen, not the bottom of it.
      expect(find.text('Paged message 45'), findsOneWidget);
      expect(find.byKey(const Key('messages-page-next')), findsNothing);
    });

    test('page numbers keep the ends and the neighbours, with gaps', () {
      // Exposed through the screen's pager for the widget tests above; the
      // rule itself is plain arithmetic.
      expect(messagesPageCount(0), 1);
      expect(messagesPageCount(30), 1);
      expect(messagesPageCount(31), 2);
      expect(messagesPageCount(1491), 50);
    });
  });

  group('search', () {
    final library = [
      for (var i = 1; i <= 45; i++)
        testSermon(
          'g$i',
          title: 'Walking in Grâce, part $i',
          publishedAt: DateTime(2025, 1, 1).add(Duration(days: i)),
        ),
      testSermon(
        'x',
        title: 'Unrelated message',
        speaker: 'Grace Owusu',
        publishedAt: DateTime(2026, 1, 1),
      ),
    ];

    testWidgets('every word matches anywhere, any case or accent, and '
        'results page like the list', (tester) async {
      tallView(tester);
      await tester.pumpWidget(
        app(FakePagedSermonRepository([library]), debounce: Duration.zero),
      );
      await tester.pumpAndSettle();
      final field = find.byType(TextField);

      await tester.enterText(field, 'GRACE walk');
      await tester.pumpAndSettle();
      expect(find.text('45 results for "GRACE walk"'), findsOneWidget);
      expect(find.text('1–30 of 45 results'), findsOneWidget);
      await tester.tap(find.byKey(const Key('messages-page-next')));
      await tester.pumpAndSettle();
      expect(find.text('31–45 of 45 results'), findsOneWidget);
      expect(find.text('That\'s all 45 results'), findsOneWidget);

      // A new query starts again at one page; mid-word fragments match.
      await tester.enterText(field, 'alking part');
      await tester.pumpAndSettle();
      expect(find.text('45 results for "alking part"'), findsOneWidget);
      expect(find.text('1–30 of 45 results'), findsOneWidget);

      // Speaker words count too, and every word must match.
      await tester.enterText(field, 'owusu unrelated');
      await tester.pumpAndSettle();
      expect(find.text('1 result for "owusu unrelated"'), findsOneWidget);
      expect(find.text('That\'s the only result'), findsOneWidget);

      await tester.enterText(field, 'grace zebra');
      await tester.pumpAndSettle();
      expect(find.text('No messages match "grace zebra"'), findsOneWidget);
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
