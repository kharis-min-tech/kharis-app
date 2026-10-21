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

import 'support/fake_audio_player_service.dart';
import 'support/fake_cache_service.dart';

Sermon _sermon(int n) => Sermon(
  id: 's$n',
  title: 'Message $n',
  speaker: 'Pastor $n',
  audioUrl: 'https://cdn.example/s$n.mp3',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  // ── Read the Bible row ──────────────────────────────────────────────────────

  group('Home Bible row', () {
    Future<void> pump(WidgetTester tester, Stream<DailyContent?> content) {
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
      return tester.pumpWidget(
        ProviderScope(
          key: UniqueKey(),
          overrides: [dailyContentProvider.overrideWith((ref) => content)],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
    }

    testWidgets("today's reading headlines the row and opens the reader", (
      tester,
    ) async {
      await pump(
        tester,
        Stream.value(
          const DailyContent(
            reading: DailyEntry(
              title: 'God so loved',
              reference: 'John 3:16-18',
              body: 'Read it slowly.',
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('John 3:16-18'), findsOneWidget);
      expect(find.text('God so loved'), findsOneWidget);
      expect(find.text('Read the Bible'), findsNothing);

      await tester.tap(find.byKey(const Key('home-bible-row')));
      await tester.pumpAndSettle();
      expect(find.text('reader'), findsOneWidget);
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

    final latest = [_sermon(1), _sermon(2), _sermon(3)];

    Future<void> pump(WidgetTester tester, UnfinishedPlay? unfinished) async {
      await tester.pumpWidget(
        ProviderScope(
          key: UniqueKey(),
          overrides: [
            audioPlayerServiceProvider.overrideWithValue(audio),
            cacheServiceProvider.overrideWithValue(FakeCacheService()),
            sermonsProvider.overrideWith((ref) async => latest),
            latestSermonsProvider.overrideWith((ref) => latest),
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

    testWidgets('the unfinished message leads with its progress and time '
        'left, and is not repeated', (tester) async {
      await pump(
        tester,
        UnfinishedPlay(
          sermon: _sermon(2),
          position: const Duration(minutes: 12),
          duration: const Duration(minutes: 30),
        ),
      );

      final continueCard = find.byKey(const Key('home-continue-card'));
      expect(continueCard, findsOneWidget);
      expect(
        tester.getTopLeft(continueCard).dx,
        lessThan(
          tester.getTopLeft(find.byKey(const Key('home-message-s1'))).dx,
        ),
      );
      expect(find.text('18 min left'), findsOneWidget);
      // Listed once: as the continue card, not again among the newest.
      expect(find.text('Message 2'), findsOneWidget);
      expect(find.byKey(const Key('home-message-s2')), findsNothing);
      expect(find.byKey(const Key('home-message-s3')), findsOneWidget);

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

    testWidgets('with nothing to resume the row is just the newest', (
      tester,
    ) async {
      await pump(tester, null);

      expect(find.byKey(const Key('home-continue-card')), findsNothing);
      for (final id in ['s1', 's2', 's3']) {
        expect(find.byKey(Key('home-message-$id')), findsOneWidget);
      }
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
