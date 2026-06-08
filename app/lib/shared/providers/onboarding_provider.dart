import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/onboarding/data/onboarding_repository.dart';

/// SharedPreferences instance - must be overridden at app startup.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Override sharedPreferencesProvider in main.dart');
});

/// Onboarding repository backed by SharedPreferences.
final onboardingRepositoryProvider = Provider<OnboardingRepository>((ref) {
  return OnboardingRepository(ref.watch(sharedPreferencesProvider));
});

/// Whether onboarding has been completed.
final onboardingCompletedProvider = Provider<bool>((ref) {
  return ref.watch(onboardingRepositoryProvider).isCompleted;
});
