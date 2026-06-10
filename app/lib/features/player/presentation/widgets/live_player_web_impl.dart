import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

/// Flutter web HLS player using an srcdoc iframe + hls.js CDN.
///
/// Uses the same HtmlElementView pattern as YoutubeWebEmbed to avoid
/// the silent failure that plagues webview_flutter_web in dart2js release
/// builds. Each unique stream URL gets its own registered view type.
///
/// hls.js (https://cdn.jsdelivr.net/npm/hls.js@latest) handles Chrome/Firefox
/// playback; browsers with native HLS (Safari/iOS) fall through to the
/// <video> element's built-in canPlayType path.
class LivePlayerWeb extends StatelessWidget {
  const LivePlayerWeb({super.key, required this.streamUrl});

  final String streamUrl;

  static final Set<String> _registered = <String>{};

  String get _viewType => 'kharis-hls-player-${streamUrl.hashCode}';

  void _ensureRegistered() {
    if (_registered.contains(_viewType)) return;
    _registered.add(_viewType);
    final url = streamUrl;
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      final iframe = web.HTMLIFrameElement();
      // srcdoc is typed JSAny in package:web 1.x; use setAttribute instead.
      iframe.setAttribute('srcdoc', _hlsHtml(url));
      iframe.style.border = 'none';
      iframe.style.width = '100%';
      iframe.style.height = '100%';
      iframe.allow = 'autoplay; fullscreen; encrypted-media';
      iframe.allowFullscreen = true;
      return iframe;
    });
  }

  /// Minimal self-contained HTML page with hls.js for cross-browser HLS.
  /// Autoplay is muted to satisfy Chrome/Firefox autoplay policy.
  static String _hlsHtml(String url) => '''<!DOCTYPE html>
<html>
<head>
<meta name="viewport" content="width=device-width,initial-scale=1">
<style>
  *{margin:0;padding:0;box-sizing:border-box}
  body{background:#000;display:flex;align-items:center;justify-content:center;height:100vh}
  video{width:100%;height:100%;object-fit:contain}
</style>
</head>
<body>
<video id="v" muted autoplay playsinline controls></video>
<script src="https://cdn.jsdelivr.net/npm/hls.js@latest/dist/hls.min.js"></script>
<script>
var v=document.getElementById('v');
var src="${url.replaceAll('"', '&quot;')}";
if(window.Hls&&Hls.isSupported()){
  var h=new Hls();
  h.loadSource(src);
  h.attachMedia(v);
  h.on(Hls.Events.MANIFEST_PARSED,function(){v.play().catch(function(){});});
} else if(v.canPlayType('application/vnd.apple.mpegurl')){
  v.src=src;
  v.play().catch(function(){});
}
</script>
</body>
</html>''';

  @override
  Widget build(BuildContext context) {
    _ensureRegistered();
    return HtmlElementView(viewType: _viewType);
  }
}
