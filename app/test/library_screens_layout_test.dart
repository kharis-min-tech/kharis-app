import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart' show PlayerState;

import 'package:kharis_app/features/notes/data/note_repository.dart';
import 'package:kharis_app/features/notes/presentation/screens/note_editor_screen.dart';
import 'package:kharis_app/features/notes/presentation/screens/notepad_screen.dart';
import 'package:kharis_app/features/notes/presentation/screens/notes_screen.dart';
import 'package:kharis_app/features/notes/presentation/widgets/sermon_notes_sheet.dart';
import 'package:kharis_app/features/playlists/data/playlist_repository.dart';
import 'package:kharis_app/features/playlists/presentation/screens/favorites_screen.dart';
import 'package:kharis_app/features/playlists/presentation/screens/playlist_detail_screen.dart';
import 'package:kharis_app/features/playlists/presentation/screens/playlists_screen.dart';
import 'package:kharis_app/features/playlists/presentation/widgets/add_to_playlist_sheet.dart';
import 'package:kharis_app/features/playlists/presentation/widgets/library_sheets.dart';
import 'package:kharis_app/features/playlists/presentation/widgets/playlist_name_dialog.dart';
import 'package:kharis_app/features/playlists/providers/playlist_providers.dart';
import 'package:kharis_app/shared/models/sermon.dart';
import 'package:kharis_app/shared/providers/audio_provider.dart';
import 'package:kharis_app/shared/providers/cache_provider.dart';
import 'package:kharis_app/shared/providers/notes_provider.dart';
import 'package:kharis_app/shared/providers/sermon_provider.dart';
import 'package:kharis_app/ui/components/components.dart';

import 'support/design_harness.dart';
import 'support/fake_cache_service.dart';
import 'support/fake_note_repository.dart';

