import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/onboarding/data/branch_repository.dart';
import '../../features/onboarding/data/user_admin_repository.dart';
import 'branch_provider.dart' show firestoreProvider;

// ── Branches ──────────────────────────────────────────────────────────────────

final branchRepositoryProvider = Provider<BranchRepository>((ref) {
  return BranchRepository();
});

/// All branches, realtime. Falls back to [BranchRepository.seedBranches].
final branchesProvider = StreamProvider<List<Branch>>((ref) {
  return ref.watch(branchRepositoryProvider).watchBranches();
});

// ── Users (admin) ───────────────────────────────────────────────────────────

final userAdminRepositoryProvider = Provider<UserAdminRepository>((ref) {
  return UserAdminRepository(firestore: ref.watch(firestoreProvider));
});

/// Every user profile with its admin campuses, realtime. Readable only by
/// super admins (Firestore rules).
final allUsersProvider = StreamProvider<List<AdminUser>>((ref) {
  return ref.watch(userAdminRepositoryProvider).watchUsers();
});
