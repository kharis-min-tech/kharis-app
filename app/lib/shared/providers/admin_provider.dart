import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/onboarding/data/branch_repository.dart';
import '../../features/onboarding/data/user_admin_repository.dart';
import '../models/user.dart';

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
  return UserAdminRepository();
});

/// Every user profile, realtime. Readable only by admins (Firestore rules).
final allUsersProvider = StreamProvider<List<User>>((ref) {
  return ref.watch(userAdminRepositoryProvider).watchUsers();
});
