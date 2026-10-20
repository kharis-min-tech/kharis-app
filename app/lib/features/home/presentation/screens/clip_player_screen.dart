import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import 'package:kharis_app/features/home/data/featured_video_repository.dart';

/// Plays [video] full screen inside the app (a Short upright, a landscape
/// clip across), with sound and the player's own controls. Nothing opens
/// YouTube.
Future<void> openClipPlayer(BuildContext context, FeaturedVideo video) =>
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => ClipPlayerScreen(video: video),
      ),
    );

class ClipPlayerScreen extends StatefulWidget {
  const ClipPlayerScreen({super.key, required this.video});

  final FeaturedVideo video;

  @override
  State<ClipPlayerScreen> createState() => _ClipPlayerScreenState();
}

class _ClipPlayerScreenState extends State<ClipPlayerScreen> {
  late final YoutubePlayerController _controller =
      YoutubePlayerController.fromVideoId(
        videoId: widget.video.videoId,
        autoPlay: true,
        params: const YoutubePlayerParams(
          showFullscreenButton: false,
          strictRelatedVideos: true,
          showVideoAnnotations: false,
          playsInline: true,
        ),
      );

  @override
  void dispose() {
    _controller.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vertical = widget.video.vertical;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Stack(
            children: [
              Center(
                child: AspectRatio(
                  key: const Key('clip-player-frame'),
                  aspectRatio: vertical ? 9 / 16 : 16 / 9,
                  child: YoutubePlayer(
                    controller: _controller,
                    aspectRatio: vertical ? 9 / 16 : 16 / 9,
                  ),
                ),
              ),
              Positioned(
                top: 8,
                left: 8,
                child: IconButton(
                  key: const Key('clip-player-close'),
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).pop(),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black.withValues(alpha: 0.55),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(44, 44),
                  ),
                  icon: const Icon(Icons.close_rounded),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
