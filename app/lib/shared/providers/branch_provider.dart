import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_provider.dart';
import 'onboarding_provider.dart';
import '../../features/onboarding/data/onboarding_repository.dart';

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

  // The member picked a branch but the profile write did not land. Trust the
  // explicit local choice over the stale remote value — otherwise reopening
  // the app silently reverts them — and retry the push in the background.
  if (onboarding.branchSyncPending && local != null) {
    _retryBranchPush(ref, local, onboarding);
    return Stream.value(local);
  }

  return _profileBranchStream(ref.watch(firestoreProvider), user.id, local);
});

/// Best-effort re-push of a branch that never reached the profile.
///
/// Runs off the provider build and swallows every failure by design: if
/// Firebase is not initialised, the network is down, or the container has been
/// disposed, the pending flag simply stays set, the local choice keeps winning,
/// and the next launch tries again. Letting this throw would take down branch
/// scoping for the whole app to fix a background sync.
void _retryBranchPush(
  Ref ref,
  String branch,
  OnboardingRepository onboarding,
) {
  scheduleMicrotask(() async {
    try {
      await ref
          .read(firebaseAuthRepositoryProvider)
          .updateProfile(branch: branch);
      await onboarding.setBranchSyncPending(false);
    } catch (_) {
      // Stays pending; retried on a later launch.
    }
  });
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
