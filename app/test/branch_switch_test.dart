import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kharis_app/core/services/notification_service.dart';
import 'package:kharis_app/shared/models/user.dart';
import 'package:kharis_app/shared/providers/auth_provider.dart';
import 'package:kharis_app/shared/providers/branch_provider.dart';
import 'package:kharis_app/shared/providers/notification_provider.dart';
import 'package:kharis_app/shared/providers/onboarding_provider.dart';

/// Records topic switches instead of touching FCM.
class _RecordingNotificationService extends NotificationService {
  final switches = <({String? from, String? to})>[];

  @override
  Future<void> switchBranchTopic({String? from, String? to}) async {
    switches.add((from: from, to: to));
  }
}

/// Covers the reported bug: a campus picked on the Events screen looked like it
/// stuck, then reverted on relaunch, because the choice lived in screen-local
/// state and never reached the three stores that actually persist it.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const uid = 'user-1';

  User member({String? branch}) => User(
        id: uid,
        email: 'member@kharis.org',
        displayName: 'Member',
        role: 'member',
        branch: branch,
        createdAt: DateTime(2024),
      );

  /// Pumps a widget so `setActiveBranch` gets a real WidgetRef, and hands the
  /// ref back to the caller.
  Future<({ProviderContainer container, WidgetRef ref, _RecordingNotificationService fcm})>
      harness(
    WidgetTester tester, {
    required FakeFirebaseFirestore db,
    User? user,
    Map<String, Object> prefs = const {},
  }) async {
    SharedPreferences.setMockInitialValues(prefs);
    final sp = await SharedPreferences.getInstance();
    final fcm = _RecordingNotificationService();
    late WidgetRef captured;

    final container = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(sp),
      firestoreProvider.overrideWithValue(db),
      currentUserProvider.overrideWith((ref) => Stream.value(user)),
      notificationServiceProvider.overrideWithValue(fcm),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: Consumer(builder: (context, ref, _) {
        captured = ref;
        return const SizedBox();
      }),
    ));
    await container.read(currentUserProvider.future);
    return (container: container, ref: captured, fcm: fcm);
  }

  testWidgets('a campus switch survives a relaunch', (tester) async {
    final db = FakeFirebaseFirestore();
    await db.collection('users').doc(uid).set({'branch': 'Bristol'});
    final h = await harness(tester,
        db: db, user: member(branch: 'Bristol'), prefs: {'onboarding_branch': 'Bristol'});

    final result = await setActiveBranch(h.ref, 'Manchester');
    expect(result.syncFailed, isFalse);

    // All three stores must agree, or the next launch reverts.
    final sp = await SharedPreferences.getInstance();
    expect(sp.getString('onboarding_branch'), 'Manchester');
    final doc = await db.collection('users').doc(uid).get();
    expect(doc.data()?['branch'], 'Manchester');
    expect(h.fcm.switches.single, (from: 'Bristol', to: 'Manchester'));

    // Simulate the relaunch the owner described.
    final relaunch = await harness(tester,
        db: db, user: member(branch: 'Manchester'), prefs: {'onboarding_branch': 'Manchester'});
    expect(
      await relaunch.container.read(currentBranchProvider.future),
      'Manchester',
      reason: 'closing and reopening must not revert the campus',
    );
  });

  testWidgets('All campuses persists and clears the stored campus',
      (tester) async {
    final db = FakeFirebaseFirestore();
    await db.collection('users').doc(uid).set({'branch': 'Bristol'});
    final h = await harness(tester,
        db: db, user: member(branch: 'Bristol'), prefs: {'onboarding_branch': 'Bristol'});

    await setActiveBranch(h.ref, null);

    // updateProfile would have omitted a null branch, leaving Bristol behind.
    final doc = await db.collection('users').doc(uid).get();
    expect(doc.data()?['branch'], isNull,
        reason: 'All campuses must actually clear the stored campus');

    final relaunch = await harness(tester,
        db: db, user: member(), prefs: {'onboarding_branch': ''});
    expect(await relaunch.container.read(currentBranchProvider.future), isNull);
  });

  testWidgets('an unsynced All campuses pick is not overwritten by the profile',
      (tester) async {
    final db = FakeFirebaseFirestore();
    await db.collection('users').doc(uid).set({'branch': 'Bristol'});
    // Empty string reads back as null, so without hasBranchChoice this was
    // indistinguishable from "never chose" and the stale profile won.
    final h = await harness(tester, db: db, user: member(branch: 'Bristol'), prefs: {
      'onboarding_branch': '',
      'onboarding_branch_sync_pending': true,
    });
    expect(await h.container.read(currentBranchProvider.future), isNull);
  });
}
