import 'package:flutter/foundation.dart';

import 'package:kharis_app/shared/models/sermon.dart';

/// What the Previous control does at a given playback position.
enum PreviousAction {
  /// Seek the current message back to its start.
  restart,

  /// Move to the preceding message in the queue.
  previousItem,

  /// Nothing to do: first message, already at its start.
  none,
}

/// The ordered list of messages the member launched playback from, and where
/// in it they are. Pure data, so the Spotify-style Previous / Next rules are
/// testable without an audio engine.
///
/// Only playable entries are kept: the audio queue holds messages with an
/// audio recording, and duplicates (the same id twice) collapse to the first.
@immutable
class PlaybackQueue {
  const PlaybackQueue._(this.items, this.index);

  /// Previous restarts the current message instead of stepping back once
  /// playback is past this point.
  static const Duration restartThreshold = Duration(seconds: 3);

  /// Builds the queue for playing [sermon] out of [source].
  ///
  /// [source] is the list the member tapped in (a playlist, search results,
  /// the Messages list). When [sermon] is not in it, or [source] is null, the
  /// queue is just [sermon]: Next and Previous are then disabled rather than
  /// jumping somewhere unrelated.
  factory PlaybackQueue.from(
    Sermon sermon, [
    List<Sermon>? source,
    bool Function(Sermon)? playable,
  ]) {
    final accept = playable ?? (Sermon s) => s.hasAudio;
    final seen = <String>{};
    final items = <Sermon>[];
    for (final item in source ?? const <Sermon>[]) {
      if (!accept(item) || !seen.add(item.id)) continue;
      items.add(item.id == sermon.id ? sermon : item);
    }
    final index = items.indexWhere((s) => s.id == sermon.id);
    if (index < 0) return PlaybackQueue._(List.unmodifiable([sermon]), 0);
    return PlaybackQueue._(List.unmodifiable(items), index);
  }

  final List<Sermon> items;
  final int index;

  Sermon get current => items[index];

  bool get hasNext => index < items.length - 1;
  bool get hasPrevious => index > 0;

  Sermon? get next => hasNext ? items[index + 1] : null;
  Sermon? get previous => hasPrevious ? items[index - 1] : null;

  /// Spotify semantics: past [restartThreshold] Previous restarts the current
  /// message; otherwise it steps back, and at the first message it does
  /// nothing.
  PreviousAction previousAction(Duration position) {
    if (position > restartThreshold) return PreviousAction.restart;
    return hasPrevious ? PreviousAction.previousItem : PreviousAction.none;
  }

  /// Whether Previous is actionable at [position].
  bool canGoPrevious(Duration position) =>
      previousAction(position) != PreviousAction.none;

  /// The same queue positioned at [newIndex].
  PlaybackQueue moveTo(int newIndex) {
    RangeError.checkValidIndex(newIndex, items, 'newIndex');
    return PlaybackQueue._(items, newIndex);
  }

  @override
  bool operator ==(Object other) =>
      other is PlaybackQueue &&
      other.index == index &&
      listEquals(
        other.items.map((s) => s.id).toList(),
        items.map((s) => s.id).toList(),
      );

  @override
  int get hashCode =>
      Object.hash(index, Object.hashAll(items.map((s) => s.id)));
}
