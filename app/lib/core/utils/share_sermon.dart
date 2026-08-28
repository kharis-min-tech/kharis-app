import 'package:share_plus/share_plus.dart';

import 'package:kharis_app/shared/models/sermon.dart';

/// Opens the OS share sheet for [sermon].
///
/// Sermons that came off YouTube get their canonical `youtu.be` link — a URL
/// that works for someone without the app installed. Audio-only sermons fall
/// back to the church site. This replaces the old copy-to-clipboard toast the
/// testers flagged.
Future<void> shareSermon(Sermon sermon) {
  final videoId = sermon.videoId;
  final link = (videoId != null && videoId.isNotEmpty)
      ? 'https://youtu.be/$videoId'
      : 'https://kharis.org';
  final speaker = sermon.speaker;
  final by = speaker.isNotEmpty ? ' \u2014 $speaker' : '';
  return SharePlus.instance.share(
    ShareParams(text: '${sermon.title}$by\n$link'),
  );
}
