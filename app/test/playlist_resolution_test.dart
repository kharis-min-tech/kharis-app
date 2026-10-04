import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kharis_app/features/playlists/providers/playlist_providers.dart';
import 'package:kharis_app/shared/models/sermon.dart';
import 'package:kharis_app/shared/models/user.dart';
import 'package:kharis_app/shared/providers/auth_provider.dart';
import 'package:kharis_app/shared/providers/branch_provider.dart';
import 'package:kharis_app/shared/providers/sermon_provider.dart';

import 'support/fake_sermon_repository.dart';

Sermon _sermon(String id, String title) => Sermon(
  id: id,
  title: title,
  speaker: 'Pastor A',
  audioUrl: 'https://audio.example/$id.mp3',
);

/// A playlist's sermon ids are resolved against the loaded catalogue; ids
/// whose message has since left the library (dangling) are skipped without
/// breaking the playlist or its order.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const uid = 'member-1';
  final member = User(
    id: uid,
    email: 'member@kharis.org',
    displayName: 'Member',
    role: 'member',
    createdAt: DateTime(2024),
  );

  Future<void> until(bool Function() check) async {
    for (var i = 0; i < 200 && !check(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    expect(check(), isTrue, reason: 'condition never became true');
  }

  test('dangling sermon ids are skipped, order preserved', () async {
    final db = FakeFirebaseFirestore();
    final now = Timestamp.fromDate(DateTime(2026, 8, 1));
    await db.collection('users').doc(uid).collection('playlists').doc('p1').set(
      {
        'name': 'Deep Roots',
        // 'ghost' was removed from the catalogue after being saved.
        'sermonIds': ['s2', 'ghost', 's1'],
        'createdAt': now,
        'updatedAt': now,
      },
    );

    final repo = FakePagedSermonRepository([
      [_sermon('s1', 'First'), _sermon('s2', 'Second')],
    ])..holdFirstPage = Completer<void>();
    final container = ProviderContainer(
      overrides: [
        firestoreProvider.overrideWithValue(db),
        currentUserProvider.overrideWith((ref) => Stream.value(member)),
        sermonRepositoryProvider.overrideWithValue(repo),
        sermonArchiveAutoHydrateProvider.overrideWithValue(false),
        videosProvider.overrideWith((ref) async => const <Sermon>[]),
      ],
    );
    addTearDown(container.dispose);
    container.listen(playlistsProvider, (_, _) {});
    container.listen(playlistResolutionProvider('p1'), (_, _) {});

    // Before the archive answers, nothing is "missing": all three ids are
    // still pending, so the UI must not say "no longer in the library".
    await until(
      () => container.read(playlistResolutionProvider('p1')).pending == 3,
    );
    expect(container.read(playlistResolutionProvider('p1')).missing, 0);

    repo.holdFirstPage!.complete();

    await until(() {
      final resolved = container.read(playlistSermonsProvider('p1'));
      return resolved.length == 2;
    });

    // Playlist order kept; the dangling id is silently skipped.
    final resolved = container.read(playlistSermonsProvider('p1'));
    expect(resolved.map((s) => s.id), ['s2', 's1']);

    // The raw playlist still remembers all three, so the UI can report the
    // one that went missing rather than silently shrinking the count.
    final playlist = container.read(playlistByIdProvider('p1'));
    expect(playlist, isNotNull);
    expect(playlist!.sermonIds, hasLength(3));
    expect(playlist.sermonIds.length - resolved.length, 1);

    // Once the archive is complete and the CMS has no such doc, the ghost
    // id is reported as missing (not pending forever).
    await until(
      () => container.read(playlistResolutionProvider('p1')).missing == 1,
    );
    expect(container.read(playlistResolutionProvider('p1')).pending, 0);
  });

  test('unknown playlist id resolves to null / empty, not a crash', () async {
    final db = FakeFirebaseFirestore();
    final container = ProviderContainer(
      overrides: [
        firestoreProvider.overrideWithValue(db),
        currentUserProvider.overrideWith((ref) => Stream.value(member)),
        sermonsProvider.overrideWith((ref) async => [_sermon('s1', 'First')]),
      ],
    );
    addTearDown(container.dispose);
    container.listen(playlistsProvider, (_, _) {});

    await until(() => container.read(playlistsProvider).valueOrNull != null);
    expect(container.read(playlistByIdProvider('missing')), isNull);
    expect(container.read(playlistSermonsProvider('missing')), isEmpty);
  });
}
