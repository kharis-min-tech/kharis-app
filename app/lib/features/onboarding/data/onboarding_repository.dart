import 'package:shared_preferences/shared_preferences.dart';

/// Persists onboarding completion state and selected branch.
///
/// Keys are prefixed with `onboarding_` to avoid collisions.
class OnboardingRepository {
  static const _completedKey = 'onboarding_completed';
  static const _roleKey = 'onboarding_role';
  static const _branchKey = 'onboarding_branch';

  final SharedPreferences _prefs;

  OnboardingRepository(this._prefs);

  bool get isCompleted => _prefs.getBool(_completedKey) ?? false;

  String? get selectedRole => _prefs.getString(_roleKey);

  String? get selectedBranch => _prefs.getString(_branchKey);

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

  Future<void> reset() async {
    await Future.wait([
      _prefs.remove(_completedKey),
      _prefs.remove(_roleKey),
      _prefs.remove(_branchKey),
    ]);
  }
}
