import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/firebase_service.dart';
import '../../features/messages/data/moments_repository.dart';
import 'branch_provider.dart';

export '../../features/messages/data/moments_repository.dart' show Moment;

final momentsRepositoryProvider = Provider<MomentsRepository>(
  (ref) => MomentsRepository(ref.watch(firestoreProvider)),
);

/// Clips shorter than this are not worth a tile on Home.
const Duration kMinMomentLength = Duration(seconds: 10);

/// [moments] without the clips known to run under [kMinMomentLength]; a
/// clip of unknown length stays.
List<Moment> momentsWorthShowing(List<Moment> moments) => [
  for (final m in moments)
    if (m.duration == null || m.duration! >= kMinMomentLength) m,
];

/// Short clips from the church's YouTube channel, newest first: title,
/// thumbnail, length and video id, less those under [kMinMomentLength].
/// Empty when Firebase is off.
final momentsProvider = FutureProvider<List<Moment>>((ref) async {
  if (!kUseFirebase) return const [];
  return momentsWorthShowing(
    await ref.watch(momentsRepositoryProvider).latest(),
  );
});
