import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

/// Direct YouTube iframe embed for Flutter web.
///
/// Bypasses youtube_player_iframe's webview_flutter_web plumbing, which
/// fails silently in release (dart2js) builds — the platform view is never
/// registered and the player screen renders blank. A plain HtmlElementView
/// with a youtube-nocookie embed is bulletproof and loads instantly.
class YoutubeWebEmbed extends StatelessWidget {
  const YoutubeWebEmbed({super.key, required this.videoId, this.startSeconds});

  final String videoId;

  /// Playback position handed over from the audio engine, if any.
  final int? startSeconds;

  static final Set<String> _registered = <String>{};

  // Start time participates in the key: the registry caches factories, and a
  // handed-over position must not reuse an embed registered to start at 0.
  String get _viewType => 'youtube-embed-$videoId-${startSeconds ?? 0}';

  void _ensureRegistered() {
    if (_registered.contains(_viewType)) return;
    _registered.add(_viewType);

    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      final start =
          startSeconds != null && startSeconds! > 0 ? '&start=$startSeconds' : '';
      final iframe = web.HTMLIFrameElement()
        ..src =
            'https://www.youtube-nocookie.com/embed/$videoId?autoplay=1&playsinline=1&rel=0$start'
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..allow =
            'accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share'
        ..allowFullscreen = true;
      return iframe;
    });
  }

  @override
  Widget build(BuildContext context) {
    _ensureRegistered();
    return HtmlElementView(viewType: _viewType);
  }
}
