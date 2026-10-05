import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart'
    show PlayerState, YoutubeError, YoutubePlayerValue;

import 'package:kharis_app/core/utils/share_sermon.dart';
import 'package:kharis_app/features/home/presentation/widgets/continue_listening_card.dart';
import 'package:kharis_app/features/notes/data/note_repository.dart';
import 'package:kharis_app/features/notes/presentation/note_anchor.dart';
import 'package:kharis_app/features/notes/presentation/widgets/sermon_notes_sheet.dart';
import 'package:kharis_app/features/player/data/playback_history.dart';
import 'package:kharis_app/features/player/data/playback_queue.dart';
import 'package:kharis_app/features/player/presentation/screens/media_player_screen.dart';
import 'package:kharis_app/features/player/presentation/widgets/like_button.dart';
import 'package:kharis_app/features/player/presentation/widgets/player_actions.dart';
import 'package:kharis_app/features/player/presentation/widgets/player_controls.dart';
import 'package:kharis_app/features/playlists/data/playlist_repository.dart';
import 'package:kharis_app/features/playlists/presentation/screens/playlist_detail_screen.dart';
import 'package:kharis_app/features/playlists/providers/playlist_providers.dart';
import 'package:kharis_app/shared/models/sermon.dart';
import 'package:kharis_app/shared/providers/audio_provider.dart';
import 'package:kharis_app/shared/providers/cache_provider.dart';
import 'package:kharis_app/shared/providers/notes_provider.dart';
import 'package:kharis_app/shared/providers/sermon_provider.dart';

import 'support/fake_audio_player_service.dart';
import 'support/fake_cache_service.dart';

Sermon _sermon(int n, {bool audio = true, String? videoId, String? source}) =>
    Sermon(
      id: 's$n',
      title: 'Message $n',
      speaker: 'Pastor A',
      audioUrl: audio ? 'https://cdn.example/s$n.mp3' : '',
      videoId: videoId,
      source: source,
    );

