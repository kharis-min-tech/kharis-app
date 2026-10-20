import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import 'package:kharis_app/features/home/data/featured_video_repository.dart';
import 'package:kharis_app/shared/providers/sound_focus_provider.dart';

/// Plays [video] full screen inside the app (a Short upright, a landscape
/// clip across), with sound and the player's own controls. Nothing opens
/// YouTube. It holds the app's one sound while it plays: a message playing
/// pauses, and anything else that starts pauses the clip.
Future<void> openClipPlayer(BuildContext context, FeaturedVideo video) =>
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => ClipPlayerScreen(video: video),
      ),
    );

class ClipPlayerScreen extends ConsumerStatefulWidget {
  const ClipPlayerScreen({super.key, required this.video});

  final FeaturedVideo video;

  @override
  ConsumerState<ClipPlayerScreen> createState() => _ClipPlayerScreenState();
}

class _ClipPlayerScreenState extends ConsumerState<ClipPlayerScreen> {
  final Object _soundOwner = Object();
  late final SoundFocus _focus;
  late final StreamSubscription<YoutubePlayerValue> _values;

  late final YoutubePlayerController _controller =
      YoutubePlayerController.fromVideoId(
        videoId: widget.video.videoId,
        autoPlay: true,
        params: const YoutubePlayerParams(
          showFullscreenButton: false,
          enableCaption: false,
          strictRelatedVideos: true,
          showVideoAnnotations: false,
          playsInline: true,
        ),
      );

  @override
  void initState() {
    super.initState();
    _focus = ref.read(soundFocusProvider.notifier);
    // Claimed after the first frame: a provider may not change mid-build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.claim(_soundOwner);
    });
    // Playing again after a pause takes the sound back.
    _values = _controller.stream.listen((value) {
      if (value.playerState == PlayerState.playing) _focus.claim(_soundOwner);
    });
  }

  @override
  void dispose() {
    _values.cancel();
    final focus = _focus;
    final owner = _soundOwner;
    scheduleMicrotask(() => focus.release(owner));
    _controller.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(soundFocusProvider, (_, owner) {
      if (owner != null && owner != _soundOwner) _controller.pauseVideo();
    });
    final vertical = widget.video.vertical;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        // The close bar sits above the clip, never over it: the clip is a
        // native view that would cover anything drawn on top of it.
        body: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
                  child: IconButton(
                    key: const Key('clip-player-close'),
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    color: Colors.white,
                    iconSize: 28,
                    style: IconButton.styleFrom(
                      minimumSize: const Size(48, 48),
                    ),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: AspectRatio(
                    key: const Key('clip-player-frame'),
                    aspectRatio: vertical ? 9 / 16 : 16 / 9,
                    child: YoutubePlayer(
                      controller: _controller,
                      aspectRatio: vertical ? 9 / 16 : 16 / 9,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
