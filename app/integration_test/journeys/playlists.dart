import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kharis_app/core/utils/media_url.dart';
import 'package:kharis_app/features/messages/presentation/widgets/sermon_list_item.dart';
import 'package:kharis_app/features/playlists/presentation/screens/favorites_screen.dart';
import 'package:kharis_app/features/playlists/presentation/screens/playlist_detail_screen.dart';
import 'package:kharis_app/features/playlists/presentation/screens/playlists_screen.dart';
import 'package:kharis_app/features/playlists/presentation/widgets/add_to_playlist_sheet.dart';
import 'package:kharis_app/features/playlists/presentation/widgets/playlist_card.dart';
import 'package:kharis_app/features/playlists/providers/playlist_providers.dart';
import 'package:kharis_app/shared/models/sermon.dart';
import 'package:kharis_app/shared/providers/sermon_provider.dart';

import '../support/actions.dart';
import '../support/harness.dart';
import '../support/live_data.dart';

/// Brings [s]'s row on screen through search and returns its finder.
Future<Finder> _findRow(Journey j, Sermon s) async {
  final t = j.tester;
  await j.resetTo('/home');
  await openMessagesReset(j);
  final field = find.byType(TextField).first;
  await t.tap(field, warnIfMissed: false);
  await t.enterText(field, s.title);
  final row = find.byKey(ValueKey(s.id));
  await pumpUntilFound(
    t,
    row,
    timeout: const Duration(seconds: 30),
    reason: 'row for "${s.title}"',
  );
  FocusManager.instance.primaryFocus?.unfocus();
  await pumpFor(t, const Duration(milliseconds: 600));
  await ensureCentred(t, row);
  return row;
}

Future<void> _openPlaylists(Journey j) async {
  final t = j.tester;
  if (find.byType(PlaylistsScreen).evaluate().isNotEmpty) return;
  await openMoreRow(t, 'My playlists');
  await pumpUntilFound(t, find.byType(PlaylistsScreen));
}

