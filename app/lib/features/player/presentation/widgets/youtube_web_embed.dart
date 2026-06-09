// Conditional export: real iframe embed on web, inert stub elsewhere.
export 'youtube_web_embed_stub.dart'
    if (dart.library.js_interop) 'youtube_web_embed_web.dart';
