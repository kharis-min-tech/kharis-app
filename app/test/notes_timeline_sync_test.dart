import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:just_audio/just_audio.dart';

import 'package:kharis_app/features/notes/data/note_repository.dart';
import 'package:kharis_app/features/notes/data/note_timeline_key.dart';
import 'package:kharis_app/features/notes/presentation/screens/note_editor_screen.dart';
import 'package:kharis_app/features/notes/presentation/widgets/sermon_notes_sheet.dart';
import 'package:kharis_app/features/player/data/audio_player_service.dart';
import 'package:kharis_app/features/player/presentation/screens/media_player_screen.dart';
import 'package:kharis_app/shared/models/sermon.dart';
import 'package:kharis_app/shared/models/user.dart';
import 'package:kharis_app/shared/providers/audio_provider.dart';
import 'package:kharis_app/shared/providers/auth_provider.dart';
import 'package:kharis_app/shared/providers/branch_provider.dart';
import 'package:kharis_app/shared/providers/notes_provider.dart';
import 'package:kharis_app/shared/providers/sermon_provider.dart';

/// Coverage for the shared note timeline across the audio and video engines:
///
///  - one message, three [Sermon] id variants (API mp3, `yt_` CMS doc, bare
///    YouTube feed id) must resolve to ONE note store;
///  - a note written in video mode is stamped with the VIDEO engine's clock,
///    in audio mode with the audio engine's;
///  - tapping a note anchor seeks whichever engine is active, never the
///    other one.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  // The same physical message as each source surfaces it.
  final apiVariant = Sermon(
    id: '2611',
    title: 'Grace Over Guilt',
    speaker: 'Pastor A',
    audioUrl: 'https://cdn.example/grace.mp3',
    videoId: 'abc123',
  );
  final cmsVariant = apiVariant.copyWith(id: 'yt_abc123', audioUrl: '');
  final feedVariant = apiVariant.copyWith(id: 'abc123', audioUrl: '');
  const audioOnly = Sermon(
    id: '9004',
    title: 'Streams in the Desert',
    speaker: 'Pastor A',
    audioUrl: 'https://cdn.example/streams.mp3',
  );

  Note note(String id, String? sermonId, int? positionMs) => Note(
        id: id,
        sermonId: sermonId,
        sermonTitle: 'Grace Over Guilt',
        positionMs: positionMs,
        body: 'note $id',
        createdAt: DateTime(2026, 3, 1),
        updatedAt: DateTime(2026, 3, 1),
      );

  group('NoteTimelineKey', () {
    test('every variant of a video-bearing message shares one canonical key',
        () {
      expect(NoteTimelineKey.of(apiVariant).canonical, 'yt_abc123');
      expect(NoteTimelineKey.of(cmsVariant).canonical, 'yt_abc123');
      expect(NoteTimelineKey.of(feedVariant).canonical, 'yt_abc123');
    });

    test('an audio-only message keeps its own id as the canonical key', () {
      expect(NoteTimelineKey.of(audioOnly).canonical, '9004');
    });

    test('matches accepts the canonical key and every legacy alias', () {
      final key = NoteTimelineKey.of(apiVariant);
      expect(key.matches('yt_abc123'), isTrue, reason: 'canonical');
      expect(key.matches('2611'), isTrue, reason: 'legacy raw API id');
      expect(key.matches('abc123'), isTrue, reason: 'legacy bare videoId');
      expect(key.matches('9004'), isFalse);
      expect(key.matches(null), isFalse);
    });

    test('value equality, so the provider family caches per message', () {
      expect(
        NoteTimelineKey.of(apiVariant),
        const NoteTimelineKey('2611', videoId: 'abc123'),
      );
      expect(
        NoteTimelineKey.of(apiVariant),
        isNot(NoteTimelineKey.of(audioOnly)),
      );
    });
  });

  group('sermonNotesProvider shared-key resolution', () {
    test('notes stored under any id variant land on one timeline', () async {
      final container = ProviderContainer(overrides: [
        notesProvider.overrideWith(
          (ref) => Stream.value([
            note('legacy-audio', '2611', 900000),
            note('legacy-video', 'abc123', 60000),
            note('canonical', 'yt_abc123', 300000),
            note('other-message', '9004', 5000),
          ]),
        ),
        // The loaded library, as in production: the API variant is the only
        // place the numeric id '2611' is linked to the video 'abc123' — the
        // yt_/feed variants cannot derive it, so sermonNotesProvider resolves
        // that alias through the catalogue.
        sermonsProvider.overrideWith((ref) async => [apiVariant, audioOnly]),
      ]);
      addTearDown(container.dispose);
      await container.read(notesProvider.future);
      await container.read(sermonsProvider.future);

      // Whichever variant opened the player, the timeline is the same.
      for (final variant in [apiVariant, cmsVariant, feedVariant]) {
        final scoped =
            container.read(sermonNotesProvider(NoteTimelineKey.of(variant)));
        expect(
          scoped.map((n) => n.id),
          ['legacy-video', 'canonical', 'legacy-audio'],
          reason: 'variant ${variant.id} must see the one shared timeline',
        );
      }

      final other =
          container.read(sermonNotesProvider(NoteTimelineKey.of(audioOnly)));
      expect(other.map((n) => n.id), ['other-message']);
    });
  });

  group('unified player note capture and anchor seek', () {
    late _FakeAudioPlayerService audio;
    late StreamController<Duration> videoPositions;
    late List<Duration> videoSeeks;

    setUp(() {
      audio = _FakeAudioPlayerService();
      videoPositions = StreamController<Duration>.broadcast();
      videoSeeks = [];
      MediaPlayerScreen.debugDisableVideoEngine = true;
      MediaPlayerScreen.debugVideoNoteBinding = NoteTimelineBinding(
        position: videoPositions.stream,
        seek: (target) async => videoSeeks.add(target),
      );
    });

    tearDown(() async {
      MediaPlayerScreen.debugDisableVideoEngine = false;
      MediaPlayerScreen.debugVideoNoteBinding = null;
      await videoPositions.close();
    });

    Widget harness(Sermon sermon, MediaMode mode, List<Note> notes) {
      return ProviderScope(
        overrides: [
          audioPlayerServiceProvider.overrideWithValue(audio),
          notesProvider.overrideWith((ref) => Stream.value(notes)),
          // Hermetic: sermonNotesProvider consults the catalogue for legacy
          // aliases — keep it empty so no network/asset load runs here.
          sermonsProvider.overrideWith((ref) async => const <Sermon>[]),
        ],
        child: MaterialApp(
          home: MediaPlayerScreen(sermon: sermon, mode: mode),
        ),
      );
    }

    testWidgets('video mode stamps a new note with the video engine clock',
        (tester) async {
      await tester.pumpWidget(harness(apiVariant, MediaMode.video, const []));
      // PlayerActions sits below the fold of the player's scroll view in the
      // 800x600 test viewport — an un-scrolled tap would silently no-op.
      await tester.ensureVisible(find.text('Notes'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Notes'));
      await tester.pumpAndSettle();

      videoPositions.add(const Duration(minutes: 5, seconds: 15));
      // Two pumps: one delivers the stream event and marks the button dirty,
      // the next paints the stamped label.
      await tester.pump();
      await tester.pump();
      expect(find.text('Add a note at 05:15'), findsOneWidget);

      await tester.tap(find.text('Add a note at 05:15'));
      await tester.pumpAndSettle();

      final editor =
          tester.widget<NoteEditorScreen>(find.byType(NoteEditorScreen));
      expect(editor.positionMs, 315000,
          reason: 'the VIDEO position, though audio is stopped');
      expect(editor.sermon?.id, apiVariant.id);
    });

    testWidgets('video mode seeks the video engine, never the audio one',
        (tester) async {
      final anchored = [note('n1', 'yt_abc123', 750000)];
      await tester.pumpWidget(harness(apiVariant, MediaMode.video, anchored));
      await tester.ensureVisible(find.text('Notes'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Notes'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('12:30'));
      await tester.pumpAndSettle();

      expect(videoSeeks, [const Duration(milliseconds: 750000)]);
      expect(audio.seekCalls, isEmpty);
      expect(audio.playCalls, isEmpty);
      expect(find.byType(SermonNotesSheet), findsNothing);
    });

    testWidgets('audio mode stamps a new note with the audio engine clock',
        (tester) async {
      audio.current = apiVariant;
      await tester.pumpWidget(harness(apiVariant, MediaMode.audio, const []));
      await tester.ensureVisible(find.text('Notes'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Notes'));
      await tester.pumpAndSettle();

      audio.positions.add(const Duration(minutes: 5));
      // Two pumps: one delivers the stream event and marks the button dirty,
      // the next paints the stamped label.
      await tester.pump();
      await tester.pump();
      expect(find.text('Add a note at 05:00'), findsOneWidget);
    });

    testWidgets(
        'audio mode seeks the audio engine — even for a note stored under '
        'the canonical yt_ key', (tester) async {
      audio.current = apiVariant;
      final anchored = [note('n1', 'yt_abc123', 750000)];
      await tester.pumpWidget(harness(apiVariant, MediaMode.audio, anchored));
      await tester.ensureVisible(find.text('Notes'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Notes'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('12:30'));
      await tester.pumpAndSettle();

      expect(audio.seekCalls, [const Duration(milliseconds: 750000)]);
      expect(audio.resumed, isTrue);
      expect(videoSeeks, isEmpty);
      expect(find.byType(SermonNotesSheet), findsNothing);
    });
  });

  group('note editor writes the canonical key', () {
    late Directory hiveDir;
    late Box<dynamic> box;

    setUp(() async {
      hiveDir = Directory.systemTemp.createTempSync('kharis_notes_sync_test');
      Hive.init(hiveDir.path);
      // Memory-backed box (`bytes:`): a disk-backed box's writes are REAL
      // file IO, which never completes under the widget test's fake clock —
      // the editor would hang forever awaiting its save.
      box = await Hive.openBox<dynamic>('notes', bytes: Uint8List(0));
    });

    tearDown(() async {
      // deleteFromDisk is unsupported for memory-backed boxes; close is all
      // the cleanup they need.
      await Hive.close();
      hiveDir.deleteSync(recursive: true);
    });

    testWidgets('a note saved against the API mp3 variant lands under yt_',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            firestoreProvider.overrideWithValue(FakeFirebaseFirestore()),
            localNoteStoreProvider.overrideWithValue(LocalNoteStore(box)),
            currentUserProvider.overrideWith((ref) => Stream<User?>.value(null)),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) => TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => NoteEditorScreen(
                      sermon: apiVariant,
                      positionMs: 315000,
                    ),
                  ),
                ),
                child: const Text('open editor'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open editor'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Hold this thought');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final stored = Map<String, dynamic>.from(
        jsonDecode(box.values.single as String) as Map,
      );
      expect(stored['sermonId'], 'yt_abc123',
          reason: 'canonical key, not the raw API id 2611');
      expect(stored['positionMs'], 315000);
      expect(stored['body'], 'Hold this thought');
    });
  });
}

// ── Fake audio engine ─────────────────────────────────────────────────────────

/// No just_audio behind it; records what the notes surfaces drive it to do.
class _FakeAudioPlayerService implements AudioPlayerService {
  final List<Sermon> playCalls = [];
  final List<Duration> seekCalls = [];
  final StreamController<Duration> positions =
      StreamController<Duration>.broadcast();
  bool resumed = false;
  Sermon? current;

  @override
  Sermon? get currentSermon => current;

  @override
  Duration get position => Duration.zero;

  @override
  PlaybackFailure? get failure => null;

  @override
  Stream<PlaybackFailure?> get failureStream => const Stream.empty();

  @override
  Stream<PlayerState> get playerStateStream => const Stream.empty();

  @override
  Stream<Duration> get positionStream => positions.stream;

  @override
  Stream<Duration?> get durationStream => const Stream.empty();

  @override
  Future<bool> play(Sermon sermon) async {
    playCalls.add(sermon);
    current = sermon;
    return true;
  }

  @override
  Future<bool> retry() async => false;

  @override
  Future<void> loadPaused(Sermon sermon) async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> resume() async {
    resumed = true;
  }

  @override
  Future<void> stop() async {
    current = null;
  }

  @override
  Future<void> seek(Duration position) async {
    seekCalls.add(position);
  }

  @override
  Future<void> setSpeed(double speed) async {}

  @override
  Future<void> dispose() async {}
}
