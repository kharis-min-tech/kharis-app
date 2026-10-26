/// Podcast-app time skips: back a little to re-hear, forward further to skip.
///
/// One rule for every skip control: the in-app buttons of both engines and
/// the notification / lock-screen rewind and fast-forward.
abstract final class TimeSkip {
  static const Duration back = Duration(seconds: 15);
  static const Duration forward = Duration(seconds: 30);

  /// [position] moved by [offset], kept within the message ([duration] may
  /// be unknown, in which case only the start bounds it).
  static Duration target(
    Duration position,
    Duration offset,
    Duration? duration,
  ) {
    var target = position + offset;
    if (target < Duration.zero) target = Duration.zero;
    if (duration != null && duration > Duration.zero && target > duration) {
      target = duration;
    }
    return target;
  }
}
