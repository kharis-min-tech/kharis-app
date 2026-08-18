import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kharis_app/features/playlists/data/playlist_repository.dart';
import 'package:kharis_app/features/playlists/providers/playlist_providers.dart';
import 'package:kharis_app/shared/models/user.dart';
import 'package:kharis_app/shared/providers/auth_provider.dart';
import 'package:kharis_app/shared/providers/branch_provider.dart';

/// Coverage for the playlist-persistence contract: playlists are the member's
/// own, live in Firestore under their uid (signed-in AND anonymous guests),
/// and survive an app relaunch. Writes are optimistic, so the tests poll the
/// backing store rather than awaiting fire-and-forget commits.
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
  final guest = User(
    id: 'guest-7',
    email: '',
    displayName: 'Guest',
    role: 'guest',
    createdAt: DateTime(2026),
  );

  ProviderContainer containerFor(
    FakeFirebaseFirestore db, {
    User? user,
    bool autoDispose = true,
  }) {
    final container = ProviderContainer(
      overrides: [
        firestoreProvider.overrideWithValue(db),
        currentUserProvider.overrideWith((ref) => Stream.value(user)),
      ],
    );
    if (autoDispose) addTearDown(container.dispose);
    return container;
  }

  /// Polls until [check] passes; playlist writes are fire-and-forget.
  Future<void> until(bool Function() check) async {
    for (var i = 0; i < 200 && !check(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    expect(check(), isTrue, reason: 'condition never became true');
  }

  List<Playlist>? playlistsOf(ProviderContainer c) =>
      c.read(playlistsProvider).valueOrNull;

  /// The repository once auth has resolved. [currentUserProvider] emits
  /// asynchronously, and reading the repo before that yields the signed-out
  /// (write-refusing) instance.
  Future<PlaylistRepository> signedInRepo(ProviderContainer c) async {
    await until(() => c.read(currentUserProvider).valueOrNull != null);
    return c.read(playlistRepositoryProvider);
  }

  test('create persists a named playlist under the owner', () async {
    final db = FakeFirebaseFirestore();
    final container = containerFor(db, user: member);
    container.listen(playlistsProvider, (_, _) {});
    final repo = await signedInRepo(container);

    final id = repo.create('  Morning Drive  ');

    await until(() => playlistsOf(container)?.length == 1);
    final playlist = playlistsOf(container)!.single;
    expect(playlist.id, id);
    expect(playlist.name, 'Morning Drive'); // trimmed
    expect(playlist.sermonIds, isEmpty);

    final snap = await db
        .collection('users')
        .doc(uid)
        .collection('playlists')
        .get();
    expect(snap.docs.single.id, id);
    expect(snap.docs.single.data()['name'], 'Morning Drive');
    expect(snap.docs.single.data()['sermonIds'], isEmpty);
  });

  test(
    'addSermon keeps order, dedupes, and removeSermon takes one out',
    () async {
      final db = FakeFirebaseFirestore();
      final container = containerFor(db, user: member);
      container.listen(playlistsProvider, (_, _) {});
      final repo = await signedInRepo(container);

      final id = repo.create('Faith Builders');
      repo.addSermon(id, 'sermon-a');
      repo.addSermon(id, 'sermon-b');
      repo.addSermon(id, 'sermon-a'); // arrayUnion: no duplicate

      await until(() {
        final lists = playlistsOf(container);
        return lists != null &&
            lists.length == 1 &&
            lists.single.sermonIds.length == 2;
      });
      expect(playlistsOf(container)!.single.sermonIds, [
        'sermon-a',
        'sermon-b',
      ]);

      repo.removeSermon(id, 'sermon-a');
      await until(() => playlistsOf(container)?.single.sermonIds.length == 1);
      expect(playlistsOf(container)!.single.sermonIds, ['sermon-b']);
    },
  );

  test('rename updates the name; delete removes the playlist', () async {
    final db = FakeFirebaseFirestore();
    final container = containerFor(db, user: member);
    container.listen(playlistsProvider, (_, _) {});
    final repo = await signedInRepo(container);

    final id = repo.create('Old Name');
    await until(() => playlistsOf(container)?.length == 1);

    repo.rename(id, 'New Name');
    await until(() => playlistsOf(container)?.single.name == 'New Name');

    repo.deletePlaylist(id);
    await until(() => playlistsOf(container)?.isEmpty ?? false);
    final snap = await db
        .collection('users')
        .doc(uid)
        .collection('playlists')
        .get();
    expect(snap.docs, isEmpty);
  });

  test(
    'playlists survive an app relaunch (fresh container, same backend)',
    () async {
      final db = FakeFirebaseFirestore();
      // Disposed mid-test to simulate the shutdown; opts out of the
      // teardown dispose so it is not disposed twice.
      final first = containerFor(db, user: member, autoDispose: false);
      first.listen(playlistsProvider, (_, _) {});
      final repo = await signedInRepo(first);
      final id = repo.create('Sunday Drive');
      repo.addSermon(id, 'sermon-a');
      await until(() {
        final lists = playlistsOf(first);
        return lists != null &&
            lists.length == 1 &&
            lists.single.sermonIds.length == 1;
      });
      first.dispose();

      // "Relaunch": a brand-new container over the same Firestore.
      final second = containerFor(db, user: member);
      second.listen(playlistsProvider, (_, _) {});
      await until(() => playlistsOf(second)?.length == 1);
      final playlist = playlistsOf(second)!.single;
      expect(playlist.name, 'Sunday Drive');
      expect(playlist.sermonIds, ['sermon-a']);
    },
  );

  test(
    'anonymous guests get the same persistence under their own uid',
    () async {
      final db = FakeFirebaseFirestore();
      final container = containerFor(db, user: guest);
      container.listen(playlistsProvider, (_, _) {});
      final repo = await signedInRepo(container);

      expect(repo.hasUser, isTrue);
      repo.create('Guest Picks');

      await until(() => playlistsOf(container)?.length == 1);
      final snap = await db
          .collection('users')
          .doc('guest-7')
          .collection('playlists')
          .get();
      expect(snap.docs.single.data()['name'], 'Guest Picks');
    },
  );

  test('signed out: stream is empty and writes refuse loudly', () async {
    final db = FakeFirebaseFirestore();
    final container = containerFor(db);
    container.listen(playlistsProvider, (_, _) {});
    final repo = container.read(playlistRepositoryProvider);

    expect(repo.hasUser, isFalse);
    await until(() => playlistsOf(container) != null);
    expect(playlistsOf(container), isEmpty);
    expect(() => repo.create('Nope'), throwsStateError);
    expect(() => repo.addSermon('p1', 's1'), throwsStateError);
  });

  test('name validation mirrors the Firestore rules (1..80 after trim)', () {
    expect(() => PlaylistRepository.normalizeName(''), throwsArgumentError);
    expect(() => PlaylistRepository.normalizeName('   '), throwsArgumentError);
    expect(
      () => PlaylistRepository.normalizeName('x' * 81),
      throwsArgumentError,
    );
    expect(PlaylistRepository.normalizeName('x' * 80), 'x' * 80);
    expect(PlaylistRepository.normalizeName('  ok  '), 'ok');
  });
}
