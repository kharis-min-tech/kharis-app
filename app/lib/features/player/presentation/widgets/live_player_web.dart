// Conditional export: real HLS iframe embed on web, inert stub elsewhere.
export 'live_player_web_stub.dart'
    if (dart.library.js_interop) 'live_player_web_impl.dart';