/// (f) Playlists and Favourites: create, add three messages, the mosaic
/// shows their artwork, rename, remove one, delete; like a message, find it
/// in Favourites, unlike it.
Future<void> playlistsJourney(Journey j) async {
  final t = j.tester;
  final r = seeded(effectiveSeed, 'playlists');
  await j.launch();
  await openMessagesReset(j);
  j.check(await waitArchiveHydrated(j), 'archive loaded');

  // Three messages, distinct artwork where the library has it.
  // Only messages search finds under the same id: the archive and the
  // search source can carry one message under different ids.
  final searchable = {
    for (final s in j.c.read(sermonsProvider).valueOrNull ?? const <Sermon>[])
      s.id,
  };
  final pool =
      j.c
          .read(sermonLibraryProvider)
          .sermons
          .take(300)
          .where((s) => searchable.contains(s.id))
          .toList()
        ..shuffle(r);
  j.check(pool.length >= 3, 'at least 3 searchable messages (${pool.length})');
  final chosen = <Sermon>[];
  final arts = <String>{};
  for (final s in pool) {
    final art = usableMediaUrl(s.artworkUrl);
    if (art != null && arts.add(art)) chosen.add(s);
    if (chosen.length == 3) break;
  }
  for (final s in pool) {
    if (chosen.length == 3) break;
    if (!chosen.contains(s)) chosen.add(s);
  }
  j.note(
    'messages for the playlist: ${chosen.map((s) => s.title).toList()} '
    '(${arts.length} with distinct artwork)',
  );

  // ── Create ───────────────────────────────────────────────────────────────
  final name = 'E2E ${DateTime.now().millisecondsSinceEpoch % 1000000}';
  await _openPlaylists(j);
  await pumpUntil(
    t,
    () => j.c.read(playlistsProvider).hasValue,
    timeout: const Duration(seconds: 30),
  );
  await t.tap(find.byKey(const ValueKey('playlists-new')), warnIfMissed: false);
  await pumpUntilFound(t, find.byType(AlertDialog));
  await t.tap(
    find.descendant(
      of: find.byType(AlertDialog),
      matching: find.text('Create'),
    ),
    warnIfMissed: false,
  );
  await pumpFor(t, const Duration(milliseconds: 500));
  j.check(
    find.text('Give your playlist a name').evaluate().isNotEmpty,
    'empty playlist name is refused',
  );
  await t.enterText(
    find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    ),
    name,
  );
  await t.tap(
    find.descendant(
      of: find.byType(AlertDialog),
      matching: find.text('Create'),
    ),
    warnIfMissed: false,
  );
  await pumpUntilFound(
    t,
    find.byType(PlaylistDetailScreen),
    reason: 'new playlist opens',
  );
  final created = await pumpUntil(
    t,
    () => (j.c.read(playlistsProvider).valueOrNull ?? const []).any(
      (p) => p.name == name,
    ),
    timeout: const Duration(seconds: 20),
  );
  j.check(created, 'playlist "$name" created');
  if (!created) return;
  final id = j.c
      .read(playlistsProvider)
      .valueOrNull!
      .firstWhere((p) => p.name == name)
      .id;
  await j.shot('playlist-created');

  try {
    // ── Add three messages from their ⋮ menu ───────────────────────────────
    for (final s in chosen) {
      final row = await _findRow(j, s);
      await t.tap(
        find.descendant(
          of: row,
          matching: find.byIcon(Icons.more_vert_rounded),
        ),
        warnIfMissed: false,
      );
      final sheet = find.byType(AddToPlaylistSheet);
      final entry = find.descendant(of: sheet, matching: find.text(name));
      await pumpUntilFound(t, entry, reason: 'playlist in the add sheet');
      await t.tap(entry, warnIfMissed: false);
      j.check(
        await pumpUntil(
          t,
          () => (j.c.read(playlistByIdProvider(id))?.sermonIds ?? const [])
              .contains(s.id),
          timeout: const Duration(seconds: 20),
        ),
        '"${s.title}" added',
      );
      Navigator.of(t.element(sheet)).pop();
      await pumpFor(t, const Duration(milliseconds: 600));
    }
    await clearMessagesSearch(t);

    // ── Mosaic ─────────────────────────────────────────────────────────────
    await _openPlaylists(j);
    final card = find.ancestor(
      of: find.text(name),
      matching: find.byType(PlaylistCard),
    );
    await pumpUntilFound(t, card, reason: 'playlist card');
    final mosaic = find.descendant(
      of: card.first,
      matching: find.byType(PlaylistMosaic),
    );
    final wantArt = {for (final s in chosen) ?usableMediaUrl(s.artworkUrl)};
    j.check(
      await pumpUntil(
        t,
        () =>
            mosaic.evaluate().isNotEmpty &&
            t
                .widget<PlaylistMosaic>(mosaic.first)
                .urls
                .toSet()
                .containsAll(wantArt) &&
            t.widget<PlaylistMosaic>(mosaic.first).urls.length ==
                wantArt.length,
        timeout: const Duration(seconds: 30),
      ),
      'mosaic shows the ${wantArt.length} message artworks '
      '(got ${mosaic.evaluate().isEmpty ? null : t.widget<PlaylistMosaic>(mosaic.first).urls})',
    );
    if (wantArt.isNotEmpty) {
      j.check(
        find
                .descendant(of: mosaic.first, matching: find.byType(Image))
                .evaluate()
                .length >=
            wantArt.length,
        'mosaic paints one image per artwork',
      );
    }
    await j.shot('mosaic');

    // ── Rename ─────────────────────────────────────────────────────────────
    await t.tap(find.text(name).first, warnIfMissed: false);
    await pumpUntilFound(t, find.byType(PlaylistDetailScreen));
    final rows = find.descendant(
      of: find.byType(PlaylistDetailScreen),
      matching: find.byType(SermonListItem),
    );
    j.check(
      await pumpUntil(
        t,
        () => rows.evaluate().length == 3,
        timeout: const Duration(seconds: 20),
      ),
      'playlist lists 3 messages (got ${rows.evaluate().length})',
    );
    final renamed = '$name renamed';
    await t.tap(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.byIcon(Icons.more_vert_rounded),
      ),
      warnIfMissed: false,
    );
    await pumpUntilFound(t, find.text('Rename'));
    await t.tap(find.text('Rename'), warnIfMissed: false);
    await pumpUntilFound(t, find.text('Rename playlist'));
    await t.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      renamed,
    );
    await t.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Save'),
      ),
      warnIfMissed: false,
    );
    j.check(
      await pumpUntil(
        t,
        () => find
            .descendant(
              of: find.byType(PlaylistDetailScreen),
              matching: find.text(renamed),
            )
            .evaluate()
            .isNotEmpty,
        timeout: const Duration(seconds: 15),
      ),
      'rename shows "$renamed"',
    );

    // ── Remove one ─────────────────────────────────────────────────────────
    final removed = t.widget<SermonListItem>(rows.first).title;
    await t.tap(
      find.descendant(
        of: rows.first,
        matching: find.byIcon(Icons.more_vert_rounded),
      ),
      warnIfMissed: false,
    );
    await pumpUntilFound(t, find.text('Remove from this playlist'));
    await t.tap(find.text('Remove from this playlist'), warnIfMissed: false);
    j.check(
      await pumpUntil(
        t,
        () =>
            rows.evaluate().length == 2 &&
            find.text('2 messages').evaluate().isNotEmpty,
        timeout: const Duration(seconds: 15),
      ),
      'removing "$removed" leaves 2 messages',
    );
    await j.shot('renamed-removed');
  } catch (e, st) {
    j.check(
      false,
      'aborted: ${'$e'.split('\n').first} @ ${'$st'.split('\n').take(3).join(' <- ')}',
    );
    await j.shot('ABORTED-before-delete');
  }

  // ── Delete (runs after a failure above too, so nothing is left behind) ──
  try {
    if (find.byType(PlaylistDetailScreen).evaluate().isEmpty) {
      await j.resetTo('/playlists/$id');
      await pumpUntilFound(t, find.byType(PlaylistDetailScreen));
    }
    await t.tap(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.byIcon(Icons.more_vert_rounded),
      ),
      warnIfMissed: false,
    );
    await pumpUntilFound(t, find.text('Delete playlist'));
    await t.tap(find.text('Delete playlist'), warnIfMissed: false);
    await pumpUntilFound(t, find.text('Delete playlist?'));
    await t.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Delete'),
      ),
      warnIfMissed: false,
    );
    j.check(
      await pumpUntil(
        t,
        () => !(j.c.read(playlistsProvider).valueOrNull ?? const []).any(
          (p) => p.id == id,
        ),
        timeout: const Duration(seconds: 20),
      ),
      'playlist deleted',
    );
    await pumpFor(t, const Duration(seconds: 1));
    j.check(
      find.textContaining(name).evaluate().isEmpty,
      'deleted playlist gone from My playlists',
    );
  } catch (e) {
    j.check(
      false,
      'deleting the playlist from its menu failed: ${'$e'.split('\n').first}',
    );
    j.c.read(playlistRepositoryProvider).deletePlaylist(id);
    j.note('test playlist $id removed through the repository instead');
  }

  // ── Favourites: like, listed, unlike ─────────────────────────────────────
  final fav = chosen.first;
  final row = await _findRow(j, fav);
  await t.tap(row, warnIfMissed: false);
  await pumpUntilFound(t, player);
  final like = inPlayer(find.byTooltip('Add to Favourites'));
  final unlike = inPlayer(find.byTooltip('Remove from Favourites'));
  await pumpUntil(
    t,
    () => like.evaluate().isNotEmpty || unlike.evaluate().isNotEmpty,
  );
  if (unlike.evaluate().isNotEmpty) {
    j.note('"${fav.title}" was already a favourite; unliking first');
    await t.tap(unlike.first, warnIfMissed: false);
    await pumpUntil(
      t,
      () => like.evaluate().isNotEmpty,
      timeout: const Duration(seconds: 15),
    );
  }
  await t.tap(like.first, warnIfMissed: false);
  j.check(
    await pumpUntil(
      t,
      () => unlike.evaluate().isNotEmpty,
      timeout: const Duration(seconds: 15),
    ),
    'heart fills after liking "${fav.title}"',
  );
  await j.shot('liked');
  await closePlayer(t);
  await clearMessagesSearch(t);
  await openMoreRow(t, 'Favourites');
  await pumpUntilFound(t, find.byType(FavoritesScreen));
  final listed = find.descendant(
    of: find.byType(FavoritesScreen),
    matching: find.text(fav.title),
  );
  j.check(
    await pumpUntil(
      t,
      () => listed.evaluate().isNotEmpty,
      timeout: const Duration(seconds: 20),
    ),
    'Favourites lists "${fav.title}"',
  );
  await j.shot('favourites');
  await tapBack(t);
  // Reopen the message the way it was liked (from its row).
  final again = await _findRow(j, fav);
  await t.tap(again, warnIfMissed: false);
  await pumpUntilFound(t, player);
  await pumpUntilFound(t, unlike);
  await t.tap(unlike.first, warnIfMissed: false);
  j.check(
    await pumpUntil(
      t,
      () => like.evaluate().isNotEmpty,
      timeout: const Duration(seconds: 15),
    ),
    'heart empties after unliking',
  );
  await closePlayer(t);
  await openMoreRow(t, 'Favourites');
  await pumpUntilFound(t, find.byType(FavoritesScreen));
  j.check(
    await pumpUntil(
      t,
      () => listed.evaluate().isEmpty,
      timeout: const Duration(seconds: 20),
    ),
    'Favourites no longer lists "${fav.title}"',
  );
  final favs = j.c.read(favoritesProvider).valueOrNull;
  j.check(
    favs == null ||
        !favs.sermonIds.any((id) => id == fav.id || id.endsWith(fav.id)),
    'favourite removed from the account',
  );
}
