import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/onboarding/data/branch_repository.dart';
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
