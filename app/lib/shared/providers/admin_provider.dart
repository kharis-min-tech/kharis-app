import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/onboarding/data/branch_repository.dart';
import '../../features/onboarding/data/user_admin_repository.dart';
import 'branch_provider.dart' show firestoreProvider;
import 'content_api_provider.dart';

// ── Branches ──────────────────────────────────────────────────────────────────

final branchRepositoryProvider = Provider<BranchRepository>((ref) {
  return BranchRepository(api: ref.watch(contentApiProvider));
});

/// Active Content Studio branches with their services and venues: the last
/// known list saved on this device first, then the Studio's current one.
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
