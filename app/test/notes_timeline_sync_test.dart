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

import 'package:kharis_app/features/notes/data/note_repository.dart';
import 'package:kharis_app/features/notes/data/note_timeline_key.dart';
import 'package:kharis_app/features/notes/presentation/widgets/sermon_notes_sheet.dart';
import 'package:kharis_app/features/player/presentation/screens/media_player_screen.dart';
import 'package:kharis_app/features/playlists/providers/playlist_providers.dart';
import 'package:kharis_app/shared/models/sermon.dart';
import 'package:kharis_app/shared/models/user.dart';
import 'package:kharis_app/shared/providers/audio_provider.dart';
import 'package:kharis_app/shared/providers/cache_provider.dart';
import 'package:kharis_app/shared/providers/auth_provider.dart';
import 'package:kharis_app/shared/providers/branch_provider.dart';
import 'package:kharis_app/shared/providers/notes_provider.dart';
import 'package:kharis_app/shared/providers/sermon_provider.dart';

import 'support/fake_audio_player_service.dart';
import 'support/fake_cache_service.dart';
import 'support/fake_note_repository.dart';

/// Coverage for the shared notepad across the audio and video engines:
///
///  - one message, three [Sermon] id variants (API mp3, `yt_` CMS doc, bare
///    YouTube feed id) must resolve to ONE note store;
///  - Insert in video mode stamps the VIDEO engine's clock, in audio mode the
///    audio engine's;
///  - tapping a stamp seeks whichever engine is active, never the other one.
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
    test(
      'every variant of a video-bearing message shares one canonical key',
      () {
        expect(NoteTimelineKey.of(apiVariant).canonical, 'yt_abc123');
        expect(NoteTimelineKey.of(cmsVariant).canonical, 'yt_abc123');
        expect(NoteTimelineKey.of(feedVariant).canonical, 'yt_abc123');
      },
    );

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
      final container = ProviderContainer(
        overrides: [
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
        ],
      );
      addTearDown(container.dispose);
      await container.read(notesProvider.future);
      await container.read(sermonsProvider.future);

      // Whichever variant opened the player, the timeline is the same.
      for (final variant in [apiVariant, cmsVariant, feedVariant]) {
        final scoped = container.read(
          sermonNotesProvider(NoteTimelineKey.of(variant)),
        );
        expect(
          scoped.map((n) => n.id),
          ['legacy-video', 'canonical', 'legacy-audio'],
          reason: 'variant ${variant.id} must see the one shared timeline',
        );
      }

      final other = container.read(
        sermonNotesProvider(NoteTimelineKey.of(audioOnly)),
      );
      expect(other.map((n) => n.id), ['other-message']);
    });
  });

  group('unified player notepad: Insert and timestamp seeks', () {
    late FakeAudioPlayerService audio;
    late StreamController<Duration> videoPositions;
    late List<Duration> videoSeeks;

    setUp(() {
      audio = FakeAudioPlayerService();
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
          cacheServiceProvider.overrideWithValue(FakeCacheService()),
          notesProvider.overrideWith((ref) => Stream.value(notes)),
          notesRepositoryProvider.overrideWithValue(FakeNoteRepository()),
          // Hermetic: sermonNotesProvider consults the catalogue for legacy
          // aliases — keep it empty so no network/asset load runs here.
          sermonsProvider.overrideWith((ref) async => const <Sermon>[]),
          // The like button reads the member's Favorites; keep it offline.
          favoritesProvider.overrideWith((ref) => Stream.value(null)),
        ],
        child: MaterialApp(
          home: MediaPlayerScreen(sermon: sermon, mode: mode),
        ),
      );
    }

    /// Opens the notes sheet from the player's action row.
    Future<void> openNotes(WidgetTester tester) async {
      // PlayerActions sits below the fold of the player's scroll view in the
      // 800x600 test viewport — an un-scrolled tap would silently no-op.
      await tester.ensureVisible(find.text('Notes'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Notes'));
      await tester.pumpAndSettle();
    }

    String notepadText(WidgetTester tester) =>
        tester.widget<TextField>(find.byType(TextField)).controller!.text;

    testWidgets('video mode inserts the video engine clock at the cursor', (
      tester,
    ) async {
      await tester.pumpWidget(harness(apiVariant, MediaMode.video, const []));
      await openNotes(tester);

      videoPositions.add(const Duration(minutes: 5, seconds: 15));
      // Two pumps: one delivers the stream event and marks the button dirty,
      // the next paints the stamped label.
      await tester.pump();
      await tester.pump();
      await tester.tap(find.text('Insert 5:15'));
      await tester.pump();

      expect(
        notepadText(tester),
        '[5:15] ',
        reason: 'the VIDEO position, though audio is stopped',
      );
    });

    testWidgets('video mode seeks the video engine, never the audio one', (
      tester,
    ) async {
      final pad = [note('n1', 'yt_abc123', null)];
      await tester.pumpWidget(harness(apiVariant, MediaMode.video, pad));
      await openNotes(tester);
      // The notes stub's body: a stamp, then text.
      await tester.enterText(find.byType(TextField), '[12:30] Grace');
      await tester.pump();

      await tapFirstStamp(tester);
      await tester.pumpAndSettle();

      expect(videoSeeks, [const Duration(minutes: 12, seconds: 30)]);
      expect(audio.seekCalls, isEmpty);
      expect(audio.playCalls, isEmpty);
      expect(
        find.byType(SermonNotesSheet),
        findsOneWidget,
        reason: 'the notepad stays open to keep writing',
      );
    });

    testWidgets('audio mode inserts the audio engine clock', (tester) async {
      audio.current = apiVariant;
      await tester.pumpWidget(harness(apiVariant, MediaMode.audio, const []));
      await openNotes(tester);

      audio.positions.add(const Duration(minutes: 5));
      await tester.pump();
      await tester.pump();
      expect(find.text('Insert 5:00'), findsOneWidget);
    });

    testWidgets(
      'audio mode seeks the audio engine — even for a notepad stored under '
      'the canonical yt_ key',
      (tester) async {
        audio.current = apiVariant;
        final legacy = [note('n1', 'yt_abc123', 750000)];
        await tester.pumpWidget(harness(apiVariant, MediaMode.audio, legacy));
        await openNotes(tester);
        expect(notepadText(tester), '[12:30] note n1');

        await tapFirstStamp(tester);
        await tester.pumpAndSettle();

        // One play request carrying the stamp as its start point: the engine
        // attaches to the loaded message and seeks there, no trailing seek.
        expect(audio.calls, hasLength(1));
        expect(audio.calls.single.sermon.id, apiVariant.id);
        expect(
          audio.calls.single.startAt,
          const Duration(minutes: 12, seconds: 30),
        );
        expect(videoSeeks, isEmpty);
      },
    );
  });

  group('the notepad saves under the canonical key', () {
    late Directory hiveDir;
    late Box<dynamic> box;

    setUp(() async {
      hiveDir = Directory.systemTemp.createTempSync('kharis_notes_sync_test');
      Hive.init(hiveDir.path);
      // Memory-backed box (`bytes:`): a disk-backed box's writes are REAL
      // file IO, which never completes under the widget test's fake clock —
      // the save would never land.
      box = await Hive.openBox<dynamic>('notes', bytes: Uint8List(0));
    });

    tearDown(() async {
      // deleteFromDisk is unsupported for memory-backed boxes; close is all
      // the cleanup they need.
      await Hive.close();
      hiveDir.deleteSync(recursive: true);
    });

    List<Map<String, dynamic>> stored() => [
      for (final raw in box.values)
        Map<String, dynamic>.from(jsonDecode(raw as String) as Map),
    ];

    testWidgets('opened on the API mp3 variant, older notes fold in and the '
        'notepad lands under yt_', (tester) async {
      final legacy = LocalNoteStore(box);
      await tester.runAsync(() async {
        await legacy.upsert(note('late', '2611', 900000));
        await legacy.upsert(note('early', 'abc123', 65000));
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            audioPlayerServiceProvider.overrideWithValue(
              FakeAudioPlayerService(),
            ),
            firestoreProvider.overrideWithValue(FakeFirebaseFirestore()),
            localNoteStoreProvider.overrideWithValue(legacy),
            currentUserProvider.overrideWith(
              (ref) => Stream<User?>.value(null),
            ),
            sermonsProvider.overrideWith((ref) async => [apiVariant]),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) => TextButton(
                onPressed: () => SermonNotesSheet.show(context, apiVariant),
                child: const Text('open notes'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open notes'));
      await tester.pumpAndSettle();
      final field = find.byType(TextField);
      expect(
        tester.widget<TextField>(field).controller!.text,
        '[1:05] note early\n[15:00] note late',
        reason: 'one line per older note, in timeline order',
      );

      await tester.enterText(
        field,
        'Hold this thought\n[1:05] note early\n[15:00] note late',
      );
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      final notes = stored();
      expect(notes, hasLength(1), reason: 'the older notes are retired');
      expect(
        notes.single['sermonId'],
        'yt_abc123',
        reason: 'canonical key, not the raw API id 2611',
      );
      expect(notes.single['positionMs'], isNull);
      expect(
        notes.single['body'],
        'Hold this thought\n[1:05] note early\n[15:00] note late',
      );
    });
  });
}
