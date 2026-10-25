import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:kharis_app/features/home/data/daily_content_repository.dart';
import 'package:kharis_app/features/home/data/news_repository.dart';
import 'package:kharis_app/features/home/presentation/widgets/continue_listening_card.dart';
import 'package:kharis_app/features/home/presentation/widgets/home_bible_row.dart';
import 'package:kharis_app/features/home/presentation/widgets/latest_announcement_card.dart';
import 'package:kharis_app/features/home/presentation/widgets/latest_messages_row.dart';
import 'package:kharis_app/features/messages/data/kharis_api_sermon_repository.dart';
import 'package:kharis_app/features/notes/data/note_repository.dart';
import 'package:kharis_app/features/player/data/playback_history.dart';
import 'package:kharis_app/features/player/presentation/screens/media_player_screen.dart';
import 'package:kharis_app/features/playlists/data/playlist_repository.dart';
import 'package:kharis_app/features/playlists/providers/playlist_providers.dart';
import 'package:kharis_app/shared/models/sermon.dart';
import 'package:kharis_app/shared/providers/audio_provider.dart';
import 'package:kharis_app/shared/providers/cache_provider.dart';
import 'package:kharis_app/shared/providers/notes_provider.dart';
import 'package:kharis_app/shared/providers/notification_feed_provider.dart';
import 'package:kharis_app/shared/providers/sermon_provider.dart';

import 'support/bible_overrides.dart';
import 'support/fake_audio_player_service.dart';
import 'support/fake_cache_service.dart';

