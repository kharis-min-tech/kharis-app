import 'package:kharis_app/shared/models/sermon.dart';

/// Which medium the unified player is presenting.
enum MediaMode { audio, video }

/// Resolves the mode [MediaPlayerScreen] opens in.
///
/// A request is honoured only when the sermon actually carries that medium.
/// With no usable request, audio wins: most sermons carry both an mp3 and a
/// YouTube link, and a member who asked for a message must never be handed a
/// video instead. A sermon with neither medium opens in audio, whose layout
/// hosts the "no recording" failure banner.
MediaMode resolveInitialMode(Sermon sermon, MediaMode? requested) {
  if (requested == MediaMode.video && sermon.hasVideo) return MediaMode.video;
  if (requested == MediaMode.audio && sermon.hasAudio) return MediaMode.audio;
  if (sermon.hasAudio) return MediaMode.audio;
  if (sermon.hasVideo) return MediaMode.video;
  return MediaMode.audio;
}
