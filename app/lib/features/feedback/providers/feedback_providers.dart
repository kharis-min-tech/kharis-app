import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kharis_app/features/feedback/data/app_feedback_repository.dart';
import 'package:kharis_app/features/feedback/data/review_prompt_store.dart';
import 'package:kharis_app/features/feedback/data/store_review.dart';
import 'package:kharis_app/shared/providers/auth_provider.dart';
import 'package:kharis_app/shared/providers/branch_provider.dart';
import 'package:kharis_app/shared/providers/onboarding_provider.dart';

final reviewPromptStoreProvider = Provider<ReviewPromptStore>(
  (ref) => ReviewPromptStore(ref.watch(sharedPreferencesProvider)),
);

final appFeedbackRepositoryProvider = Provider<AppFeedbackRepository>((ref) {
  return AppFeedbackRepository(
    ref.watch(firestoreProvider),
    uid: ref.watch(currentUserProvider).valueOrNull?.id,
  );
});

/// Overridable so tests can record native review requests.
final storeReviewProvider = Provider<StoreReview>((ref) => const StoreReview());

/// Clock seam for the prompt policy.
final reviewClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);