/// Every notes and collections screen, on a 390-wide phone, in light and
/// dark, at 100% and 130% text: nothing overflows and the content a member
/// needs is there.
void main() {
  setUpAll(loadDesignAssets);

  final sermons = [
    const Sermon(
      id: 's1',
      title: 'Walking in faith when the road ahead is long and uncertain',
      speaker: 'Pastor David Antwi',
      audioUrl: 'https://cdn.example/s1.mp3',
      duration: Duration(hours: 1, minutes: 12),
    ),
    const Sermon(
      id: 's2',
      title: 'Grace',
      speaker: 'Pastor David',
      audioUrl: 'https://cdn.example/s2.mp3',
      duration: Duration(minutes: 48),
    ),
    const Sermon(
      id: 's3',
      title: 'The beatitudes, part three',
      speaker: '',
      audioUrl: 'https://cdn.example/s3.mp3',
    ),
  ];
  final at = DateTime(2026, 11, 1);
  final playlists = [
    Playlist(
      id: 'p1',
      name: 'For the drive home to Manchester on a Sunday evening',
      sermonIds: const ['s1', 's2'],
      createdAt: at,
      updatedAt: at,
    ),
    Playlist(
      id: 'p2',
      name: 'Faith builders',
      sermonIds: const [],
      createdAt: at,
      updatedAt: at,
    ),
  ];
  final favorites = Playlist(
    id: PlaylistRepository.favoritesId,
    name: 'Favorites',
    sermonIds: const ['s1', 's2', 's3'],
    createdAt: at,
    updatedAt: at,
  );
  final notes = [
    Note(
      id: 'n1',
      sermonId: 's1',
      sermonTitle: sermons[0].title,
      body:
          '[1:05] Grace is not earned, it is received\n'
          '[15:00] Mercy triumphs over judgement, every single time',
      createdAt: at,
      updatedAt: at,
    ),
    Note(
      id: 'n2',
      body: 'Ask about the midweek service and the youth camp dates',
      createdAt: at,
      updatedAt: DateTime.now(),
    ),
  ];

  List<Override> overrides({
    Stream<List<Playlist>> Function()? playlistStream,
    List<Note>? notebook,
  }) => [
    cacheServiceProvider.overrideWithValue(FakeCacheService()),
    playlistRepositoryProvider.overrideWithValue(
      PlaylistRepository(FakeFirebaseFirestore(), uid: 'member-1'),
    ),
    playlistsProvider.overrideWith(
      (ref) => playlistStream?.call() ?? Stream.value(playlists),
    ),
    favoritesProvider.overrideWith((ref) => Stream.value(favorites)),
    playlistResolutionProvider.overrideWith(
      (ref, id) => id == 'p1'
          ? PlaylistResolution(
              sermons: [sermons[0], sermons[1]],
              ids: const ['s1', 's2'],
            )
          : const PlaylistResolution(),
    ),
    favoritesResolutionProvider.overrideWith(
      (ref) => PlaylistResolution(
        sermons: sermons,
        ids: const ['s1', 's2', 's3'],
        missing: 1,
      ),
    ),
    sermonsProvider.overrideWith((ref) async => sermons),
    currentSermonProvider.overrideWith((ref) => sermons[1]),
    playerStateProvider.overrideWith(
      (ref) => const Stream<PlayerState>.empty(),
    ),
    positionProvider.overrideWith((ref) => const Stream<Duration>.empty()),
    notesProvider.overrideWith((ref) => Stream.value(notebook ?? notes)),
    notesRepositoryProvider.overrideWithValue(FakeNoteRepository()),
  ];

  /// Opens a sheet from a button, the way a screen does.
  Widget opener(Future<void> Function(BuildContext context) open) => Scaffold(
    body: Builder(
      builder: (context) =>
          TextButton(onPressed: () => open(context), child: const Text('open')),
    ),
  );

  final cases =
      <String, ({Widget home, List<Override> overrides, String sees})>{
        'collections': (
          home: const PlaylistsScreen(),
          overrides: overrides(),
          sees: 'Your collections',
        ),
        'collections, none yet': (
          home: const PlaylistsScreen(),
          overrides: overrides(playlistStream: () => Stream.value(const [])),
          sees: 'Build your first collection',
        ),
        'collections, loading': (
          home: const PlaylistsScreen(),
          overrides: overrides(playlistStream: () => const Stream.empty()),
          sees: 'Favourites',
        ),
        'collections, failed': (
          home: const PlaylistsScreen(),
          overrides: overrides(
            playlistStream: () => Stream.error(StateError('offline')),
          ),
          sees: 'Retry',
        ),
        'collection detail': (
          home: const PlaylistDetailScreen(playlistId: 'p1'),
          overrides: overrides(),
          sees: '2 messages · 2 h',
        ),
        'collection detail, empty': (
          home: const PlaylistDetailScreen(playlistId: 'p2'),
          overrides: overrides(),
          sees: 'Nothing here yet',
        ),
        'collection detail, gone': (
          home: const PlaylistDetailScreen(playlistId: 'nope'),
          overrides: overrides(),
          sees: 'This collection no longer exists',
        ),
        'favourites': (
          home: const FavoritesScreen(),
          overrides: overrides(),
          sees: '3 messages · newest first',
        ),
        'notes': (
          home: const NotesScreen(),
          overrides: overrides(),
          sees: 'Note',
        ),
        'notes, none yet': (
          home: const NotesScreen(),
          overrides: overrides(notebook: const []),
          sees: 'No notes yet',
        ),
        'notepad': (
          home: NotepadScreen(
            messageKey: 's1',
            notes: [notes[0]],
            title: sermons[0].title,
          ),
          overrides: overrides(),
          sees: 'Insert time',
        ),
        'note editor': (
          home: NoteEditorScreen(existingNote: notes[1]),
          overrides: overrides(),
          sees: 'Save',
        ),
        'add to collection sheet': (
          home: opener(
            (context) => showAddToPlaylistSheet(
              context,
              sermonId: 's1',
              sermonTitle: sermons[0].title,
              onOpenNotes: () {},
            ),
          ),
          overrides: overrides(),
          sees: 'Add to collection',
        ),
        'collection name sheet': (
          home: opener(
            (context) =>
                showPlaylistNameDialog(context, title: 'New collection'),
          ),
          overrides: overrides(),
          sees: 'Create',
        ),
        'confirm sheet': (
          home: opener(
            (context) => showConfirmSheet(
              context,
              title: 'Delete collection?',
              message:
                  '"${playlists[0].name}" will be removed from your library. '
                  'The messages themselves are untouched.',
              confirmLabel: 'Delete',
            ),
          ),
          overrides: overrides(),
          sees: 'Cancel',
        ),
        'message notes sheet': (
          home: opener((context) => SermonNotesSheet.show(context, sermons[1])),
          overrides: overrides(),
          sees: 'Done',
        ),
      };

  for (final MapEntry(key: name, value: screen) in cases.entries) {
    for (final dark in [false, true]) {
      for (final textScale in [1.0, 1.3]) {
        testWidgets('$name holds at 390 wide, ${dark ? 'dark' : 'light'}, '
            'text x$textScale', (tester) async {
          tester.view
            ..physicalSize = const Size(KSize.designWidth, 844)
            ..devicePixelRatio = 1;
          addTearDown(tester.view.reset);

          await tester.pumpWidget(
            ProviderScope(
              overrides: screen.overrides,
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: KharisTheme.light(),
                darkTheme: KharisTheme.dark(),
                themeMode: dark ? ThemeMode.dark : ThemeMode.light,
                builder: (context, app) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(textScale)),
                  child: app!,
                ),
                home: screen.home,
              ),
            ),
          );
          await tester.pumpAndSettle();
          if (find.text('open').evaluate().isNotEmpty) {
            await tester.tap(find.text('open'));
            await tester.pumpAndSettle();
          }

          expect(find.text(screen.sees), findsWidgets);
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}
