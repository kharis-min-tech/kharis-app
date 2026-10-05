import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:kharis_app/features/onboarding/data/auth_repository.dart';
import 'package:kharis_app/features/onboarding/data/onboarding_repository.dart';
import 'package:kharis_app/shared/providers/auth_provider.dart';
import 'package:kharis_app/shared/providers/branch_provider.dart';
import 'package:kharis_app/shared/providers/cache_provider.dart';
import 'package:kharis_app/shared/providers/onboarding_provider.dart';

/// Removes everything a member stores in Firestore.
///
/// A member owns `users/{uid}` with its `notes` and `playlists`
/// subcollections (Favourites is the `liked` doc in `playlists`) and
/// their `rsvps/{uid}_{eventId}` docs. Feedback (`app_feedback`), visitor
/// cards and testimonies are write-only for members and are left for the
/// church to manage.
class AccountDataRepository {
  AccountDataRepository(this._firestore);

  final FirebaseFirestore _firestore;

  /// Firestore's limit on writes per batch.
  static const _batchLimit = 500;

  /// Deletes [uid]'s notes, playlists, RSVPs and finally the profile doc.
  ///
  /// The profile goes last so a failure part-way leaves it in place and a
  /// retry finds the account as it was. Idempotent: deleting a missing doc
  /// is a no-op.
  Future<void> deleteUserData(String uid) async {
    final profile = _firestore.collection('users').doc(uid);
    final notes = await profile.collection('notes').get();
    final playlists = await profile.collection('playlists').get();
    final rsvps = await _firestore
        .collection('rsvps')
        .where('userId', isEqualTo: uid)
        .get();
    final refs = <DocumentReference<Map<String, dynamic>>>[
      for (final doc in notes.docs) doc.reference,
      for (final doc in playlists.docs) doc.reference,
      for (final doc in rsvps.docs) doc.reference,
      profile,
    ];
    for (var start = 0; start < refs.length; start += _batchLimit) {
      final batch = _firestore.batch();
      final end = start + _batchLimit < refs.length
          ? start + _batchLimit
          : refs.length;
      for (final ref in refs.sublist(start, end)) {
        batch.delete(ref);
      }
      await batch.commit();
    }
  }
}

/// Personal data this device keeps for the member outside Firestore.
class LocalAccountData {
  LocalAccountData(this._notesBox, this._onboarding);

  final Box<dynamic> _notesBox;
  final OnboardingRepository _onboarding;

  /// Clears notes kept on the device and the saved role and branch, so the
  /// app starts again from Welcome.
  Future<void> clear() async {
    await _notesBox.clear();
    await _onboarding.reset();
    await _onboarding.setBranchSyncPending(false);
  }
}

/// Runs an in-app account deletion end to end.
class AccountDeletionService {
  AccountDeletionService({
    required this.auth,
    required this.data,
    required this.local,
  });

  final AuthRepository auth;
  final AccountDataRepository data;
  final LocalAccountData local;

  /// Confirms [password] when given, deletes [uid]'s Firestore data, then
  /// the auth account (which signs out), then the device's copies.
  ///
  /// Throws [InvalidCredentialsException] for a wrong password and
  /// [RecentLoginRequiredException] when the auth backend wants a fresh
  /// sign-in; call again with the password. Safe to retry after any failure.
  Future<void> deleteAccount({required String uid, String? password}) async {
    if (password != null) await auth.reauthenticate(password);
    await data.deleteUserData(uid);
    await auth.deleteAccount();
    await local.clear();
  }
}

final accountDataRepositoryProvider = Provider<AccountDataRepository>((ref) {
  return AccountDataRepository(ref.watch(firestoreProvider));
});

final localAccountDataProvider = Provider<LocalAccountData>((ref) {
  return LocalAccountData(
    ref.watch(cacheServiceProvider).notesBox,
    ref.watch(onboardingRepositoryProvider),
  );
});

final accountDeletionServiceProvider = Provider<AccountDeletionService>((ref) {
  return AccountDeletionService(
    auth: ref.watch(authRepositoryProvider),
    data: ref.watch(accountDataRepositoryProvider),
    local: ref.watch(localAccountDataProvider),
  );
});
