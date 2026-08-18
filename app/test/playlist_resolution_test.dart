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

    final container = ProviderContainer(
      overrides: [
        firestoreProvider.overrideWithValue(db),
        currentUserProvider.overrideWith((ref) => Stream.value(member)),
        sermonsProvider.overrideWith(
          (ref) async => [_sermon('s1', 'First'), _sermon('s2', 'Second')],
        ),
      ],
    );
    addTearDown(container.dispose);
    container.listen(playlistsProvider, (_, _) {});
    container.listen(playlistSermonsProvider('p1'), (_, _) {});

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
