import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kharis_app/features/admin/data/content_config_repository.dart';

export 'package:kharis_app/features/admin/data/content_config_repository.dart';

final contentConfigRepositoryProvider = Provider<ContentConfigRepository>(
  (ref) => ContentConfigRepository(),
);

/// Studio view of `config/featured.mode`; `auto` until the doc says otherwise.
final adminFeaturedModeProvider = StreamProvider.autoDispose<FeaturedMode>(
  (ref) => ref.watch(contentConfigRepositoryProvider).watchFeaturedMode(),
);

/// Scheduled Messages of the Day from today onwards, soonest first.
final adminMotdScheduleProvider = StreamProvider.autoDispose<List<MotdEntry>>((
  ref,
) {
  return ref
      .watch(contentConfigRepositoryProvider)
      .watchSchedule(from: DateTime.now());
});
