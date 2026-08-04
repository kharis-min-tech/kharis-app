import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kharis_app/shared/models/user.dart';
import 'package:kharis_app/shared/providers/auth_provider.dart';
import 'package:kharis_app/shared/providers/branch_provider.dart';
import 'package:kharis_app/shared/providers/onboarding_provider.dart';

/// Regression coverage for branch scoping.
///
/// The original defect: `currentUserProvider` is bound to Firebase Auth state
/// and only re-emits on sign-in/sign-out, so writing `users/{uid}.branch`
/// never reached any content provider. A user who switched branch kept seeing
/// the old branch's events and announcements until the app was restarted.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const uid = 'user-1';

  User signedIn({String? branch}) => User(
        id: uid,
        email: 'member@kharis.org',
        displayName: 'Member',
        role: 'member',
        branch: branch,
        createdAt: DateTime(2024),
      );

  /// Builds a container and lets auth settle first, mirroring app startup:
  /// content providers are only read once the auth state has resolved.
  Future<ProviderContainer> settled({
    required FakeFirebaseFirestore db,
    required User? user,
    String? localBranch,
    bool branchSyncPending = false,
  }) async {
    SharedPreferences.setMockInitialValues({
      'onboarding_branch': ?localBranch,
      if (branchSyncPending) 'onboarding_branch_sync_pending': true,
    });
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        firestoreProvider.overrideWithValue(db),
        currentUserProvider.overrideWith((ref) => Stream.value(user)),
      ],
    );
    addTearDown(container.dispose);
    await container.read(currentUserProvider.future);
    return container;
  }

  test('a branch switch survives a failed profile write', () async {
    // The reported bug: pick a branch, reopen the app, and it silently reverts.
    // The profile write had failed, so the stale remote value won on relaunch.
    final db = FakeFirebaseFirestore();
    await db.collection('users').doc(uid).set({'branch': 'Bristol'});

    final container = await settled(
      db: db,
      user: signedIn(branch: 'Bristol'),
      localBranch: 'Manchester',
      branchSyncPending: true,
    );

    expect(
      await container.read(currentBranchProvider.future),
      'Manchester',
      reason: 'the unsynced local choice must beat the stale remote branch',
    );
  });

  test('the remote branch wins once the profile write has landed', () async {
    final db = FakeFirebaseFirestore();
    await db.collection('users').doc(uid).set({'branch': 'Bristol'});
    final container = await settled(
      db: db,
      user: signedIn(branch: 'Bristol'),
      localBranch: 'Manchester',
    );
    expect(await container.read(currentBranchProvider.future), 'Bristol');
  });

  test('re-emits when the profile branch changes, without a restart', () async {
    final db = FakeFirebaseFirestore();
    await db.collection('users').doc(uid).set({'branch': 'London'});
    final container =
        await settled(db: db, user: signedIn(branch: 'London'));

    final seen = <String?>[];
    container.listen(
      currentBranchProvider,
      (_, next) {
        if (next.hasValue) seen.add(next.value);
      },
      fireImmediately: true,
    );

    expect(await container.read(currentBranchProvider.future), 'London');

    await db.collection('users').doc(uid).update({'branch': 'Manchester'});
    await Future<void>.delayed(const Duration(milliseconds: 200));

    // The switch must reach subscribers with no restart and no re-login.
    expect(seen.last, 'Manchester');
  });

  test('guests fall back to the persisted onboarding choice', () async {
    final container = await settled(
      db: FakeFirebaseFirestore(),
      user: User(
        id: 'guest-1',
        email: '',
        displayName: 'Guest',
        role: 'guest',
        createdAt: DateTime(2024),
      ),
      localBranch: 'Brighton',
    );

    // Guests never get a Firestore profile write, so the local choice is the
    // only source. Before the fix this resolved to null and the calendar
    // substituted a hardcoded 'Kharis London' that matches no real branch.
    expect(await container.read(currentBranchProvider.future), 'Brighton');
  });

  test('signed-out sessions still scope to the local choice', () async {
    final container = await settled(
      db: FakeFirebaseFirestore(),
      user: null,
      localBranch: 'Accra',
    );
    expect(await container.read(currentBranchProvider.future), 'Accra');
  });

  test('falls back to the local choice when the profile has no branch',
      () async {
    final db = FakeFirebaseFirestore();
    await db.collection('users').doc(uid).set({'displayName': 'Member'});
    final container =
        await settled(db: db, user: signedIn(), localBranch: 'Luton');
    expect(await container.read(currentBranchProvider.future), 'Luton');
  });

  test('treats a blank profile branch as unscoped, not as a branch named ""',
      () async {
    final db = FakeFirebaseFirestore();
    await db.collection('users').doc(uid).set({'branch': '   '});
    final container = await settled(db: db, user: signedIn());
    expect(await container.read(currentBranchProvider.future), isNull);
  });
}
