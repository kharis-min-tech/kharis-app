import 'package:flutter/widgets.dart';

/// Non-web stub. Never used at runtime on mobile/desktop because
/// MediaPlayerScreen only builds this widget when kIsWeb is true.
class YoutubeWebEmbed extends StatelessWidget {
  const YoutubeWebEmbed({super.key, required this.videoId, this.startSeconds});

  final String videoId;
  final int? startSeconds;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
