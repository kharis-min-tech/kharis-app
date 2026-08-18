import 'dart:convert';
import 'dart:io';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:kharis_app/features/notes/data/note_repository.dart';
import 'package:kharis_app/features/notes/data/note_timeline_key.dart';
import 'package:kharis_app/shared/models/sermon.dart';
import 'package:kharis_app/shared/models/user.dart';
import 'package:kharis_app/shared/providers/auth_provider.dart';
import 'package:kharis_app/shared/providers/branch_provider.dart';
import 'package:kharis_app/shared/providers/notes_provider.dart';
import 'package:kharis_app/shared/providers/sermon_provider.dart';

/// Coverage for the note-persistence contract the product owner asked for:
/// notes must survive a reinstall (so they cannot live only in Hive), notes
/// already on the device must be carried over rather than dropped, and a note
/// taken during playback must remember which message and where in it.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const uid = 'member-1';
  late Directory hiveDir;
  late Box<dynamic> box;

  final signedIn = User(
    id: uid,
    email: 'member@kharis.org',
    displayName: 'Member',
    role: 'member',
    createdAt: DateTime(2024),
  );

  setUp(() async {
    hiveDir = Directory.systemTemp.createTempSync('kharis_notes_test');
    Hive.init(hiveDir.path);
    box = await Hive.openBox<dynamic>('notes');
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await Hive.close();
    hiveDir.deleteSync(recursive: true);
  });

  ProviderContainer containerFor(FakeFirebaseFirestore db, {User? user}) {
    final container = ProviderContainer(
      overrides: [
        firestoreProvider.overrideWithValue(db),
        localNoteStoreProvider.overrideWithValue(LocalNoteStore(box)),
        currentUserProvider.overrideWith((ref) => Stream.value(user)),
        // Hermetic: sermonNotesProvider consults the catalogue for legacy
        // note aliases — keep it empty so no network/asset load runs here.
        sermonsProvider.overrideWith((ref) async => const <Sermon>[]),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  /// Polls until [check] passes; the migration upload is fire-and-forget.
  Future<void> until(bool Function() check) async {
    for (var i = 0; i < 200 && !check(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    expect(check(), isTrue, reason: 'condition never became true');
  }

  test('notes already on the device are migrated to Firestore, not dropped',
      () async {
    // A note written by the previous, local-only build: `text` key, epoch ms.
    await box.put(
      'legacy-1',
      jsonEncode({
        'id': 'legacy-1',
        'sermonId': 'sermon-a',
        'sermonTitle': 'Faith That Moves',
        'positionMs': 754000,
        'text': 'God is faithful even here',
        'createdAt': DateTime(2025, 3, 1).millisecondsSinceEpoch,
        'updatedAt': DateTime(2025, 3, 1).millisecondsSinceEpoch,
      }),
    );

    final db = FakeFirebaseFirestore();
    final container = containerFor(db, user: signedIn);
    container.listen(notesProvider, (_, _) {});

    late Map<String, dynamic> stored;
    await until(() {
      final notes = container.read(notesProvider).valueOrNull;
      return notes != null && notes.length == 1;
    });
    final snap = await db.collection('users').doc(uid).collection('notes').get();
    expect(snap.docs, hasLength(1));
    stored = snap.docs.single.data();

    expect(snap.docs.single.id, 'legacy-1');
    expect(stored['body'], 'God is faithful even here');
    expect(stored['sermonId'], 'sermon-a');
    expect(stored['positionMs'], 754000);

    // Once the upload is acked the local copy is released — and the note is
    // still in the list, served from the cloud.
    await until(() => box.isEmpty);
    expect(container.read(notesProvider).valueOrNull, hasLength(1));
  });

  test('a note captured during playback keeps its sermon and position',
      () async {
    final db = FakeFirebaseFirestore();
    final container = containerFor(db, user: signedIn);
    container.listen(notesProvider, (_, _) {});
    final repo = container.read(notesRepositoryProvider);

    final now = DateTime(2026, 1, 4, 10, 30);
    await repo.upsert(Note(
      id: repo.newId(),
      sermonId: 'sermon-b',
      sermonTitle: 'The Weight of Grace',
      positionMs: 1_265_000,
      body: 'Come back to this illustration',
      createdAt: now,
      updatedAt: now,
    ));

    await until(() {
      final notes = container.read(notesProvider).valueOrNull;
      return notes != null && notes.length == 1;
    });

    final note = container.read(notesProvider).value!.single;
    expect(note.isAnchored, isTrue);
    expect(note.sermonId, 'sermon-b');
    expect(note.positionMs, 1265000);

    // Durable: present in Firestore, so it survives a reinstall.
    final snap = await db.collection('users').doc(uid).collection('notes').get();
    expect(snap.docs.single.data()['positionMs'], 1265000);
  });

  test('signed out, a note is held locally and uploaded on sign-in', () async {
    final db = FakeFirebaseFirestore();
    final guest = containerFor(db);
    guest.listen(notesProvider, (_, _) {});
    final guestRepo = guest.read(notesRepositoryProvider);

    final now = DateTime(2026, 1, 5);
    await guestRepo.upsert(Note(
      id: 'offline-1',
      body: 'Written before signing in',
      createdAt: now,
      updatedAt: now,
    ));

    await until(() {
      final notes = guest.read(notesProvider).valueOrNull;
      return notes != null && notes.length == 1;
    });
    expect(
      (await db.collection('users').doc(uid).collection('notes').get()).docs,
      isEmpty,
    );

    // Same device, now signed in: the note follows the member up.
    final member = containerFor(db, user: signedIn);
    member.listen(notesProvider, (_, _) {});
    await until(() => box.isEmpty);

    final snap = await db.collection('users').doc(uid).collection('notes').get();
    expect(snap.docs.single.id, 'offline-1');
    expect(snap.docs.single.data()['body'], 'Written before signing in');
  });

  test('per-sermon view returns only that sermon, in timeline order', () async {
    final db = FakeFirebaseFirestore();
    final container = containerFor(db, user: signedIn);
    container.listen(notesProvider, (_, _) {});
    final repo = container.read(notesRepositoryProvider);

    final base = DateTime(2026, 2, 1);
    Note note(String id, String? sermonId, int? positionMs, int minute) => Note(
          id: id,
          sermonId: sermonId,
          sermonTitle: sermonId,
          positionMs: positionMs,
          body: 'note $id',
          createdAt: base,
          updatedAt: base.add(Duration(minutes: minute)),
        );

    await repo.upsert(note('late', 'sermon-c', 900000, 1));
    await repo.upsert(note('early', 'sermon-c', 60000, 2));
    await repo.upsert(note('whole', 'sermon-c', null, 3));
    await repo.upsert(note('other', 'sermon-d', 5000, 4));
    await repo.upsert(note('general', null, null, 5));

    await until(() {
      final notes = container.read(notesProvider).valueOrNull;
      return notes != null && notes.length == 5;
    });

    final scoped =
        container.read(sermonNotesProvider(const NoteTimelineKey('sermon-c')));
    expect(scoped.map((n) => n.id), ['whole', 'early', 'late']);

    // The overall notebook still shows everything, newest edit first.
    final all = container.read(notesProvider).value!;
    expect(all.map((n) => n.id).first, 'general');
    expect(all, hasLength(5));
  });
}
