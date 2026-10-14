import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:kharis_app/core/utils/html_entities.dart';
import 'package:kharis_app/core/utils/sermon_categorizer.dart';
import 'package:kharis_app/shared/models/sermon.dart';

/// Sources of hand-added audio sermons. The `sermons`
/// collection also holds YouTube mirrors (`yt_<videoId>`, source 'youtube');
/// those carry no audio and must not crowd hand-added sermons out of the
/// member library's window.
const List<String> kCmsAudioSources = ['audio', 'admin'];

/// Reads the Firestore `sermons` collection (YouTube mirrors written by
/// `syncYouTube` and earlier hand-added sermons).
class FirestoreSermonRepository {
  FirestoreSermonRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  /// Fetches a single sermon by its Firestore document ID.
  Future<Sermon?> getSermonById(String id) async {
    try {
      final doc = await _firestore.collection('sermons').doc(id).get();
      if (!doc.exists || doc.data() == null) return null;
      return _mapData(doc.id, doc.data()!);
    } catch (_) {
      return null;
    }
  }

  /// Streams hand-added CMS sermons (see [kCmsAudioSources]) for the member
  /// library, newest first. Uses the (source, publishedAt) index.
  Stream<List<Sermon>> watchCmsSermons({int limit = 100}) {
    return _firestore
        .collection('sermons')
        .where('source', whereIn: kCmsAudioSources)
        .orderBy('publishedAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map(_docToSermon).toList());
  }

  /// Streams the Studio-starred sermons (`isFeatured == true`), newest first.
  /// Uses the (isFeatured, publishedAt) index.
  Stream<List<Sermon>> watchPinnedFeatured({int limit = 5}) {
    return _firestore
        .collection('sermons')
        .where('isFeatured', isEqualTo: true)
        .orderBy('publishedAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map(_docToSermon).toList());
  }

  // ── Mapping ────────────────────────────────────────────────────────────────

  Sermon _docToSermon(QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
      _mapData(doc.id, doc.data());

  Sermon _mapData(String id, Map<String, dynamic> data) {
    return Sermon(
      id: id,
      title: decodeHtmlEntities(data['title'] as String? ?? ''),
      speaker: data['speaker'] as String? ?? '',
      audioUrl: data['audioUrl'] as String? ?? '',
      artworkUrl:
          data['thumbnailUrl'] as String? ?? data['artworkUrl'] as String?,
      duration: data['duration'] != null
          ? Duration(seconds: (data['duration'] as num).toInt())
          : null,
      publishedAt: (data['publishedAt'] as Timestamp?)?.toDate(),
      series: data['series'] as String?,
      description: data['description'] as String?,
      artworkColor: (data['artworkColor'] as num?)?.toInt(),
      category: topicOf(
        title: data['title'] as String? ?? '',
        description: data['description'] as String?,
        category: data['category'] as String?,
      ),
      videoId: data['videoId'] as String?,
      source: data['source'] as String?,
      isFeatured: data['isFeatured'] as bool? ?? false,
    );
  }
}
