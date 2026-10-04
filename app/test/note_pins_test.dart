import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:kharis_app/features/notes/data/note_repository.dart';
import 'package:kharis_app/features/notes/presentation/widgets/sermon_notes_sheet.dart';
import 'package:kharis_app/features/player/presentation/screens/media_player_screen.dart';
import 'package:kharis_app/features/player/presentation/widgets/seek_bar.dart';
import 'package:kharis_app/features/playlists/providers/playlist_providers.dart';
import 'package:kharis_app/shared/models/sermon.dart';
import 'package:kharis_app/shared/providers/audio_provider.dart';
import 'package:kharis_app/shared/providers/cache_provider.dart';
import 'package:kharis_app/shared/providers/notes_provider.dart';
import 'package:kharis_app/shared/providers/sermon_provider.dart';

import 'support/fake_audio_player_service.dart';
import 'support/fake_cache_service.dart';

/// The member's notes as pins on the player's seek bar: one per anchored
/// note on the message on screen, on the timeline of the engine playing it,
/// live as notes come and go.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  // Like API sermon 101897: the mp3 starts 487 s into the service video.
  const service = Sermon(
    id: '2611',
    title: 'Grace Over Guilt',
    speaker: 'Pastor A',
    audioUrl: 'https://cdn.example/grace.mp3',
    videoId: 'abc123',
    videoStart: Duration(seconds: 487),
  );

  Note note(String id, String? sermonId, int? positionMs) => Note(
    id: id,
    sermonId: sermonId,
    sermonTitle: service.title,
    positionMs: positionMs,
    body: 'note $id',
    createdAt: DateTime(2026, 3, 1),
    updatedAt: DateTime(2026, 3, 1),
  );

  const tenMinutes = 600000;
  const twelveThirty = 750000;

  late FakeAudioPlayerService audio;
  late StreamController<List<Note>> notes;

  setUp(() {
    audio = FakeAudioPlayerService();
    notes = StreamController<List<Note>>.broadcast();
    MediaPlayerScreen.debugDisableVideoEngine = true;
    MediaPlayerScreen.debugLastVideoPins = null;
  });

  tearDown(() async {
    MediaPlayerScreen.debugDisableVideoEngine = false;
    MediaPlayerScreen.debugLastVideoPins = null;
    await notes.close();
  });

  Future<void> open(
    WidgetTester tester,
    MediaMode mode,
    List<Note> initial,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          audioPlayerServiceProvider.overrideWithValue(audio),
          cacheServiceProvider.overrideWithValue(FakeCacheService()),
          // The notes stream the sheet's adds and deletes surface through.
          notesProvider.overrideWith((ref) async* {
            yield initial;
            yield* notes.stream;
          }),
          // Hermetic: sermonNotesProvider consults the catalogue for legacy
          // aliases; keep it empty so no network/asset load runs here.
          sermonsProvider.overrideWith((ref) async => const <Sermon>[]),
          // The heart reads the member's Favorites; keep it offline.
          favoritesProvider.overrideWith((ref) => Stream.value(null)),
        ],
        child: MaterialApp(
          home: MediaPlayerScreen(sermon: service, mode: mode),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> emit(WidgetTester tester, List<Note> next) async {
    notes.add(next);
    await tester.pumpAndSettle();
  }

  List<Duration> audioPins(WidgetTester tester) =>
      tester.widget<SeekBar>(find.byType(SeekBar)).pins;

  group('audio mode', () {
    testWidgets('pins sit at the notes\' audio positions; general notes do '
        'not pin', (tester) async {
      audio.current = service;
      await open(tester, MediaMode.audio, [
        note('n1', 'yt_abc123', tenMinutes),
        note('general', 'yt_abc123', null),
        note('other', 'yt_zzz999', 60000),
      ]);

      expect(audioPins(tester), [const Duration(minutes: 10)]);
    });

    testWidgets('pins follow notes as they are added and deleted', (
      tester,
    ) async {
      audio.current = service;
      await open(tester, MediaMode.audio, [
        note('n1', 'yt_abc123', tenMinutes),
      ]);
      expect(audioPins(tester), [const Duration(minutes: 10)]);

      // Added from the notes sheet.
      await emit(tester, [
        note('n1', 'yt_abc123', tenMinutes),
        note('n2', 'yt_abc123', twelveThirty),
      ]);
      expect(audioPins(tester), [
        const Duration(minutes: 10),
        const Duration(minutes: 12, seconds: 30),
      ]);

      // The 10:00 note deleted.
      await emit(tester, [note('n2', 'yt_abc123', twelveThirty)]);
      expect(audioPins(tester), [const Duration(minutes: 12, seconds: 30)]);

      await emit(tester, const []);
      expect(audioPins(tester), isEmpty);
    });

    testWidgets('the bar announces how many notes it marks', (tester) async {
      audio.current = service;
      await open(tester, MediaMode.audio, [
        note('n1', 'yt_abc123', tenMinutes),
        note('n2', 'yt_abc123', twelveThirty),
      ]);
      audio.durations.add(const Duration(minutes: 40));
      await tester.pumpAndSettle();

      expect(
        tester
            .getSemantics(find.byType(SeekBar))
            .label
            .startsWith('Playback position, 2 notes on this message'),
        isTrue,
      );
    });
  });

  group('video mode (videoStart 8:07)', () {
    testWidgets('a note at 10:00 audio pins at 18:07 on the video bar', (
      tester,
    ) async {
      await open(tester, MediaMode.video, [
        note('n1', 'yt_abc123', tenMinutes),
        note('general', 'yt_abc123', null),
      ]);

      expect(MediaPlayerScreen.debugLastVideoPins, [
        const Duration(minutes: 18, seconds: 7),
      ]);
    });

    testWidgets('video pins follow notes as they are added and deleted', (
      tester,
    ) async {
      await open(tester, MediaMode.video, [
        note('n1', 'yt_abc123', tenMinutes),
      ]);

      await emit(tester, [
        note('n1', 'yt_abc123', tenMinutes),
        note('n2', 'yt_abc123', twelveThirty),
      ]);
      expect(MediaPlayerScreen.debugLastVideoPins, [
        const Duration(minutes: 18, seconds: 7),
        const Duration(minutes: 20, seconds: 37),
      ]);

      await emit(tester, [note('n2', 'yt_abc123', twelveThirty)]);
      expect(MediaPlayerScreen.debugLastVideoPins, [
        const Duration(minutes: 20, seconds: 37),
      ]);
    });

    testWidgets('a pin taps through to the same moment the note seeks to', (
      tester,
    ) async {
      final seeks = <Duration>[];
      MediaPlayerScreen.debugVideoNoteBinding = NoteTimelineBinding(
        position: const Stream.empty(),
        seek: (target) async => seeks.add(target),
      );
      addTearDown(() => MediaPlayerScreen.debugVideoNoteBinding = null);
      await open(tester, MediaMode.video, [
        note('n1', 'yt_abc123', tenMinutes),
      ]);

      await tester.ensureVisible(find.text('Notes'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Notes'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('10:00'));
      await tester.pumpAndSettle();

      // The pin and the anchor seek agree on where the note lives.
      expect(seeks, MediaPlayerScreen.debugLastVideoPins);
    });
  });
}
