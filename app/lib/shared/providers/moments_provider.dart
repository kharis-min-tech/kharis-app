import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/firebase_service.dart';
import '../../features/messages/data/moments_repository.dart';
import 'branch_provider.dart';

export '../../features/messages/data/moments_repository.dart' show Moment;

final momentsRepositoryProvider = Provider<MomentsRepository>(
  (ref) => MomentsRepository(ref.watch(firestoreProvider)),
);

/// Short clips from the church's YouTube channel, newest first: title,
/// thumbnail, length and video id. Empty when Firebase is off.
final momentsProvider = FutureProvider<List<Moment>>((ref) async {
  if (!kUseFirebase) return const [];
  return ref.watch(momentsRepositoryProvider).latest();
});
