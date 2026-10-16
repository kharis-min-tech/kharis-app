import 'package:flutter/foundation.dart';
import 'package:kharis_app/core/services/content_api.dart';
import 'package:kharis_app/features/messages/data/kharis_api_sermon_repository.dart'
    show youTubeVideoId;

@immutable
class LiveStatus {
  const LiveStatus({required this.isLive, this.videoId, this.title, this.url});

  final bool isLive;

  /// YouTube id of the stream, when [url] is a YouTube video link.
  final String? videoId;
  final String? title;

  /// The stream link as the Studio stored it.
  final String? url;

  static const notLive = LiveStatus(isLive: false);

  /// The Content Studio `app_config` value under key `live_stream`:
  /// `{url, title, enabled | is_live}`. Off, missing or unreadable is
  /// [notLive].
  static LiveStatus fromConfig(Object? value) {
    if (value is! Map) return notLive;
    final on = value['enabled'] == true || value['is_live'] == true;
    if (!on) return notLive;
    final url = _text(value['url']);
    return LiveStatus(
      isLive: true,
      url: url,
      videoId: youTubeVideoId(url),
      title: _text(value['title']),
    );
  }

  static String? _text(Object? v) {
    if (v is! String) return null;
    final t = v.trim();
    return t.isEmpty ? null : t;
  }
}

/// Reads the live-stream switch from the Content Studio `app_config` table.
class LiveRepository {
  LiveRepository({required this._api});

  final ContentApi _api;

  static const _query = {'key': 'eq.live_stream'};

  /// The Studio's current state. Read from the network only: a saved "live"
  /// would announce a stream long after it ended. Any failure reads as
  /// [LiveStatus.notLive].
  Stream<LiveStatus> watchLiveStatus() async* {
    try {
      yield fromRows(await _api.fetch('app_config', query: _query));
    } catch (_) {
      yield LiveStatus.notLive;
    }
  }

  static LiveStatus fromRows(List<Map<String, dynamic>> rows) {
    for (final row in rows) {
      if (row['key'] == 'live_stream') {
        return LiveStatus.fromConfig(row['value']);
      }
    }
    return LiveStatus.notLive;
  }
}
