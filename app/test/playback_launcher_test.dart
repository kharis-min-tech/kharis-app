import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kharis_app/features/playlists/providers/playlist_providers.dart';
import 'package:kharis_app/features/player/presentation/playback_launcher.dart';
import 'package:kharis_app/features/player/presentation/screens/media_player_screen.dart';
import 'package:kharis_app/shared/models/sermon.dart';
import 'package:kharis_app/shared/providers/audio_provider.dart';
import 'package:kharis_app/shared/providers/cache_provider.dart';
import 'package:kharis_app/shared/providers/sermon_provider.dart';

import 'support/fake_audio_player_service.dart';
import 'support/fake_cache_service.dart';

Sermon _sermon({String audioUrl = '', String? videoId}) => Sermon(
  id: 's1',
  title: 'Walking in Faith',
  speaker: 'Pastor A',
  audioUrl: audioUrl,
  videoId: videoId,
);

Widget _harness(
  FakeAudioPlayerService service,
  Sermon sermon, {
  int tapsPerPress = 1,
  List<Sermon> library = const <Sermon>[],
  List<Sermon>? queue,
  MediaMode? mode,
}) {
  return ProviderScope(
    overrides: [
      audioPlayerServiceProvider.overrideWithValue(service),
      cacheServiceProvider.overrideWithValue(FakeCacheService()),
      // Hermetic: the default queue reads the library.
      sermonsProvider.overrideWith((ref) async => library),
      // The like button reads the member's Favorites; keep it offline.
      favoritesProvider.overrideWith((ref) => Stream.value(null)),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: Consumer(
          builder: (context, ref, _) => TextButton(
            onPressed: () {
              // tapsPerPress > 1 replays a double-tap: the second call lands
              // before the pushed route has covered the row.
              for (var i = 0; i < tapsPerPress; i++) {
                startPlayback(context, ref, sermon, queue: queue, mode: mode);
              }
            },
            child: const Text('open message'),
          ),
        ),
      ),
    ),
  );
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  setUp(() => MediaPlayerScreen.debugDisableVideoEngine = true);
  tearDown(() => MediaPlayerScreen.debugDisableVideoEngine = false);

  testWidgets(
    'video-only sermon opens the unified player in video mode and never '
    'reaches AudioPlayerService.play',
    (tester) async {
      final service = FakeAudioPlayerService();
      final sermon = _sermon(videoId: 'abc123');
      await tester.pumpWidget(_harness(service, sermon));

      await tester.tap(find.text('open message'));
      await tester.pumpAndSettle();

      expect(service.playCalls, isEmpty);
      expect(find.byType(MediaPlayerScreen), findsOneWidget);
      // Video mode chrome, not the old "video only" failure prompt.
      expect(find.text('Video'), findsOneWidget);
      expect(find.textContaining('video only'), findsNothing);
    },
  );

  testWidgets(
    'audio sermon starts audio exactly once and opens the same player screen',
    (tester) async {
      final service = FakeAudioPlayerService();
      final sermon = _sermon(audioUrl: 'https://a/x.mp3', videoId: 'abc123');
      await tester.pumpWidget(_harness(service, sermon));

      await tester.tap(find.text('open message'));
      await tester.pumpAndSettle();

      // One play from the launcher; the screen attaches instead of restarting.
      expect(service.playCalls.map((s) => s.id), ['s1']);
      expect(find.byType(MediaPlayerScreen), findsOneWidget);
    },
  );

  testWidgets('audio-only sermon opens with the Video chip disabled', (
    tester,
  ) async {
    final service = FakeAudioPlayerService();
    final sermon = _sermon(audioUrl: 'https://a/x.mp3');
    await tester.pumpWidget(_harness(service, sermon));

    await tester.tap(find.text('open message'));
    await tester.pumpAndSettle();

    expect(find.byType(MediaPlayerScreen), findsOneWidget);
    expect(
      find.byTooltip('No video recording for this message'),
      findsOneWidget,
    );
  });

  testWidgets(
    'double-tap on a video-only sermon pushes exactly one player screen',
    (tester) async {
      final service = FakeAudioPlayerService();
      final sermon = _sermon(videoId: 'abc123');
      await tester.pumpWidget(_harness(service, sermon, tapsPerPress: 2));

      await tester.tap(find.text('open message'));
      await tester.pumpAndSettle();

      expect(find.byType(MediaPlayerScreen), findsOneWidget);
    },
  );

  testWidgets(
    'double-tap on an audio sermon starts audio once and stacks no screen',
    (tester) async {
      final service = FakeAudioPlayerService();
      final sermon = _sermon(audioUrl: 'https://a/x.mp3', videoId: 'abc123');
      await tester.pumpWidget(_harness(service, sermon, tapsPerPress: 2));

      await tester.tap(find.text('open message'));
      await tester.pumpAndSettle();

      expect(service.playCalls.map((s) => s.id), ['s1']);
      expect(find.byType(MediaPlayerScreen), findsOneWidget);
    },
  );

  testWidgets('player can be reopened after being popped (latch clears)', (
    tester,
  ) async {
    final service = FakeAudioPlayerService();
    final sermon = _sermon(audioUrl: 'https://a/x.mp3');
    await tester.pumpWidget(_harness(service, sermon));

    await tester.tap(find.text('open message'));
    await tester.pumpAndSettle();
    expect(find.byType(MediaPlayerScreen), findsOneWidget);

    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();
    expect(find.byType(MediaPlayerScreen), findsNothing);

    await tester.tap(find.text('open message'));
    await tester.pumpAndSettle();
    expect(find.byType(MediaPlayerScreen), findsOneWidget);
  });

  testWidgets('the caller\'s list is the queue', (tester) async {
    final service = FakeAudioPlayerService();
    final list = [
      for (var n = 1; n <= 3; n++)
        Sermon(
          id: 's$n',
          title: 'M$n',
          speaker: 'A',
          audioUrl: 'https://a/$n.mp3',
        ),
    ];
    await tester.pumpWidget(_harness(service, list[1], queue: list));

    await tester.tap(find.text('open message'));
    await tester.pumpAndSettle();

    expect(service.calls.single.queue?.map((s) => s.id), ['s1', 's2', 's3']);
  });

  testWidgets('no list falls back to the library order', (tester) async {
    final service = FakeAudioPlayerService();
    final library = [
      for (var n = 1; n <= 3; n++)
        Sermon(
          id: 's$n',
          title: 'M$n',
          speaker: 'A',
          audioUrl: 'https://a/$n.mp3',
        ),
    ];
    await tester.pumpWidget(_harness(service, library.first, library: library));
    // The library is loaded by the time a member taps (Messages watches it).
    await ProviderScope.containerOf(
      tester.element(find.byType(TextButton)),
    ).read(sermonsProvider.future);

    await tester.tap(find.text('open message'));
    await tester.pumpAndSettle();

    expect(service.calls.single.queue?.map((s) => s.id), ['s1', 's2', 's3']);
  });

  testWidgets('MediaMode.video opens an audio twin as video without audio', (
    tester,
  ) async {
    final service = FakeAudioPlayerService();
    final twin = _sermon(audioUrl: 'https://a/x.mp3', videoId: 'abc123');
    await tester.pumpWidget(_harness(service, twin, mode: MediaMode.video));

    await tester.tap(find.text('open message'));
    await tester.pumpAndSettle();

    expect(service.playCalls, isEmpty);
    expect(find.byType(MediaPlayerScreen), findsOneWidget);
    expect(
      find.byTooltip('No audio recording for this message'),
      findsNothing,
      reason: 'the twin keeps Audio one tap away',
    );
  });
}
