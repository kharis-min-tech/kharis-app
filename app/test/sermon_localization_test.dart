import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:just_audio_platform_interface/just_audio_platform_interface.dart';
import 'package:kharis_app/features/player/data/audio_player_service.dart';
import 'package:kharis_app/features/player/data/sermon_localization.dart';
import 'package:kharis_app/features/player/presentation/widgets/sermon_languages.dart';
import 'package:kharis_app/shared/models/sermon.dart';
import 'package:kharis_app/shared/providers/audio_provider.dart';
import 'package:kharis_app/shared/providers/sermon_localization_provider.dart';
import 'support/fake_audio_player_service.dart';
import 'support/fake_cache_service.dart';
import 'support/fake_just_audio_platform.dart';

const sermon = Sermon(
  id: '123',
  title: 'Message',
  speaker: 'David Antwi',
  audioUrl: 'https://cdn.example/original.mp3',
);
const french = SermonLanguageTrack(
  language: 'fr',
  label: 'Français',
  audioUrl: 'https://cdn.example/fr.mp3',
  subtitlesUrl: 'https://cdn.example/fr.vtt',
);

Map<String, Object> manifest({bool reviewed = true}) => {
  'schemaVersion': 1,
  'sermonId': sermon.id,
  'sourceAudioUrl': sermon.audioUrl,
  'timeline': 'audio',
  'tracks': [
    {
      'language': 'fr',
      'label': 'Français',
      'audioUrl': french.audioUrl,
      'subtitlesUrl': french.subtitlesUrl,
      'reviewed': reviewed,
    },
  ],
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('only reviewed media tied to this exact recording is offered', () {
    List<SermonLanguageTrack> parse(Object m) =>
        SermonLanguageTrack.fromManifest(
          m,
          sermonId: sermon.id,
          sourceAudioUrl: sermon.audioUrl,
        );
    expect(parse(manifest()).single.language, 'fr');
    expect(parse(manifest(reviewed: false)), isEmpty);
    expect(
      () => parse({
        ...manifest(),
        'sourceAudioUrl': 'https://cdn.example/full-service.mp3',
      }),
      throwsFormatException,
    );
    expect(
      () => parse({...manifest(), 'timeline': 'video'}),
      throwsFormatException,
    );
  });

  test(
    'WebVTT parses cue settings and multiline text, seeks use half-open intervals',
    () {
      final cues = parseSermonCaptions(
        'WEBVTT\r\n\r\nNOTE ignored\r\n\r\ncue-1\r\n00:01.000 --> 00:03.250 align:center\r\n<c>La foi</c> &amp;\r\nla grâce\r\n\r\n2\r\n00:03.250 --> 00:05.000\r\nAmen.\r\n',
      );
      expect(cues, hasLength(2));
      expect(cues.first.text, 'La foi &\nla grâce');
      expect(cues.first.contains(const Duration(milliseconds: 3250)), isFalse);
      expect(cues.last.contains(const Duration(milliseconds: 3250)), isTrue);
      expect(
        () => parseSermonCaptions('<html>failed</html>'),
        throwsFormatException,
      );
    },
  );

  group('real audio engine language switching', () {
    late FakeJustAudioPlatform platform;
    late AudioPlayerService service;
    setUp(() {
      platform = FakeJustAudioPlatform.install();
      service = AudioPlayerService(FakeCacheService());
    });
    tearDown(() => service.dispose());
    Future<void> settle() =>
        Future<void>.delayed(const Duration(milliseconds: 5));

    test(
      'switches source at the same position and keeps queue, rate and paused state',
      () async {
        final next = sermon.copyWith(
          id: 'next',
          audioUrl: 'https://cdn.example/next.mp3',
        );
        await service.play(sermon, queue: [sermon, next]);
        await settle();
        await service.seek(const Duration(minutes: 2));
        await service.setSpeed(1.25);
        await service.pause();
        await settle();
        expect(await service.selectLanguageTrack(sermon, french), isTrue);
        await settle();
        final native = platform.player!;
        final load = native.loads.last;
        final sources =
            load.audioSourceMessage as ConcatenatingAudioSourceMessage;
        expect(
          (sources.children.first as ProgressiveAudioSourceMessage).uri,
          french.audioUrl,
        );
        expect(load.initialPosition, const Duration(minutes: 2));
        expect(service.currentSermon, sermon);
        expect(service.queue!.items.map((s) => s.id), ['123', 'next']);
        expect(service.playing, isFalse);
        expect(service.speed, 1.25);
        expect(await service.selectLanguageTrack(sermon, null), isTrue);
        expect(service.languageTrackFor(sermon), isNull);
      },
    );

    test(
      'failed French source restores original audio and resumes playback',
      () async {
        await service.play(sermon);
        await settle();
        await service.seek(const Duration(minutes: 3));
        await settle();
        platform.failNextLoad = true;
        expect(await service.selectLanguageTrack(sermon, french), isFalse);
        await settle();
        expect(service.languageTrackFor(sermon), isNull);
        expect(service.currentSermon, sermon);
        expect(service.playing, isTrue);
        expect(service.position.inSeconds, closeTo(180, 1));
      },
    );
  });

  testWidgets(
    'French subtitles follow position independently of selected audio',
    (tester) async {
      final audio = FakeAudioPlayerService();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            audioPlayerServiceProvider.overrideWithValue(audio),
            sermonLanguageTracksProvider(
              sermon,
            ).overrideWith((ref) async => [french]),
            sermonCaptionsProvider(french.subtitlesUrl).overrideWith(
              (ref) async => [
                const SermonCaption(
                  Duration(seconds: 1),
                  Duration(seconds: 4),
                  'La foi vient de ce qu’on entend.',
                ),
              ],
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(body: SermonLanguages(sermon: sermon)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('sermon-language-settings')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('sermon-subtitle-language')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Subtitles: Français').last);
      await tester.pumpAndSettle();
      audio.positions.add(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.text('La foi vient de ce qu’on entend.'), findsOneWidget);
      expect(
        audio.selectedTrack,
        isNull,
        reason: 'English audio can use French subtitles',
      );
      audio.positions.add(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(find.text('La foi vient de ce qu’on entend.'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
