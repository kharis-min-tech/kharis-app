import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kharis_app/features/onboarding/data/onboarding_repository.dart';
import 'package:kharis_app/features/settings/data/account_deletion.dart';

/// Account deletion must remove everything the member owns in Firestore —
/// profile, notes, playlists (Favourites included) and RSVPs — and nothing
/// that belongs to anyone else.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const uid = 'member-1';
  const other = 'member-2';

  Future<FakeFirebaseFirestore> seeded() async {
    final db = FakeFirebaseFirestore();
    final now = Timestamp.now();
    for (final id in [uid, other]) {
      final user = db.collection('users').doc(id);
      await user.set({'role': 'member', 'displayName': id});
      await user.collection('notes').doc('n1').set({
        'body': 'note',
        'updatedAt': now,
      });
      await user.collection('notes').doc('n2').set({
        'body': 'note',
        'updatedAt': now,
      });
      await user.collection('playlists').doc('favorites').set({
        'name': 'Favourites',
        'sermonIds': ['s1'],
        'createdAt': now,
        'updatedAt': now,
      });
      await user.collection('playlists').doc('p1').set({
        'name': 'Sunday',
        'sermonIds': <String>[],
        'createdAt': now,
        'updatedAt': now,
      });
      for (final event in ['e1', 'e2']) {
        await db.collection('rsvps').doc('${id}_$event').set({
          'userId': id,
          'eventId': event,
        });
      }
    }
    return db;
  }

  Future<int> count(Query<Map<String, dynamic>> q) async =>
      (await q.get()).docs.length;

  test('deletes the member\'s profile, notes, playlists and RSVPs', () async {
    final db = await seeded();

    await AccountDataRepository(db).deleteUserData(uid);

    final user = db.collection('users').doc(uid);
    expect((await user.get()).exists, isFalse);
    expect(await count(user.collection('notes')), 0);
    expect(await count(user.collection('playlists')), 0);
    expect(
      await count(db.collection('rsvps').where('userId', isEqualTo: uid)),
      0,
    );
  });

  test('leaves other members\' data untouched', () async {
    final db = await seeded();

    await AccountDataRepository(db).deleteUserData(uid);

    final user = db.collection('users').doc(other);
    expect((await user.get()).exists, isTrue);
    expect(await count(user.collection('notes')), 2);
    expect(await count(user.collection('playlists')), 2);
    expect(
      await count(db.collection('rsvps').where('userId', isEqualTo: other)),
      2,
    );
  });

  test('is safe to run again after a partial deletion', () async {
    final db = await seeded();
    final repo = AccountDataRepository(db);

    await repo.deleteUserData(uid);
    await repo.deleteUserData(uid);

    expect((await db.collection('users').doc(uid).get()).exists, isFalse);
    expect((await db.collection('users').doc(other).get()).exists, isTrue);
  });

  test(
    'clearing local data empties notes and the saved role and branch',
    () async {
      final dir = await Directory.systemTemp.createTemp('kharis_account_');
      Hive.init(dir.path);
      addTearDown(() async {
        await Hive.close();
        await dir.delete(recursive: true);
      });
      final box = await Hive.openBox<dynamic>('notes_test');
      await box.put('n1', '{"id":"n1"}');
      SharedPreferences.setMockInitialValues({
        'onboarding_completed': true,
        'onboarding_role': 'member',
        'onboarding_branch': 'London',
        'onboarding_branch_sync_pending': true,
        'theme_mode': 'dark',
      });
      final prefs = await SharedPreferences.getInstance();
      final onboarding = OnboardingRepository(prefs);

      await LocalAccountData(box, onboarding).clear();

      expect(box.isEmpty, isTrue);
      expect(onboarding.isCompleted, isFalse);
      expect(onboarding.selectedRole, isNull);
      expect(onboarding.hasBranchChoice, isFalse);
      expect(onboarding.branchSyncPending, isFalse);
      // Device settings that are not personal data stay.
      expect(prefs.getString('theme_mode'), 'dark');
    },
  );
}
