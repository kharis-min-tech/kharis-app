/// A playback position as members read it on the player: `m:ss` under an
/// hour (`0:05`, `12:30`), `h:mm:ss` from an hour on (`1:02:07`).
///
/// The one spelling for every timestamp tied to a message's timeline — note
/// stamps and transcript markers alike — so the same moment reads the same
/// everywhere. Negative durations clamp to `0:00`.
String formatPlaybackTimestamp(Duration position) {
  final d = position.isNegative ? Duration.zero : position;
  final h = d.inHours;
  final m = d.inMinutes.remainder(60).toString().padLeft(h > 0 ? 2 : 1, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return h > 0 ? '$h:$m:$s' : '$m:$s';
}