/// Message n, published on n October 2026.
Sermon _sermon(int n) => Sermon(
  id: 's$n',
  title: 'Message $n',
  speaker: 'Pastor $n',
  audioUrl: 'https://cdn.example/s$n.mp3',
  publishedAt: DateTime(2026, 10, n),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  // ── Read the Bible row ──────────────────────────────────────────────────────

  group('Home Bible row', () {
    Future<void> pump(
      WidgetTester tester,
      Stream<DailyContent?> content,
    ) async {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const Scaffold(body: HomeBibleRow()),
          ),
          GoRoute(
            path: '/reading',
            builder: (_, _) => const Scaffold(body: Text('reader')),
          ),
          GoRoute(
            path: '/bible',
            builder: (_, _) => const Scaffold(body: Text('bible books')),
          ),
        ],
      );
      final bible = await bibleRowOverrides();
      await tester.pumpWidget(
        ProviderScope(
          key: UniqueKey(),
          overrides: [
            ...bible,
            dailyContentProvider.overrideWith((ref) => content),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
    }

    Stream<DailyContent?> reading(String reference) => Stream.value(
      DailyContent(
        reading: DailyEntry(
          title: 'God so loved',
          reference: reference,
          body: 'Read it slowly.',
        ),
      ),
    );

    testWidgets("today's chapter headlines the row and opens the reader", (
      tester,
    ) async {
      await pump(tester, reading('John 3:16-18'));
      await tester.pump();

      expect(find.text("Today's reading"), findsOneWidget);
      expect(find.text('John 3'), findsOneWidget);
      expect(find.text('John 3:16-18'), findsNothing);
      expect(find.text('Read the Bible'), findsNothing);

      await tester.tap(find.byKey(const Key('home-bible-row-open')));
      await tester.pumpAndSettle();
      expect(find.text('reader'), findsOneWidget);
    });

    testWidgets('several passages name each chapter once, in order', (
      tester,
    ) async {
      await pump(tester, reading('Romans 8:1-11; Romans 8:28; John 3:16'));
      await tester.pump();

      expect(find.text('Romans 8 \u00b7 John 3'), findsOneWidget);
    });

    testWidgets("a reference that names no chapter shows the Studio's text", (
      tester,
    ) async {
      await pump(tester, reading('A word for the week'));
      await tester.pump();

      expect(find.text('A word for the week'), findsOneWidget);
    });

    testWidgets('Whole Bible opens the book list, not the reader', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pump(tester, reading('John 3:16'));
      await tester.pump();

      final wholeBible = find.byKey(const Key('home-bible-row-whole-bible'));
      expect(find.text('Whole Bible'), findsOneWidget);
      expect(find.bySemanticsLabel('Open the whole Bible'), findsOneWidget);
      final size = tester.getSize(wholeBible);
      expect(size.height, greaterThanOrEqualTo(44));
      expect(size.width, greaterThanOrEqualTo(44));

      await tester.tap(wholeBible);
      await tester.pumpAndSettle();
      expect(find.text('bible books'), findsOneWidget);
      expect(find.text('reader'), findsNothing);
      semantics.dispose();
    });

    testWidgets('without a reading it offers the whole Bible', (tester) async {
      for (final content in [
        Stream<DailyContent?>.value(null),
        Stream<DailyContent?>.error(Exception('offline')),
        Stream<DailyContent?>.value(
          const DailyContent(prayer: DailyEntry(title: 'A morning prayer')),
        ),
      ]) {
        await pump(tester, content);
        await tester.pump();

        expect(find.text('Read the Bible'), findsOneWidget);
        expect(
          find.text('Every book and chapter, in your translation.'),
          findsOneWidget,
        );
        expect(find.text('Whole Bible'), findsNothing);

        await tester.tap(find.byKey(const Key('home-bible-row')));
        await tester.pumpAndSettle();
        expect(find.text('bible books'), findsOneWidget);
      }
    });
  });

  // ── Latest messages, led by Continue listening ──────────────────────────────

  group('Latest messages row', () {
    late FakeAudioPlayerService audio;

    setUp(() {
      audio = FakeAudioPlayerService();
      MediaPlayerScreen.debugDisableVideoEngine = true;
    });
    tearDown(() => MediaPlayerScreen.debugDisableVideoEngine = false);

    // Ten messages, oldest first: Home shows the eight newest.
    final library = [for (var n = 1; n <= 10; n++) _sermon(n)];
    const newest = ['s10', 's9', 's8', 's7', 's6', 's5', 's4', 's3'];

    Future<void> pump(WidgetTester tester, UnfinishedPlay? unfinished) async {
      await tester.pumpWidget(
        ProviderScope(
          key: UniqueKey(),
          overrides: [
            audioPlayerServiceProvider.overrideWithValue(audio),
            cacheServiceProvider.overrideWithValue(FakeCacheService()),
            sermonsProvider.overrideWith((ref) async => library),
            continueListeningProvider.overrideWith((ref) => unfinished),
            playlistsProvider.overrideWith(
              (ref) => Stream.value(const <Playlist>[]),
            ),
            favoritesProvider.overrideWith((ref) => Stream.value(null)),
            notesProvider.overrideWith((ref) => Stream.value(const <Note>[])),
          ],
          child: const MaterialApp(home: Scaffold(body: LatestMessagesRow())),
        ),
      );
      await tester.pump();
    }

    /// The row's message tiles, left to right.
    List<String> tileIds(WidgetTester tester) {
      final tiles =
          tester
              .widgetList<GestureDetector>(find.byType(GestureDetector))
              .map((g) => g.key)
              .whereType<ValueKey<String>>()
              .where((k) => k.value.startsWith('home-message-'))
              .toList()
            ..sort(
              (a, b) => tester
                  .getTopLeft(find.byKey(a))
                  .dx
                  .compareTo(tester.getTopLeft(find.byKey(b)).dx),
            );
      return [for (final k in tiles) k.value.substring('home-message-'.length)];
    }

    testWidgets('the unfinished message leads once, with its progress and '
        'time left, and the eight newest of the rest follow', (tester) async {
      await tester.binding.setSurfaceSize(const Size(2400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await pump(
        tester,
        UnfinishedPlay(
          sermon: _sermon(9),
          position: const Duration(minutes: 12),
          duration: const Duration(minutes: 30),
        ),
      );

      final continueCard = find.byKey(const Key('home-continue-card'));
      expect(continueCard, findsOneWidget);
      expect(
        tester.getTopLeft(continueCard).dx,
        lessThan(
          tester.getTopLeft(find.byKey(const Key('home-message-s10'))).dx,
        ),
      );
      expect(find.text('18 min left'), findsOneWidget);
      // Listed once: as the continue card, not again among the newest, which
      // reach one further back instead.
      expect(find.text('Message 9'), findsOneWidget);
      expect(find.byKey(const Key('home-message-s9')), findsNothing);
      expect(tileIds(tester), [
        's10',
        's8',
        's7',
        's6',
        's5',
        's4',
        's3',
        's2',
      ]);

      // 12 of 30 minutes listened: the bar is filled two fifths of the way.
      final bar = find.byKey(const Key('home-continue-progress'));
      final fill = find.descendant(
        of: bar,
        matching: find.byType(FractionallySizedBox),
      );
      expect(tester.getSize(bar).height, 3);
      expect(
        tester.getSize(fill).width,
        moreOrLessEquals(tester.getSize(bar).width * 0.4, epsilon: 0.5),
      );
    });

    testWidgets('tapping the continue card resumes that message', (
      tester,
    ) async {
      await pump(
        tester,
        UnfinishedPlay(
          sermon: _sermon(2),
          position: const Duration(minutes: 12),
          duration: const Duration(minutes: 30),
        ),
      );

      await tester.tap(find.byKey(const Key('home-continue-card')));
      await tester.pumpAndSettle();
      expect(audio.calls.single.sermon.id, 's2');
    });

    testWidgets('with nothing to resume the row is the eight newest, newest '
        'first, each dated', (tester) async {
      await tester.binding.setSurfaceSize(const Size(2400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await pump(tester, null);

      expect(find.byKey(const Key('home-continue-card')), findsNothing);
      expect(tileIds(tester), newest);
      expect(find.text('10 Oct'), findsOneWidget);
      expect(find.text('3 Oct'), findsOneWidget);
      expect(find.text('2 Oct'), findsNothing);
      // The date sits under the speaker.
      expect(
        tester.getTopLeft(find.text('10 Oct')).dy,
        greaterThan(tester.getTopLeft(find.text('Pastor 10')).dy),
      );
    });
  });

  group('Message artwork', () {
    test("the sermon host's default image counts as no artwork", () {
      expect(
        biggerSermonImage(
          'https://cdn.sermons.example/images/Kharis_resized_H6Mr63b.jpeg'
          '?width=256',
        ),
        isNull,
      );
      expect(
        biggerSermonImage(
          'https://cdn.sermons.example/a/own-art.jpg?width=256',
        ),
        'https://cdn.sermons.example/a/own-art.jpg?width=512',
      );
    });
  });

  // ── Latest announcement ─────────────────────────────────────────────────────

  group('Latest announcement card', () {
    Future<void> pump(
      WidgetTester tester,
      AsyncValue<List<NewsItem>> news,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          key: UniqueKey(),
          overrides: [campusNewsProvider.overrideWithValue(news)],
          child: const MaterialApp(
            home: Scaffold(body: LatestAnnouncementCard()),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('shows only the newest announcement and opens it', (
      tester,
    ) async {
      await pump(
        tester,
        AsyncValue.data([
          NewsItem(
            id: 'n2',
            title: 'Harvest Sunday',
            type: 'Announcement',
            publishedAt: DateTime(2026, 10, 12),
            body: 'Bring a friend this Sunday.',
          ),
          NewsItem(
            id: 'n1',
            title: 'Choir rehearsal moved',
            type: 'Notice',
            publishedAt: DateTime(2026, 10, 3),
          ),
        ]),
      );

      expect(find.byKey(const Key('home-announcement-latest')), findsOneWidget);
      expect(find.text('Harvest Sunday'), findsOneWidget);
      expect(find.text('12 Oct'), findsOneWidget);
      expect(find.text('Choir rehearsal moved'), findsNothing);

      await tester.tap(find.byKey(const Key('home-announcement-latest')));
      await tester.pumpAndSettle();
      expect(find.text('Bring a friend this Sunday.'), findsOneWidget);
    });

    testWidgets('collapses when nothing is published, or while loading', (
      tester,
    ) async {
      for (final news in const <AsyncValue<List<NewsItem>>>[
        AsyncValue.data(<NewsItem>[]),
        AsyncValue.loading(),
      ]) {
        await pump(tester, news);
        expect(find.byKey(const Key('home-announcement-latest')), findsNothing);
      }
    });
  });
}
