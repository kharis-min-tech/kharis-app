import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_test/flutter_test.dart';

import 'package:kharis_app/features/onboarding/data/firebase_auth_repository.dart';

/// Coverage for the profile-save contract: accounts whose `users/{uid}` doc
/// never got created (the app pointed at a dead Firebase project for a while,
/// so many real accounts have no profile doc) must still be able to save —
/// the repository upserts instead of blindly merging into a missing doc,
/// which the Firestore rules reject as a role-less create. On update the
/// client must never send `role`; the rules pin it and an admin would
/// otherwise be demoted by their own profile edit.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const uid = 'member-1';

  FirebaseAuthRepository repoFor(
    FakeFirebaseFirestore db, {
    bool isAnonymous = false,
  }) {
    return FirebaseAuthRepository(
      auth: _FakeFirebaseAuth(
        _FakeFirebaseUser(
          uid: uid,
          email: isAnonymous ? null : 'member@kharis.org',
          displayName: 'Member',
          isAnonymous: isAnonymous,
        ),
      ),
      firestore: db,
    );
  }

  group('updateProfile', () {
    test('creates the profile doc with a safe role when it is missing',
        () async {
      final db = FakeFirebaseFirestore();
      final repo = repoFor(db);

      final user = await repo.updateProfile(
        displayName: 'Ayo',
        branch: 'London',
      );

      final snap = await db.collection('users').doc(uid).get();
      expect(snap.exists, isTrue);
      final data = snap.data()!;
      expect(data['displayName'], 'Ayo');
      expect(data['branch'], 'London');
      expect(data['role'], 'member');
      expect(data['email'], 'member@kharis.org');
      expect(data['createdAt'], isNotNull);
      expect(user.displayName, 'Ayo');
      expect(user.branch, 'London');
    });

    test('creates a guest-role doc for anonymous users', () async {
      final db = FakeFirebaseFirestore();
      final repo = repoFor(db, isAnonymous: true);

      await repo.updateProfile(branch: 'Manchester');

      final data = (await db.collection('users').doc(uid).get()).data()!;
      expect(data['role'], 'guest');
      expect(data['branch'], 'Manchester');
    });

    test('merges into an existing doc without touching other fields',
        () async {
      final db = FakeFirebaseFirestore();
      await db.collection('users').doc(uid).set({
        'email': 'member@kharis.org',
        'displayName': 'Old Name',
        'role': 'new_here',
        'branch': 'London',
        'photoUrl': null,
        'notificationPrefs': {'events': true},
      });
      final repo = repoFor(db);

      await repo.updateProfile(displayName: 'New Name');

      final data = (await db.collection('users').doc(uid).get()).data()!;
      expect(data['displayName'], 'New Name');
      // Untouched fields survive the merge.
      expect(data['branch'], 'London');
      expect(data['notificationPrefs'], {'events': true});
      // Role is never sent on update — an unusual role must survive as-is.
      expect(data['role'], 'new_here');
    });

    test('never writes role on update, even for admins', () async {
      final db = FakeFirebaseFirestore();
      await db.collection('users').doc(uid).set({
        'email': 'member@kharis.org',
        'displayName': 'Admin',
        'role': 'admin',
      });
      final repo = repoFor(db);

      await repo.updateProfile(
        displayName: 'Still Admin',
        branch: 'London',
        photoUrl: 'https://example.com/a.png',
      );

      final data = (await db.collection('users').doc(uid).get()).data()!;
      expect(data['role'], 'admin');
      expect(data['displayName'], 'Still Admin');
      expect(data['photoUrl'], 'https://example.com/a.png');
    });
  });

  group('updateNotificationPrefs', () {
    test('creates the profile doc with a safe role when it is missing',
        () async {
      final db = FakeFirebaseFirestore();
      final repo = repoFor(db);

      await repo.updateNotificationPrefs({'events': false});

      final data = (await db.collection('users').doc(uid).get()).data()!;
      expect(data['role'], 'member');
      expect(data['notificationPrefs'], {'events': false});
    });

    test('merges prefs into an existing doc without touching role', () async {
      final db = FakeFirebaseFirestore();
      await db.collection('users').doc(uid).set({
        'displayName': 'Member',
        'role': 'new_here',
      });
      final repo = repoFor(db);

      await repo.updateNotificationPrefs({'events': true});

      final data = (await db.collection('users').doc(uid).get()).data()!;
      expect(data['role'], 'new_here');
      expect(data['notificationPrefs'], {'events': true});
    });
  });
}

// ── Fakes ─────────────────────────────────────────────────────────────────────

class _FakeFirebaseAuth extends Fake implements fb.FirebaseAuth {
  _FakeFirebaseAuth(this._user);
  final fb.User? _user;

  @override
  fb.User? get currentUser => _user;
}

class _FakeFirebaseUser extends Fake implements fb.User {
  _FakeFirebaseUser({
    required this.uid,
    this.email,
    this.displayName,
    this.isAnonymous = false,
  });

  @override
  final String uid;
  @override
  final String? email;
  @override
  final String? displayName;
  @override
  String? get photoURL => null;
  @override
  final bool isAnonymous;

  @override
  Future<void> updateDisplayName(String? displayName) async {}
}
