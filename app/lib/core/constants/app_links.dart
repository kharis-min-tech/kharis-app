/// The links the app hands out, and the deep-link paths it answers.
///
/// Every shared link points at [host], which serves the Kharis web app
/// (Firebase Hosting) and is verified for the native apps through
/// `/.well-known/apple-app-site-association` and
/// `/.well-known/assetlinks.json` (see `app/web/.well-known/`). A link
/// therefore opens the installed app when there is one and the web app at the
/// same URL otherwise. Moving to a custom domain is a change to [host] plus
/// the iOS associated-domains entitlement and the Android intent filter.
///
/// Paths:
/// - `/m/<canonicalId>[?t=<seconds>][&v=1]`: a message. The id is the
///   `NoteTimelineKey` canonical, so the audio and video variants of one
///   message share one link; `t` is a position on the AUDIO timeline (the
///   one resume points and notes use); `v=1` asks for the video.
/// - `/e/<eventId>`: an event.
/// - `/a/<newsId>`: an announcement.
abstract final class AppLinks {
  /// The one host every shared link uses.
  static const String host = 'kharis-app-47c49.web.app';

  /// Android application id, also the App Links package.
  static const String androidPackage = 'com.kharis.church';

  /// The app's Play Store listing.
  static const String playStoreUrl =
      'https://play.google.com/store/apps/details?id=$androidPackage';

  /// First path segment of each deep-link kind.
  static const String messageSegment = 'm';
  static const String eventSegment = 'e';
  static const String announcementSegment = 'a';

  /// Query parameter carrying a message position in whole seconds.
  static const String timeParam = 't';

  /// Query parameter asking for the video (`v=1`).
  static const String videoParam = 'v';

  /// The closing line of every share text.
  static String shareLine(Uri link) => 'Open in the Kharis app: $link';

  /// A message at [canonicalId]. [at] adds `t` when it is at least one
  /// second in; [video] adds `v=1`.
  static Uri message(String canonicalId, {Duration? at, bool video = false}) {
    final seconds = at?.inSeconds ?? 0;
    final query = <String, String>{
      if (seconds > 0) timeParam: '$seconds',
      if (video) videoParam: '1',
    };
    return Uri(
      scheme: 'https',
      host: host,
      pathSegments: [messageSegment, canonicalId],
      queryParameters: query.isEmpty ? null : query,
    );
  }

  /// The event [eventId].
  static Uri event(String eventId) =>
      Uri(scheme: 'https', host: host, pathSegments: [eventSegment, eventId]);

  /// The announcement [newsId].
  static Uri announcement(String newsId) => Uri(
    scheme: 'https',
    host: host,
    pathSegments: [announcementSegment, newsId],
  );

  /// Whether [path] is one of the shared-link paths (`/m/…`, `/e/…`,
  /// `/a/…`) with an id.
  static bool isSharedPath(String path) {
    final segments = Uri(path: path).pathSegments;
    return segments.length == 2 &&
        segments[1].isNotEmpty &&
        const {
          messageSegment,
          eventSegment,
          announcementSegment,
        }.contains(segments[0]);
  }

  /// The position a message link asks for: `t` as whole, non-negative
  /// seconds; null when absent or malformed.
  static Duration? parseTime(String? raw) {
    final seconds = int.tryParse(raw ?? '');
    return seconds == null || seconds < 0 ? null : Duration(seconds: seconds);
  }

  /// Whether a message link asks for the video.
  static bool parseVideo(String? raw) => raw == '1';
}
