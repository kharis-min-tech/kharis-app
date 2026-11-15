import 'package:kharis_app/features/playlists/providers/playlist_providers.dart';

/// "1 message", "8 messages".
String messageCountLabel(int count) =>
    count == 1 ? '1 message' : '$count messages';

/// A listening length as a member reads it: "42 min", "3 h", "3 h 40 min".
/// Anything under a minute reads "1 min".
String listeningLengthLabel(Duration length) {
  final minutes = (length.inSeconds / 60).round();
  if (minutes < 60) return '${minutes < 1 ? 1 : minutes} min';
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  return rest == 0 ? '$hours h' : '$hours h $rest min';
}

/// The total length of a collection, or null while any of its messages is
/// still loading, is gone, or has no known length: a partial total would
/// read as the whole.
Duration? collectionLength(PlaylistResolution resolution) {
  if (resolution.sermons.isEmpty ||
      resolution.pending > 0 ||
      resolution.missing > 0) {
    return null;
  }
  var total = Duration.zero;
  for (final sermon in resolution.sermons) {
    final length = sermon.duration;
    if (length == null) return null;
    total += length;
  }
  return total;
}

/// The meta line of a collection: "8 messages · 3 h 40 min", or just the
/// count when the total length is not known.
String collectionMeta(int count, PlaylistResolution resolution) {
  final length = collectionLength(resolution);
  final messages = messageCountLabel(count);
  return length == null
      ? messages
      : '$messages · ${listeningLengthLabel(length)}';
}
