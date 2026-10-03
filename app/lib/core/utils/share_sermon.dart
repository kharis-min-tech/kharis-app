import 'package:share_plus/share_plus.dart';

import 'package:kharis_app/shared/models/sermon.dart';

/// Public page of a message on the church's sermon host.
const String kSermonPageBase = 'https://yetanothersermon.host/_/kc/sermons/';

/// The link that opens [sermon] for someone without the app.
///
/// - Shared while watching ([asVideo]), or a message that only exists on
///   YouTube: the `youtu.be` link, starting at [position] when there is one.
/// - A message from the church's sermon API: its sermon page, which carries
///   the recording (and the video when there is one).
/// - Anything else with a video: the `youtu.be` link.
/// - Otherwise the church site.
String sermonShareLink(
  Sermon sermon, {
  Duration? position,
  bool asVideo = false,
}) {
  final videoId = sermon.videoId?.trim();
  final hasVideo = videoId != null && videoId.isNotEmpty;
  String youtube() {
    final seconds = position?.inSeconds ?? 0;
    return seconds > 0
        ? 'https://youtu.be/$videoId?t=$seconds'
        : 'https://youtu.be/$videoId';
  }

  if (hasVideo && (asVideo || !sermon.hasAudio)) return youtube();
  if (sermon.source == 'kharis-api' && sermon.id.isNotEmpty) {
    return '$kSermonPageBase${sermon.id}/';
  }
  if (hasVideo) return youtube();
  return 'https://kharis.org';
}

/// The text handed to the share sheet: title, speaker and link.
String sermonShareText(
  Sermon sermon, {
  Duration? position,
  bool asVideo = false,
}) {
  final speaker = sermon.speaker.trim();
  final by = speaker.isNotEmpty ? ' by $speaker' : '';
  final link = sermonShareLink(sermon, position: position, asVideo: asVideo);
  return '${sermon.title}$by\n$link';
}

/// Opens the OS share sheet for [sermon]. See [sermonShareLink] for which
/// link is shared.
Future<void> shareSermon(
  Sermon sermon, {
  Duration? position,
  bool asVideo = false,
}) {
  return SharePlus.instance.share(
    ShareParams(
      text: sermonShareText(sermon, position: position, asVideo: asVideo),
    ),
  );
}
