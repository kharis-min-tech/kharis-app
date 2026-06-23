// Platform-specific plain-text fetch for public XML/RSS feeds.
//
// Web (default) uses the browser Fetch API; Dio's XHR adapter throws on some
// cross-origin feeds such as YouTube's, where native fetch succeeds. Native
// platforms (anything with dart:io) use Dio.
export 'feed_fetch_web.dart' if (dart.library.io) 'feed_fetch_io.dart';
