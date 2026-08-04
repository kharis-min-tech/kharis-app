import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:just_audio/just_audio.dart';
import 'package:kharis_app/features/player/data/audio_player_service.dart';
import 'package:kharis_app/features/player/presentation/playback_launcher.dart';
import 'package:kharis_app/features/player/presentation/screens/media_player_screen.dart';
import 'package:kharis_app/shared/models/sermon.dart';
import 'package:kharis_app/shared/providers/audio_provider.dart';

/// Fake with no just_audio engine behind it, so tests can prove exactly which
/// sermons reach [AudioPlayerService.play].
class FakeAudioPlayerService implements AudioPlayerService {
  final List<Sermon> playCalls = [];
  Sermon? _current;

  @override
  Sermon? get currentSermon => _current;

  @override
  Duration get position => Duration.zero;

  @override
  PlaybackFailure? get failure => null;

  @override
  Stream<PlaybackFailure?> get failureStream => const Stream.empty();

  @override
  Stream<PlayerState> get playerStateStream => const Stream.empty();

  @override
  Stream<Duration> get positionStream => const Stream.empty();

  @override
  Stream<Duration?> get durationStream => const Stream.empty();

  @override
  Future<bool> play(Sermon sermon) async {
    playCalls.add(sermon);
    _current = sermon;
    return true;
  }

  @override
  Future<bool> retry() async => false;

  @override
  Future<void> loadPaused(Sermon sermon) async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> resume() async {}

  @override
  Future<void> stop() async {
    _current = null;
  }

  @override
  Future<void> seek(Duration position) async {}

  @override
  Future<void> setSpeed(double speed) async {}

  @override
  Future<void> dispose() async {}
}

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
}) {
  return ProviderScope(
    overrides: [audioPlayerServiceProvider.overrideWithValue(service)],
    child: MaterialApp(
      home: Scaffold(
        body: Consumer(
          builder: (context, ref, _) => TextButton(
            onPressed: () {
              // tapsPerPress > 1 replays a double-tap: the second call lands
              // before the pushed route has covered the row.
              for (var i = 0; i < tapsPerPress; i++) {
                startPlayback(ref, sermon);
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
      'reaches AudioPlayerService.play', (tester) async {
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
  });

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
  });

  testWidgets('audio-only sermon opens with the Video chip disabled',
      (tester) async {
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
  });

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
  });

  testWidgets('player can be reopened after being popped (latch clears)',
      (tester) async {
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
}
