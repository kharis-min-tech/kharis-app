import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kharis_app/features/notes/data/note_repository.dart';
import 'package:kharis_app/features/notes/data/notepad.dart';
import 'package:kharis_app/features/playlists/data/playlist_repository.dart';
import 'package:kharis_app/features/playlists/providers/playlist_providers.dart';
import 'package:kharis_app/shared/models/sermon.dart';
import 'package:kharis_app/shared/providers/clock_provider.dart';
import 'package:kharis_app/shared/providers/downloads_provider.dart';
import 'package:kharis_app/shared/providers/notes_provider.dart';
import 'package:kharis_app/shared/providers/streaks_provider.dart';

Playlist _playlist(String id, int messages) => Playlist(
  id: id,
  name: 'Collection $id',
  sermonIds: [for (var i = 0; i < messages; i++) 'sermon-$id-$i'],
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

/// The on-device and account data the More tab reads for its streak badges
/// and tile counts, so a test pumping `SettingsScreen` needs no cache,
/// network or files. Counts default to nothing saved and no streak.
List<Override> moreScreenOverrides({
  int notes = 0,
  int downloads = 0,
  int collections = 0,
  int favourites = 0,
  int readingStreak = 0,
  int messagesStreak = 0,
  DateTime? now,
}) => [
  notebookProvider.overrideWithValue(
    AsyncData(
      groupNotebook([
        for (var i = 0; i < notes; i++)
          Note(
            id: 'note-$i',
            body: 'Note $i',
            createdAt: DateTime(2026),
            updatedAt: DateTime(2026),
          ),
      ], const <Sermon>[]),
    ),
  ),
  downloadsProvider.overrideWithValue([
    for (var i = 0; i < downloads; i++)
      DownloadedMessage(
        sermon: Sermon(
          id: 'saved-$i',
          title: 'Saved $i',
          speaker: 'Pastor A',
          audioUrl: 'https://audio.example/saved-$i.mp3',
        ),
        fileName: 'saved-$i.mp3',
        bytes: 1024,
        savedAt: DateTime(2026),
      ),
  ]),
  playlistsProvider.overrideWith(
    (ref) => Stream.value([
      for (var i = 0; i < collections; i++) _playlist('c$i', 1),
    ]),
  ),
  favoritesProvider.overrideWith(
    (ref) => Stream.value(
      favourites == 0 ? null : _playlist('favourites', favourites),
    ),
  ),
  streaksProvider.overrideWithValue(
    Streaks(
      readToday: readingStreak > 0,
      readingStreak: readingStreak,
      listenedToday: messagesStreak > 0,
      messagesStreak: messagesStreak,
      weekRead: const [false, false, false, false, false, false, false],
      todayIndex: 0,
    ),
  ),
  if (now != null) clockProvider.overrideWithValue(() => now),
];
