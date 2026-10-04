import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kharis_app/features/admin/data/branch_settings_repository.dart';
import 'package:kharis_app/features/admin/data/content_config_repository.dart';
import 'package:kharis_app/features/messages/data/curation_repository.dart'
    show FeaturedMode;
import 'package:kharis_app/shared/models/campus_config.dart';
import 'package:kharis_app/shared/providers/branch_provider.dart'
    show firestoreProvider;

export 'package:kharis_app/features/admin/data/branch_settings_repository.dart';
export 'package:kharis_app/features/admin/data/content_config_repository.dart';

final contentConfigRepositoryProvider = Provider<ContentConfigRepository>(
  (ref) => ContentConfigRepository(firestore: ref.watch(firestoreProvider)),
);

final branchSettingsRepositoryProvider = Provider<BranchSettingsRepository>(
  (ref) => BranchSettingsRepository(firestore: ref.watch(firestoreProvider)),
);

/// Studio view of `config/featured.mode`; `auto` until the doc says otherwise.
final adminFeaturedModeProvider = StreamProvider.autoDispose<FeaturedMode>(
  (ref) => ref.watch(contentConfigRepositoryProvider).watchFeaturedMode(),
);

/// `config/giving`; null while Studio has set none.
final adminChurchGivingProvider = StreamProvider.autoDispose<GivingDetails?>(
  (ref) => ref.watch(contentConfigRepositoryProvider).watchChurchGiving(),
);

/// `config/home`; null while Studio has set none.
final adminChurchHomeProvider = StreamProvider.autoDispose<HomeLayout?>(
  (ref) => ref.watch(contentConfigRepositoryProvider).watchChurchHome(),
);

/// The raw `branches/{id}` doc for the branch page's campus settings.
final adminBranchDocProvider = StreamProvider.autoDispose
    .family<Map<String, dynamic>?, String>(
      (ref, id) => ref.watch(branchSettingsRepositoryProvider).watchBranch(id),
    );
