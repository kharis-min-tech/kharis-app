import 'package:shared_preferences/shared_preferences.dart';

/// Persists onboarding completion state and selected branch.
///
/// Keys are prefixed with `onboarding_` to avoid collisions.
class OnboardingRepository {
  static const _completedKey = 'onboarding_completed';
  static const _roleKey = 'onboarding_role';
  static const _branchKey = 'onboarding_branch';
  static const _branchPendingKey = 'onboarding_branch_sync_pending';

  final SharedPreferences _prefs;

  OnboardingRepository(this._prefs);

  bool get isCompleted => _prefs.getBool(_completedKey) ?? false;

  String? get selectedRole => _prefs.getString(_roleKey);

  String? get selectedBranch => _prefs.getString(_branchKey);

  /// Whether the member has ever explicitly chosen a campus.
  ///
  /// Distinct from [selectedBranch] being non-null: "All campuses" is a real
  /// choice stored as an empty string, which reads back as `null`. Without
  /// this, an unsynced "All campuses" pick would be indistinguishable from
  /// never having chosen, and the stale profile branch would win.
  bool get hasBranchChoice => _prefs.containsKey(_branchKey);

  /// Persists the campus on its own, outside the onboarding flow.
  /// `null` means all campuses and is stored as an empty string.
  Future<void> setSelectedBranch(String? branch) =>
      _prefs.setString(_branchKey, branch ?? '');

  /// True when [selectedBranch] has not yet been written to the signed-in
  /// user's Firestore profile.
  ///
  /// The profile is normally authoritative, so a failed write would let the
  /// stale remote branch overwrite the member's choice on the next launch —
  /// they pick a branch, reopen the app, and silently land back on the old
  /// one. While this flag is set the local choice wins and the push is
  /// retried.
  bool get branchSyncPending => _prefs.getBool(_branchPendingKey) ?? false;

  Future<void> setBranchSyncPending(bool pending) =>
      _prefs.setBool(_branchPendingKey, pending);

  Future<void> completeOnboarding({
    required String role,
    required String branch,
  }) async {
    await Future.wait([
      _prefs.setBool(_completedKey, true),
      _prefs.setString(_roleKey, role),
      _prefs.setString(_branchKey, branch),
    ]);
  }

  /// Persists the selected role before branch selection completes onboarding.
  Future<void> saveRole(String role) => _prefs.setString(_roleKey, role);

  Future<void> reset() async {
    await Future.wait([
      _prefs.remove(_completedKey),
      _prefs.remove(_roleKey),
      _prefs.remove(_branchKey),
    ]);
  }
}
