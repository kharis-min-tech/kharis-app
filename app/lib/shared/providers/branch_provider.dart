import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_provider.dart';
import 'onboarding_provider.dart';
import '../../features/onboarding/data/onboarding_repository.dart';
import 'notification_provider.dart';

/// Normalises a stored branch name: blank/whitespace-only becomes `null` so
/// callers get a single "unscoped" sentinel instead of three of them.
String? _normalise(String? raw) {
  final trimmed = raw?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  return trimmed;
}

/// Firestore handle, overridable in tests.
final firestoreProvider = Provider<FirebaseFirestore>(
  (ref) => FirebaseFirestore.instance,
);

/// The active branch name used to scope content (events, announcements,
/// giving, venue details). `null` means "all campuses" — callers must treat it
/// as unscoped rather than substituting a default branch.
///
/// Resolution order:
///   1. Firestore `users/{uid}.branch`, streamed live so a branch switch
///      propagates without an app restart.
///   2. The onboarding choice persisted in SharedPreferences, which is written
///      for every user including guests and signed-out sessions.
///
/// Why this exists: [currentUserProvider] is bound to Firebase Auth state and
/// only re-emits on sign-in/sign-out, so profile edits never surfaced through
/// it. Reading `currentUserProvider.branch` for content scoping returns a
/// stale value after a switch — use this provider instead.
///
/// Invalidate this provider after writing the branch for a guest (no Firestore
/// doc to stream), e.g. from the branch selection flow.
final currentBranchProvider = StreamProvider<String?>((ref) {
  // `select` so a bare AsyncLoading -> AsyncData transition that leaves the
  // user unchanged does not tear down and re-subscribe the Firestore listener
  // below (and, in tests, discard the pending `.future` completer).
  final user = ref.watch(currentUserProvider.select((a) => a.valueOrNull));
  final onboarding = ref.watch(onboardingRepositoryProvider);
  final local = _normalise(onboarding.selectedBranch);

  // Guests and signed-out sessions have no user doc to stream; the locally
  // persisted onboarding choice is authoritative for them.
  if (user == null || user.id.isEmpty || user.role == 'guest') {
    return Stream.value(local);
  }

  // The member picked a campus but the profile write did not land. Trust the
  // explicit local choice over the stale remote value — otherwise reopening
  // the app silently reverts them — and retry the push in the background.
  // Keyed on hasBranchChoice, not on `local != null`, so an unsynced
  // "All campuses" pick is honoured rather than falling through to the stale
  // profile branch.
  if (onboarding.branchSyncPending && onboarding.hasBranchChoice) {
    _retryBranchPush(ref, local, onboarding);
    return Stream.value(local);
  }

  return _profileBranchStream(ref.watch(firestoreProvider), user.id, local);
});

/// Writes `users/{uid}.branch`, allowing an explicit `null` for all campuses.
///
/// Not routed through `FirebaseAuthRepository.updateProfile`: that builds its
/// payload with null-aware entries, so a null branch is omitted rather than
/// written, and "All campuses" could never clear a previously set campus.
Future<void> _writeProfileBranch(
  FirebaseFirestore db,
  String uid,
  String? branch,
) =>
    db.collection('users').doc(uid).set(
      {'branch': branch},
      SetOptions(merge: true),
    );

/// Best-effort re-push of a campus that never reached the profile.
///
/// Runs off the provider build and swallows every failure by design: if
/// Firebase is not initialised, the network is down, or the container has been
/// disposed, the pending flag simply stays set, the local choice keeps winning,
/// and the next launch tries again. Letting this throw would take down branch
/// scoping for the whole app to fix a background sync.
void _retryBranchPush(
  Ref ref,
  String? branch,
  OnboardingRepository onboarding,
) {
  scheduleMicrotask(() async {
    try {
      final user = ref.read(currentUserProvider).valueOrNull;
      if (user == null || user.id.isEmpty) return;
      await _writeProfileBranch(ref.read(firestoreProvider), user.id, branch);
      await onboarding.setBranchSyncPending(false);
    } catch (_) {
      // Stays pending; retried on a later launch.
    }
  });
}

/// Outcome of [setActiveBranch].
@immutable
class BranchSwitchResult {
  const BranchSwitchResult({required this.syncFailed});

  /// Local preference and FCM topic landed, but the profile write did not.
  /// The choice is still in effect on this device and will be retried.
  final bool syncFailed;
}

/// Persists the member's campus everywhere it is stored — SharedPreferences,
/// the FCM branch topic, and `users/{uid}.branch` — then refreshes
/// [currentBranchProvider].
///
/// THE single way to change campus. Anything that changes it without going
/// through here leaves the three stores disagreeing, which is what made a
/// switch appear to revert on the next launch.
///
/// `branch == null` means all campuses and is a real, persisted choice.
Future<BranchSwitchResult> setActiveBranch(WidgetRef ref, String? branch) async {
  final onboarding = ref.read(onboardingRepositoryProvider);
  final previous = onboarding.selectedBranch;

  // Local first: it cannot fail, so the choice is never lost to the network.
  await onboarding.setSelectedBranch(branch);

  await ref.read(notificationServiceProvider).switchBranchTopic(
        from: previous,
        to: branch,
      );

  var syncFailed = false;
  final user = ref.read(currentUserProvider).valueOrNull;
  if (user != null && user.id.isNotEmpty && user.role != 'guest') {
    try {
      await _writeProfileBranch(ref.read(firestoreProvider), user.id, branch);
      await onboarding.setBranchSyncPending(false);
    } catch (_) {
      syncFailed = true;
      await onboarding.setBranchSyncPending(true);
    }
  }

  ref.invalidate(currentBranchProvider);
  return BranchSwitchResult(syncFailed: syncFailed);
}

/// Streams `users/{uid}.branch`, degrading to [local] if Firestore is
/// unreachable or rules deny the read. Degrading to the last known-good
/// onboarding choice keeps content scoped rather than silently unscoping it.
Stream<String?> _profileBranchStream(
  FirebaseFirestore db,
  String uid,
  String? local,
) async* {
  try {
    await for (final snap in db.collection('users').doc(uid).snapshots()) {
      yield _normalise(snap.data()?['branch'] as String?) ?? local;
    }
  } catch (_) {
    yield local;
  }
}
