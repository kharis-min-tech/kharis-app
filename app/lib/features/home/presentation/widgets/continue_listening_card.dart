import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kharis_app/features/player/data/playback_history.dart';
import 'package:kharis_app/shared/providers/audio_provider.dart';

/// The most recently played message that was started and not finished, or
/// null. Re-evaluated on every playback transition so a pause, a finish or a
/// new play updates the card.
final continueListeningProvider = Provider.autoDispose<UnfinishedPlay?>((ref) {
  ref.watch(playerStateProvider);
  return ref.watch(playbackHistoryProvider).lastUnfinished();
});

/// "12 min left", "1 hr 5 min left", "Less than a minute left".
String remainingLabel(Duration remaining) {
  final minutes = (remaining.inSeconds / 60).ceil();
  if (minutes <= 1) return 'Less than a minute left';
  if (minutes < 60) return '$minutes min left';
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  return rest == 0 ? '$hours hr left' : '$hours hr $rest min left';
}