final _library = [for (var n = 1; n <= 4; n++) _sermon(n)];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  late FakeAudioPlayerService audio;
  late FakeCacheService cache;

  setUp(() {
    audio = FakeAudioPlayerService();
    cache = FakeCacheService();
  });

  List<Override> overrides({
    List<Sermon> library = const [],
    List<Playlist> playlists = const [],
    Playlist? favorites,
  }) => [
    audioPlayerServiceProvider.overrideWithValue(audio),
    cacheServiceProvider.overrideWithValue(cache),
    sermonsProvider.overrideWith((ref) async => library),
    playlistsProvider.overrideWith((ref) => Stream.value(playlists)),
    favoritesProvider.overrideWith((ref) => Stream.value(favorites)),
    notesProvider.overrideWith((ref) => Stream.value(const <Note>[])),
  ];

  // ── Queue rules ─────────────────────────────────────────────────────────────

  group('PlaybackQueue (Spotify-style Previous / Next)', () {
    test('Previous restarts after 3 s, steps back within 3 s', () {
      final queue = PlaybackQueue.from(_library[1], _library);
      expect(
        queue.previousAction(const Duration(seconds: 4)),
        PreviousAction.restart,
      );
      expect(
        queue.previousAction(const Duration(seconds: 3)),
        PreviousAction.previousItem,
      );
      expect(queue.previous?.id, 's1');
      expect(queue.next?.id, 's3');
    });

    test('ends: nothing before the first, nothing after the last', () {
      final first = PlaybackQueue.from(_library.first, _library);
      expect(first.previousAction(Duration.zero), PreviousAction.none);
      expect(first.canGoPrevious(Duration.zero), isFalse);
      expect(
        first.previousAction(const Duration(seconds: 10)),
        PreviousAction.restart,
        reason: 'past 3 s the first message can still restart',
      );

      final last = PlaybackQueue.from(_library.last, _library);
      expect(last.hasNext, isFalse);
      expect(last.next, isNull);
    });

    test('keeps only playable, unique entries; unknown sermon plays alone', () {
      final videoOnly = _sermon(9, audio: false, videoId: 'v9');
      final queue = PlaybackQueue.from(_library[1], [
        _library[0],
        videoOnly,
        _library[1],
        _library[1],
        _library[2],
      ]);
      expect(queue.items.map((s) => s.id), ['s1', 's2', 's3']);
      expect(queue.index, 1);

      final alone = PlaybackQueue.from(_sermon(42), _library);
      expect(alone.items.map((s) => s.id), ['s42']);
      expect(alone.hasNext || alone.hasPrevious, isFalse);
    });
  });

  // ── Transport controls ──────────────────────────────────────────────────────

  group('PlayerControls Previous / Next', () {
    Future<void> pump(WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides(),
          child: const MaterialApp(
            home: Scaffold(body: Center(child: PlayerControls())),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('replace the ±seconds skips; Next walks the queue', (
      tester,
    ) async {
      await audio.play(_library.first, queue: _library);
      await pump(tester);

      expect(find.byIcon(Icons.replay_rounded), findsNothing);
      expect(find.byIcon(Icons.forward_rounded), findsNothing);

      // First message at 0:00: Previous is disabled.
      await tester.tap(find.byIcon(Icons.skip_previous_rounded));
      expect(audio.previousCalls, 0);

      await tester.tap(find.byIcon(Icons.skip_next_rounded));
      await tester.pump();
      expect(audio.nextCalls, 1);
      expect(audio.current?.id, 's2');

      // Second message within 3 s: Previous steps back.
      await tester.tap(find.byIcon(Icons.skip_previous_rounded));
      await tester.pump();
      expect(audio.current?.id, 's1');
    });

    testWidgets('Next is disabled on the last message', (tester) async {
      await audio.play(_library.last, queue: _library);
      await pump(tester);

      await tester.tap(find.byIcon(Icons.skip_next_rounded));
      expect(audio.nextCalls, 0);
    });

    testWidgets('past 3 s Previous restarts even the first message', (
      tester,
    ) async {
      await audio.play(_library.first, queue: _library);
      await pump(tester);
      audio.positionValue = const Duration(seconds: 30);
      audio.positions.add(const Duration(seconds: 30));
      await tester.pump();
      await tester.pump();

      await tester.tap(find.byIcon(Icons.skip_previous_rounded));
      await tester.pump();
      expect(audio.previousCalls, 1);
      expect(audio.seekCalls, [Duration.zero]);
      expect(audio.current?.id, 's1');
    });

    testWidgets('speed pill cycles and persists through the service', (
      tester,
    ) async {
      await pump(tester);
      await tester.tap(find.text('1×'));
      expect(audio.speedCalls, [1.25]);
    });
  });

  // ── Engine handoff and video position ───────────────────────────────────────

  group('audio <-> video handoff', () {
    final both = _sermon(5, videoId: 'vid5');
    late StreamController<Duration> videoPositions;

    setUp(() {
      videoPositions = StreamController<Duration>.broadcast();
      MediaPlayerScreen.debugDisableVideoEngine = true;
      MediaPlayerScreen.debugLastVideoStart = null;
      MediaPlayerScreen.debugVideoNoteBinding = NoteTimelineBinding(
        position: videoPositions.stream,
        seek: (_) async {},
      );
    });

    tearDown(() async {
      MediaPlayerScreen.debugDisableVideoEngine = false;
      MediaPlayerScreen.debugVideoNoteBinding = null;
      await videoPositions.close();
    });

    Future<void> open(
      WidgetTester tester,
      MediaMode mode, {
      Sermon? sermon,
      List<Sermon>? queue,
      List<Sermon> library = const [],
    }) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides(library: library),
          child: MaterialApp(
            home: MediaPlayerScreen(
              sermon: sermon ?? both,
              mode: mode,
              queue: queue,
            ),
          ),
        ),
      );
      await tester.pump();
    }

    Future<void> tapChip(WidgetTester tester, String label) async {
      await tester.ensureVisible(find.text(label));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
    }

    testWidgets('audio -> video starts the video at the live audio position', (
      tester,
    ) async {
      await audio.play(both);
      audio.positionValue = const Duration(minutes: 2);
      await open(tester, MediaMode.audio);

      await tapChip(tester, 'Video');

      expect(MediaPlayerScreen.debugLastVideoStart, const Duration(minutes: 2));
      expect(audio.stopCalls, 1, reason: 'audio fully released for video');
    });

    testWidgets('video -> audio hands the video position to play(startAt:)', (
      tester,
    ) async {
      await open(tester, MediaMode.video);
      videoPositions.add(const Duration(minutes: 5, seconds: 15));
      await tester.pump();

      await tapChip(tester, 'Audio');

      final call = audio.calls.last;
      expect(call.sermon.id, both.id);
      expect(call.startAt, const Duration(minutes: 5, seconds: 15));
      expect(audio.seekCalls, isEmpty, reason: 'no trailing seek after load');
    });

    testWidgets('video picks up the saved point when audio was not last', (
      tester,
    ) async {
      PlaybackHistory(cache).savePosition(both, const Duration(minutes: 7));

      await open(tester, MediaMode.video);

      expect(MediaPlayerScreen.debugLastVideoStart, const Duration(minutes: 7));
    });

    testWidgets('video position persists on close and restores on reopen', (
      tester,
    ) async {
      await open(tester, MediaMode.video);
      videoPositions.add(const Duration(seconds: 20));
      await tester.pump();
      videoPositions.add(const Duration(seconds: 23));
      await tester.pump();

      // Close the player: dispose flushes the last position.
      await tester.pumpWidget(const SizedBox());

      expect(cache.positions['yt_vid5'], 23000, reason: 'canonical key');
      expect(cache.positions['s5'], 23000, reason: 'audio key, shared point');
      expect(cache.getRecentlyPlayed(), ['s5'], reason: 'video plays count');
      expect(PlaybackHistory(cache).snapshots().map((s) => s.id), ['s5']);

      await open(tester, MediaMode.video);
      expect(
        MediaPlayerScreen.debugLastVideoStart,
        const Duration(seconds: 23),
      );
    });

    group('full-service video (videoStart 8:07)', () {
      // Like API sermon 101897: the mp3 starts 487 s into the service video.
      final service = _sermon(
        7,
        videoId: 'vid7',
      ).copyWith(videoStart: const Duration(seconds: 487));

      testWidgets('a fresh video opens where the message begins', (
        tester,
      ) async {
        await open(tester, MediaMode.video, sermon: service);
        expect(
          MediaPlayerScreen.debugLastVideoStart,
          const Duration(minutes: 8, seconds: 7),
        );
      });

      testWidgets('audio 10:00 -> video opens at 18:07', (tester) async {
        await audio.play(service);
        audio.positionValue = const Duration(minutes: 10);
        await open(tester, MediaMode.audio, sermon: service);

        await tapChip(tester, 'Video');

        expect(
          MediaPlayerScreen.debugLastVideoStart,
          const Duration(minutes: 18, seconds: 7),
        );
      });

      testWidgets('video 30:00 -> audio starts at 21:53', (tester) async {
        await open(tester, MediaMode.video, sermon: service);
        videoPositions.add(const Duration(minutes: 30));
        await tester.pump();

        await tapChip(tester, 'Audio');

        expect(
          audio.calls.last.startAt,
          const Duration(minutes: 21, seconds: 53),
        );
      });

      testWidgets(
        'video saves land on the audio timeline: resume, Continue listening '
        'and the next video open all agree',
        (tester) async {
          final timed = service.copyWith(duration: const Duration(minutes: 40));
          await open(tester, MediaMode.video, sermon: timed);
          videoPositions.add(const Duration(minutes: 30));
          await tester.pump();
          await tester.pumpWidget(const SizedBox());

          const audioPoint = Duration(minutes: 21, seconds: 53);
          final history = PlaybackHistory(cache);
          expect(cache.positions['s7'], audioPoint.inMilliseconds);
          expect(cache.positions['yt_vid7'], audioPoint.inMilliseconds);
          expect(history.resumePoint(timed), audioPoint);
          final unfinished = history.lastUnfinished();
          expect(unfinished?.position, audioPoint);
          expect(unfinished?.duration, const Duration(minutes: 40));

          await open(tester, MediaMode.video, sermon: timed);
          expect(
            MediaPlayerScreen.debugLastVideoStart,
            const Duration(minutes: 30),
          );
        },
      );

      testWidgets('a note taken in video is stamped on the audio timeline', (
        tester,
      ) async {
        await open(tester, MediaMode.video, sermon: service);
        final binding = tester
            .widget<PlayerActions>(find.byType(PlayerActions))
            .timeline!;
        final stamped = binding.position!.first;
        videoPositions.add(const Duration(minutes: 30));
        expect(await stamped, const Duration(minutes: 21, seconds: 53));
      });
    });

    testWidgets('a finished video is not written back by a later save', (
      tester,
    ) async {
      final values = StreamController<YoutubePlayerValue>.broadcast();
      MediaPlayerScreen.debugVideoValues = values.stream;
      addTearDown(() async {
        MediaPlayerScreen.debugVideoValues = null;
        await values.close();
      });
      // duration unknown (a CMS doc whose length fetch failed): the end
      // guard cannot catch a written-back final tick.
      await open(tester, MediaMode.video);
      videoPositions.add(const Duration(minutes: 39, seconds: 50));
      await tester.pump();
      values.add(YoutubePlayerValue(playerState: PlayerState.ended));
      await tester.pump();

      // Close: dispose flushes the video position.
      await tester.pumpWidget(const SizedBox());

      expect(cache.positions['s5'], 0);
      expect(PlaybackHistory(cache).lastUnfinished(), isNull);
    });

    testWidgets('Video stays tappable while the audio load is still running', (
      tester,
    ) async {
      final load = Completer<void>();
      audio.playGate = load.future;
      addTearDown(load.complete);
      await open(tester, MediaMode.video);
      expect(audio.stopCalls, 1);

      await tapChip(tester, 'Audio');
      expect(audio.calls, hasLength(1), reason: 'audio load in flight');
      MediaPlayerScreen.debugLastVideoStart = null;

      await tapChip(tester, 'Video');

      expect(audio.stopCalls, 2, reason: 'switched back to video');
      expect(MediaPlayerScreen.debugLastVideoStart, isNotNull);
    });

    testWidgets(
      'a video variant switched to its audio twin keeps the launch queue',
      (tester) async {
        final twin = _sermon(2, videoId: 'v2');
        const variant = Sermon(
          id: 'yt_v2',
          title: 'Message 2',
          speaker: 'Pastor A',
          audioUrl: '',
          videoId: 'v2',
          source: 'youtube',
        );
        final videoOnly = _sermon(9, audio: false, videoId: 'v9');
        await open(
          tester,
          MediaMode.video,
          sermon: variant,
          queue: [_library[0], variant, videoOnly, _library[2]],
          library: [_library[0], twin, _library[2]],
        );
        await tester.pump();

        await tapChip(tester, 'Audio');

        final call = audio.calls.last;
        expect(call.sermon.id, 's2');
        expect(call.queue?.map((s) => s.id), ['s1', 's2', 's9', 's3']);
        expect(audio.queue?.previous?.id, 's1');
        expect(audio.queue?.next?.id, 's3');

        // Back to video and audio again: the video-only entry survived the
        // audio engine's filtered queue.
        await tapChip(tester, 'Video');
        await tapChip(tester, 'Audio');
        expect(audio.calls.last.queue?.map((s) => s.id), [
          's1',
          's2',
          's9',
          's3',
        ]);
      },
    );
  });

  group('video errors', () {
    final both = _sermon(5, videoId: 'vid5');
    late StreamController<YoutubePlayerValue> values;

    setUp(() {
      values = StreamController<YoutubePlayerValue>.broadcast();
      MediaPlayerScreen.debugDisableVideoEngine = true;
      MediaPlayerScreen.debugVideoValues = values.stream;
    });

    tearDown(() async {
      MediaPlayerScreen.debugDisableVideoEngine = false;
      MediaPlayerScreen.debugVideoValues = null;
      await values.close();
    });

    Future<void> open(WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides(),
          child: MaterialApp(
            home: MediaPlayerScreen(sermon: both, mode: MediaMode.video),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('an embed error offers Listen instead and Open in YouTube', (
      tester,
    ) async {
      await open(tester);
      values.add(YoutubePlayerValue(error: YoutubeError.notEmbeddable));
      // One pump delivers the event, the next paints the banner.
      await tester.pump();
      await tester.pump();

      expect(
        find.text('This video can\u2019t be played inside the app.'),
        findsOneWidget,
      );
      expect(find.text('Open in YouTube'), findsOneWidget);

      await tester.ensureVisible(find.text('Listen instead'));
      await tester.tap(find.text('Listen instead'));
      await tester.pumpAndSettle();

      expect(audio.calls.single.sermon.id, both.id);
      expect(find.text('Open in YouTube'), findsNothing, reason: 'audio mode');
    });

    testWidgets('a video stuck unstarted for 15 s gets the banner', (
      tester,
    ) async {
      await open(tester);
      values.add(YoutubePlayerValue(playerState: PlayerState.unStarted));
      await tester.pump(const Duration(seconds: 14));
      expect(
        find.text('This video is taking too long to start.'),
        findsNothing,
      );

      await tester.pump(const Duration(seconds: 2));
      expect(
        find.text('This video is taking too long to start.'),
        findsOneWidget,
      );
    });

    testWidgets('a video that starts never trips the watchdog', (tester) async {
      await open(tester);
      values.add(YoutubePlayerValue(playerState: PlayerState.playing));
      await tester.pump(const Duration(seconds: 20));
      expect(
        find.text('This video is taking too long to start.'),
        findsNothing,
      );
    });
  });

  // ── Share ───────────────────────────────────────────────────────────────────

  // Shared links lead into the Kharis app (full contract: app_links_test).
  group('share links', () {
    const origin = 'https://kharis-app-47c49.web.app';

    test('audio-only API message links its own id', () {
      final s = _sermon(2611, source: 'kharis-api');
      expect(sermonShareLink(s).toString(), '$origin/m/s2611');
    });

    test('watching links the canonical id at the current second', () {
      final s = _sermon(1, videoId: 'abc123', source: 'kharis-api');
      expect(
        sermonShareLink(
          s,
          asVideo: true,
          position: const Duration(seconds: 95),
        ).toString(),
        '$origin/m/yt_abc123?t=95&v=1',
      );
      expect(
        sermonShareLink(s).toString(),
        '$origin/m/yt_abc123',
        reason: 'listening shares the same message link',
      );
    });

    test('video-only feed message: Kharis link; text has no em dash', () {
      final s = _sermon(3, audio: false, videoId: 'xyz789', source: 'youtube');
      expect(sermonShareLink(s).toString(), '$origin/m/yt_xyz789');
      final text = sermonShareText(s);
      expect(
        text,
        'Message 3\nPastor A\nOpen in the Kharis app: $origin/m/yt_xyz789',
      );
      expect(text.contains('\u2014'), isFalse);
    });
  });

  // ── Playlists ───────────────────────────────────────────────────────────────

  group('playlists', () {
    final playlist = Playlist(
      id: 'p1',
      name: 'Sunday drive',
      sermonIds: const ['s3', 's1', 's2'],
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

    setUp(() => MediaPlayerScreen.debugDisableVideoEngine = true);
    tearDown(() => MediaPlayerScreen.debugDisableVideoEngine = false);

    testWidgets('Play all plays the playlist as the queue, in its order', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides(library: _library, playlists: [playlist]),
            playlistResolutionProvider.overrideWith(
              (ref, id) => PlaylistResolution(
                sermons: [_library[2], _library[0], _library[1]],
              ),
            ),
          ],
          child: const MaterialApp(
            home: PlaylistDetailScreen(playlistId: 'p1'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Play all'));
      await tester.pumpAndSettle();

      final call = audio.calls.single;
      expect(call.sermon.id, 's3');
      expect(call.queue?.map((s) => s.id), ['s3', 's1', 's2']);
      expect(audio.queue?.next?.id, 's1', reason: 'Next continues the list');
    });

    test('the heart files messages into one Favorites doc', () async {
      final db = FakeFirebaseFirestore();
      final repo = PlaylistRepository(db, uid: 'm1');
      final doc = db
          .collection('users')
          .doc('m1')
          .collection('playlists')
          .doc(PlaylistRepository.favoritesId);

      repo.setLiked('s1', liked: true, favoritesExist: false);
      await pumpEventQueue();
      expect((await doc.get()).data()?['name'], 'Favorites');
      expect((await doc.get()).data()?['sermonIds'], ['s1']);

      repo.setLiked('s2', liked: true, favoritesExist: true);
      await pumpEventQueue();
      expect((await doc.get()).data()?['sermonIds'], ['s1', 's2']);

      repo.setLiked('s1', liked: false, favoritesExist: true);
      await pumpEventQueue();
      expect((await doc.get()).data()?['sermonIds'], ['s2']);
    });

    test(
      'a first like on a lagging snapshot adds to the stored list instead of '
      'replacing it; unlike clears every id the message was liked under',
      () async {
        final db = FakeFirebaseFirestore();
        final repo = PlaylistRepository(db, uid: 'm1');
        final doc = db
            .collection('users')
            .doc('m1')
            .collection('playlists')
            .doc(PlaylistRepository.favoritesId);
        final now = Timestamp.now();
        await doc.set({
          'name': 'Favorites',
          'sermonIds': ['s1', 's2'],
          'createdAt': now,
          'updatedAt': now,
        });

        repo.setLiked('yt_v3', liked: true, favoritesExist: false);
        await pumpEventQueue();
        expect((await doc.get()).data()?['sermonIds'], ['s1', 's2', 'yt_v3']);

        repo.setLiked(
          'yt_v1',
          liked: false,
          favoritesExist: true,
          aliases: ['s1'],
        );
        await pumpEventQueue();
        expect((await doc.get()).data()?['sermonIds'], ['s2', 'yt_v3']);
      },
    );

    testWidgets(
      'the heart waits for the Favorites snapshot, then likes the message '
      'under its canonical key',
      (tester) async {
        final db = FakeFirebaseFirestore();
        final repo = PlaylistRepository(db, uid: 'm1');
        final doc = db
            .collection('users')
            .doc('m1')
            .collection('playlists')
            .doc(PlaylistRepository.favoritesId);
        final liked = Playlist(
          id: PlaylistRepository.favoritesId,
          name: 'Favorites',
          sermonIds: const ['s1'],
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        );
        await tester.runAsync(
          () => doc.set({
            'name': liked.name,
            'sermonIds': liked.sermonIds,
            'createdAt': Timestamp.now(),
            'updatedAt': Timestamp.now(),
          }),
        );
        // Cold start: the stream has not delivered its first snapshot.
        final snapshots = StreamController<Playlist?>();
        addTearDown(snapshots.close);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              playlistRepositoryProvider.overrideWithValue(repo),
              favoritesProvider.overrideWith((ref) => snapshots.stream),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: LikeButton(sermon: _sermon(2, videoId: 'v2')),
              ),
            ),
          ),
        );

        await tester.tap(find.byIcon(Icons.favorite_border_rounded));
        await tester.pump();
        await tester.runAsync(pumpEventQueue);
        expect(
          find.text(
            'Your Favourites are still loading. Try again in a moment.',
          ),
          findsOneWidget,
        );
        final untouched = await tester.runAsync(doc.get);
        expect(untouched?.data()?['sermonIds'], ['s1']);

        snapshots.add(liked);
        await tester.pump();
        await tester.tap(find.byIcon(Icons.favorite_border_rounded));
        await tester.runAsync(pumpEventQueue);
        final after = await tester.runAsync(doc.get);
        expect(after?.data()?['sermonIds'], ['s1', 'yt_v2']);
      },
    );

    testWidgets('the heart stays filled across the audio <-> video swap', (
      tester,
    ) async {
      // Liked while watching the yt_ variant; the toggle swaps in the twin.
      final liked = Playlist(
        id: PlaylistRepository.favoritesId,
        name: 'Favorites',
        sermonIds: const ['yt_v2'],
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides(favorites: liked),
          child: MaterialApp(
            home: Scaffold(
              body: LikeButton(sermon: _sermon(2, videoId: 'v2')),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
    });
  });

  // ── Notes ───────────────────────────────────────────────────────────────────

  group('note anchors', () {
    testWidgets(
      'an anchor plays its message from the note time, resolving it from '
      'recent snapshots before the archive loads',
      (tester) async {
        final target = _sermon(8);
        PlaybackHistory(cache).recordPlay(target);
        late WidgetRef captured;
        await tester.pumpWidget(
          ProviderScope(
            overrides: overrides(),
            child: MaterialApp(
              home: Consumer(
                builder: (context, ref, _) {
                  captured = ref;
                  return const SizedBox();
                },
              ),
            ),
          ),
        );

        final result = await NoteAnchor.play(
          captured,
          Note(
            id: 'n1',
            sermonId: 's8',
            sermonTitle: 'Message 8',
            positionMs: 754000,
            body: 'Hold this',
            createdAt: DateTime(2026),
            updatedAt: DateTime(2026),
          ),
        );

        expect(result, NoteAnchorResult.started);
        expect(audio.calls.single.sermon.id, 's8');
        expect(
          audio.calls.single.startAt,
          const Duration(minutes: 12, seconds: 34),
        );
      },
    );
  });

  group('notes sheet', () {
    testWidgets(
      'swiping a note away deletes it without the late stream tripping the '
      'Dismissible assertion',
      (tester) async {
        final notes = _RecordingNotes();
        final sermon = _sermon(6);
        final note = Note(
          id: 'n1',
          sermonId: 's6',
          sermonTitle: 'Message 6',
          positionMs: 750000,
          body: 'Grace is enough',
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              ...overrides(),
              // A stream that has not caught up with the delete yet.
              notesProvider.overrideWith((ref) => Stream.value([note])),
              notesRepositoryProvider.overrideWithValue(notes),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: Builder(
                  builder: (context) => TextButton(
                    onPressed: () => SermonNotesSheet.show(context, sermon),
                    child: const Text('notes'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('notes'));
        await tester.pumpAndSettle();
        expect(find.text('Grace is enough'), findsOneWidget);
        expect(find.text('12:30'), findsOneWidget, reason: 'anchor listed');

        await tester.drag(find.text('Grace is enough'), const Offset(-600, 0));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(notes.deleted, ['n1']);
        expect(find.text('Grace is enough'), findsNothing);
      },
    );
  });

  // ── Continue listening ──────────────────────────────────────────────────────

  group('Continue listening', () {
    test('one Recently played row per message across its variants', () {
      final api = _sermon(7, videoId: 'v7');
      const variant = Sermon(
        id: 'yt_v7',
        title: 'Message 7',
        speaker: 'Pastor A',
        audioUrl: '',
        videoId: 'v7',
        source: 'youtube',
      );
      final history = PlaybackHistory(cache)
        ..recordPlay(api)
        ..recordPlay(_sermon(1))
        ..recordPlay(variant);
      expect(cache.getRecentlyPlayed(), ['yt_v7', 's1']);
      expect(history.snapshots().map((s) => s.id), ['yt_v7', 's1']);

      history.recordPlay(api);
      expect(cache.getRecentlyPlayed(), ['s7', 's1']);
      expect(history.snapshots().map((s) => s.id), ['s7', 's1']);
    });

    test('the live stream is never recorded, saved or resumed', () {
      const live = Sermon(
        id: 'live',
        title: 'Live Stream',
        speaker: 'Kharis Church',
        audioUrl: '',
        videoId: 'liveA',
        source: 'youtube',
      );
      final history = PlaybackHistory(cache)
        ..recordPlay(live)
        ..savePosition(live, const Duration(minutes: 20));
      expect(cache.getRecentlyPlayed(), isEmpty);
      expect(history.snapshots(), isEmpty);
      expect(cache.positions, isEmpty);

      // A point left under the fixed id by an older build must not open the
      // next stream mid-way.
      cache.cachePlaybackPosition(
        'live',
        const Duration(minutes: 9).inMilliseconds,
      );
      expect(history.resumePoint(live.copyWith(videoId: 'liveB')), isNull);
      expect(history.lastUnfinished(), isNull);
    });

    test('picks the newest unfinished message, skipping finished ones', () {
      final history = PlaybackHistory(cache);
      final older = _sermon(1).copyWith(duration: const Duration(minutes: 40));
      final finished = _sermon(
        2,
      ).copyWith(duration: const Duration(minutes: 40));
      history
        ..recordPlay(older)
        ..savePosition(older, const Duration(minutes: 10))
        ..recordPlay(finished)
        ..savePosition(finished, const Duration(minutes: 39, seconds: 50));

      final unfinished = history.lastUnfinished();
      expect(unfinished?.sermon.id, 's1');
      expect(unfinished?.progress, 0.25);
    });

    testWidgets('shows progress and resumes; hidden when nothing to resume', (
      tester,
    ) async {
      MediaPlayerScreen.debugDisableVideoEngine = true;
      addTearDown(() => MediaPlayerScreen.debugDisableVideoEngine = false);

      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides(),
          child: const MaterialApp(
            home: Scaffold(body: ContinueListeningCard()),
          ),
        ),
      );
      expect(find.text('CONTINUE LISTENING'), findsNothing);

      final s = _sermon(3).copyWith(duration: const Duration(minutes: 30));
      PlaybackHistory(cache)
        ..recordPlay(s)
        ..savePosition(s, const Duration(minutes: 12));
      await tester.pumpWidget(
        ProviderScope(
          key: UniqueKey(),
          overrides: overrides(),
          child: const MaterialApp(
            home: Scaffold(body: ContinueListeningCard()),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Message 3'), findsOneWidget);
      expect(find.text('18 min left'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);

      await tester.tap(find.text('Message 3'));
      await tester.pumpAndSettle();
      expect(audio.calls.single.sermon.id, 's3');
    });
  });
}

/// Records deletes; never touches a store, so the notes stream stays stale.
class _RecordingNotes implements NoteRepository {
  final List<String> deleted = [];

  @override
  Future<void> delete(String id) async => deleted.add(id);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
