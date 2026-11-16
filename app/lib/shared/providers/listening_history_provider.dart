import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/player/data/playback_history.dart';
import 'audio_provider.dart';
import 'cache_provider.dart';

export '../../features/player/data/playback_history.dart' show UnfinishedPlay;

/// Continue listening shows this many messages; `/history` shows them all.
const int kContinueListeningCount = 3;

/// Every message the member started and has not finished, most recently
/// played first, each with where they stopped and its length (the length is
/// null when no player has reported one yet).
///
/// Built from the same resume points and "recently played" list as the
/// Continue listening card, so its first entry is that card's message. It
/// holds as many messages as the recently played list keeps (20), audio and
/// video alike, and redraws on every saved position.
final listeningHistoryProvider = Provider<List<UnfinishedPlay>>((ref) {
  final history = ref.watch(playbackHistoryProvider);
  void changed() => ref.invalidateSelf();
  history.changes.addListener(changed);
  ref.onDispose(() => history.changes.removeListener(changed));

  final byId = {for (final sermon in history.snapshots()) sermon.id: sermon};
  final plays = <UnfinishedPlay>[];
  for (final id in ref.watch(cacheServiceProvider).getRecentlyPlayed()) {
    final sermon = byId[id];
    if (sermon == null) continue;
    final position = history.resumePoint(sermon);
    if (position == null) continue;
    plays.add(
      UnfinishedPlay(
        sermon: sermon,
        position: position,
        duration: sermon.duration,
      ),
    );
  }
  return plays;
});

/// The first [kContinueListeningCount] of [listeningHistoryProvider].
final continueListeningListProvider = Provider<List<UnfinishedPlay>>(
  (ref) => ref
      .watch(listeningHistoryProvider)
      .take(kContinueListeningCount)
      .toList(),
);
