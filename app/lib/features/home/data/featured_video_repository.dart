import 'package:flutter/foundation.dart';
import 'package:kharis_app/core/services/content_api.dart';
import 'package:kharis_app/core/utils/media_url.dart';
import 'package:kharis_app/features/messages/data/kharis_api_sermon_repository.dart';

/// A YouTube clip the Content Studio features for one of its sites.
@immutable
class FeaturedVideo {
  const FeaturedVideo({
    required this.workspace,
    required this.url,
    required this.videoId,
    required this.title,
    required this.thumbnailUrl,
    this.updatedAt,
  });

  /// The Studio site the clip is for: `app`, `general`, `kharis` or `kp2`.
  final String workspace;

  /// The YouTube link as the Studio stored it; opens the full video.
  final String url;

  /// The 11-character YouTube id parsed from [url].
  final String videoId;

  final String title;

  /// The Studio's thumbnail, else YouTube's own `hqdefault` frame.
  final String thumbnailUrl;

  final DateTime? updatedAt;

  @override
  String toString() => 'FeaturedVideo($workspace, $videoId, $title)';
}

/// Reads the Content Studio `featured_videos` table and picks the one clip
/// the app features.
class FeaturedVideoRepository {
  FeaturedVideoRepository({required this._api});

  final ContentApi _api;

  static const _table = 'featured_videos';
  static const _query = {'order': 'updated_at.desc'};

  /// Workspaces whose clip the app may feature, best first: the app's own,
  /// then the shared General one, then the main church site's (`kp2` is the
  /// KP2 site and never the app's).
  static const workspacePrecedence = ['app', 'general', 'kharis'];

  /// The clip the app features, or null when the Studio has none for it.
  /// Throws when the table cannot be read and nothing is cached.
  Future<FeaturedVideo?> getFeaturedVideo() async =>
      pick(await _api.load(_table, query: _query));

  // ── Mapping (pure; tested directly) ────────────────────────────────────────

  /// The best row by [workspacePrecedence], the most recently updated within
  /// a workspace. Rows without a readable YouTube link or a title are
  /// skipped.
  static FeaturedVideo? pick(List<Map<String, dynamic>> rows) {
    final videos = [for (final row in rows) ?fromRow(row)];
    for (final workspace in workspacePrecedence) {
      final candidates = videos.where((v) => v.workspace == workspace).toList()
        ..sort(
          (a, b) => (b.updatedAt ?? DateTime(0)).compareTo(
            a.updatedAt ?? DateTime(0),
          ),
        );
      if (candidates.isNotEmpty) return candidates.first;
    }
    return null;
  }

  static FeaturedVideo? fromRow(Map<String, dynamic> row) {
    final workspace = _text(row['workspace'])?.toLowerCase();
    final url = _text(row['url']);
    final title = _text(row['title']);
    final videoId = youTubeVideoId(url);
    if (workspace == null || url == null || title == null || videoId == null) {
      return null;
    }
    return FeaturedVideo(
      workspace: workspace,
      url: url,
      videoId: videoId,
      title: title,
      thumbnailUrl:
          usableMediaUrl(_text(row['thumbnail_url'])) ??
          'https://i.ytimg.com/vi/$videoId/hqdefault.jpg',
      updatedAt: DateTime.tryParse(_text(row['updated_at']) ?? '')?.toLocal(),
    );
  }

  static String? _text(Object? v) {
    if (v is! String) return null;
    final t = v.trim();
    return t.isEmpty ? null : t;
  }
}
