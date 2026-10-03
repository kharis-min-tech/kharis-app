import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import 'package:kharis_app/core/constants/app_links.dart';
import 'package:kharis_app/features/notes/data/note_timeline_key.dart';
import 'package:kharis_app/shared/models/sermon.dart';

/// The Kharis link for [sermon] (see [AppLinks.message]).
///
/// Keyed by the [NoteTimelineKey] canonical id, so the audio and video
/// variants of one message share one link. [position] is on the AUDIO
/// timeline and becomes `t`; [asVideo] (shared while watching) adds `v=1`.
Uri sermonShareLink(
  Sermon sermon, {
  Duration? position,
  bool asVideo = false,
}) => AppLinks.message(
  NoteTimelineKey.of(sermon).canonical,
  at: position,
  video: asVideo && sermon.hasVideo,
);

/// The text handed to the share sheet: the title, the speaker and date when
/// known, then the Kharis link.
String sermonShareText(
  Sermon sermon, {
  Duration? position,
  bool asVideo = false,
}) {
  final speaker = sermon.speaker.trim();
  final date = sermon.publishedAt;
  final byline = [
    if (speaker.isNotEmpty) speaker,
    if (date != null) DateFormat('d MMMM yyyy').format(date),
  ].join(', ');
  return [
    sermon.title.trim(),
    if (byline.isNotEmpty) byline,
    AppLinks.shareLine(
      sermonShareLink(sermon, position: position, asVideo: asVideo),
    ),
  ].join('\n');
}

/// Opens the OS share sheet for [sermon]. See [sermonShareLink] for the link.
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
