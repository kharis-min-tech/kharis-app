import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/home/data/daily_content_repository.dart';
import '../../features/home/data/reading_plan_repository.dart';
import 'sermon_provider.dart';

final readingPlanRepositoryProvider = Provider<ReadingPlanRepository>((ref) {
  return ReadingPlanRepository();
});

/// Every reading plan, newest start date first — the Content Studio list.
final readingPlansProvider = StreamProvider<List<ReadingPlan>>((ref) {
  return ref.watch(readingPlanRepositoryProvider).watchPlans();
});

/// What a given `YYYY-MM-DD` actually resolves to, and why — the Content Studio
/// preview. Keyed by date string so a picked date re-resolves on its own.
final readingPreviewProvider =
    FutureProvider.family<ResolvedDailyContent, String>((ref, dateKey) {
  // Watching the plan list makes the preview refresh as soon as a plan is
  // saved or deleted, without the screen having to invalidate anything.
  ref.watch(readingPlansProvider);
  return ref.watch(dailyContentRepositoryProvider).resolveForDate(dateKey);
});
