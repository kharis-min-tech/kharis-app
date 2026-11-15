import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'package:kharis_app/core/utils/html_entities.dart';
import 'package:kharis_app/shared/models/sermon.dart';

/// A short clip from the church's YouTube channel.
@immutable
class Moment {
  const Moment({
    required this.videoId,
    required this.title,
    required this.thumbnailUrl,
    this.duration,
    this.publishedAt,
  });

  /// YouTube video id.
  final String videoId;
  final String title;

  /// A 4:3 still. YouTube letterboxes an upright video inside it.
  final String thumbnailUrl;

  /// Null when the mirror has no length for it (a clip known only by its
  /// `#shorts` tag).
  final Duration? duration;
  final DateTime? publishedAt;

  /// The clip on YouTube, in the Shorts player.
  String get youtubeUrl => 'https://www.youtube.com/shorts/$videoId';
}

/// Reads Moments from the YouTube mirror in Firestore.
///
/// `syncYouTube` copies the channel's newest uploads into `sermons` as
/// `yt_<videoId>` documents with `source: 'youtube'`. The mirror has no
/// field that says "this is a Short" (`type` is `video` for every upload),
/// so a Moment is told apart by [Sermon.isShortClip], the rule that already
/// keeps these clips out of Messages: a video that runs under
/// [kMinMessageLength], or whose title carries `#short`.
class MomentsRepository {
  MomentsRepository(this._firestore);

  final FirebaseFirestore _firestore;

  /// How many of the newest uploads are read. About half of them are clips.
  static const int uploadWindow = 60;

  /// The clips among the newest [uploadWindow] uploads, newest first.
  Future<List<Moment>> latest() async {
    final snapshot = await _firestore
        .collection('sermons')
        .where('source', isEqualTo: 'youtube')
        .orderBy('publishedAt', descending: true)
        .limit(uploadWindow)
        .get();
    return [for (final doc in snapshot.docs) ?_moment(doc.data())];
  }

  static Moment? _moment(Map<String, dynamic> data) {
    final videoId = (data['videoId'] as String?)?.trim() ?? '';
    if (videoId.isEmpty) return null;
    final title = decodeHtmlEntities(data['title'] as String? ?? '');
    final seconds = (data['duration'] as num?)?.toInt() ?? 0;
    final duration = seconds > 0 ? Duration(seconds: seconds) : null;
    final isClip = Sermon(
      id: 'yt_$videoId',
      title: title,
      speaker: '',
      audioUrl: '',
      videoId: videoId,
      duration: duration,
    ).isShortClip;
    if (!isClip) return null;
    final thumbnail = (data['thumbnailUrl'] as String?)?.trim() ?? '';
    return Moment(
      videoId: videoId,
      title: title,
      thumbnailUrl: thumbnail.isNotEmpty
          ? thumbnail
          : 'https://i.ytimg.com/vi/$videoId/hqdefault.jpg',
      duration: duration,
      publishedAt: (data['publishedAt'] as Timestamp?)?.toDate(),
    );
  }
}
