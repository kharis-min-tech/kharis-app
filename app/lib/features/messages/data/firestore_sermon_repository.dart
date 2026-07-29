import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:kharis_app/core/utils/html_entities.dart';
import 'package:kharis_app/core/utils/sermon_categorizer.dart';
import 'package:kharis_app/shared/models/sermon.dart';
import 'sermon_repository.dart';
import 'sermon_repository_base.dart';

/// Reads sermons from the Firestore `sermons` collection.
///
/// Falls back to the same mock data used by [SermonRepository] if Firestore
/// is unavailable or a document is malformed.
class FirestoreSermonRepository extends AbstractSermonRepository {
  FirestoreSermonRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  // Keep a single mock source so both repos share identical fallback data.
  static final _mock = SermonRepository();

  /// Fetches AUDIO sermons (the Spotify-style Messages surface).
  ///
  /// [limit] – maximum documents to return (default 20).
  /// [offset] is not directly supported by Firestore; kept for API parity.
  /// [source] – unused by default; reserved for multi-source collections.
  /// [type] – defaults to 'audio'; pass 'video' for the video surface.
  /// Filtering happens client-side over a small window so no composite
  /// Firestore index is required; legacy docs without a `type` field count
  /// as audio when they carry no videoId.
  @override
  Future<List<Sermon>> getSermons({
    int limit = 0,
    int offset = 0,
    String? source,
    String? type,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('sermons')
          .orderBy('publishedAt', descending: true)
          .limit(500)
          .get();
      final wanted = type ?? 'audio';
      final fromFirestore = snapshot.docs.map(_docToSermon).where((s) {
        final docType = (s.source == 'youtube' || s.videoId != null)
            ? 'video'
            : 'audio';
        return docType == wanted;
      }).toList();

      // Firestore may hold a partial sync (or nothing) until the backend
      // functions run on schedule. Merge with the RSS/embedded dataset and
      // dedupe by title so the library is always the full catalogue.
      final fallback = await _mock.getSermons();
      final seen = <String>{
        for (final s in fromFirestore) _dedupeKey(s),
      };
      final merged = [
        ...fromFirestore,
        ...fallback.where((s) => seen.add(_dedupeKey(s))),
      ]..sort((a, b) => (b.publishedAt ?? DateTime(0))
          .compareTo(a.publishedAt ?? DateTime(0)));

      if (merged.isEmpty) return fallback;
      return limit > 0 ? merged.take(limit).toList() : merged;
    } catch (_) {
      return _mock.getSermons();
    }
  }

  static String _dedupeKey(Sermon s) =>
      s.title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

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

  // ── Admin writes ────────────────────────────────────────────────────────────

  /// Adds a new sermon to the Firestore `sermons` collection.
  Future<String> addSermon({
    required String title,
    required String speaker,
    required String audioUrl,
    String? artworkUrl,
    int? durationSeconds,
    DateTime? publishedAt,
    String? series,
    String? description,
    String? category,
    String? videoId,
    String? source,
    bool isFeatured = false,
  }) async {
    final ref = await _firestore.collection('sermons').add({
      'title': title,
      'speaker': speaker,
      'audioUrl': audioUrl,
      'thumbnailUrl': artworkUrl,
      'artworkUrl': artworkUrl,
      'duration': durationSeconds,
      'publishedAt': publishedAt != null
          ? Timestamp.fromDate(publishedAt)
          : FieldValue.serverTimestamp(),
      'series': series,
      'description': description,
      'category': category ?? sermonCategory(title),
      'videoId': videoId,
      'source': source ?? 'audio',
      'isFeatured': isFeatured,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  /// Updates an existing sermon document.
  Future<void> updateSermon(
    String id, {
    String? title,
    String? speaker,
    String? audioUrl,
    String? artworkUrl,
    int? durationSeconds,
    DateTime? publishedAt,
    String? series,
    String? description,
    String? category,
    String? videoId,
    String? source,
    bool? isFeatured,
  }) {
    final data = <String, dynamic>{};
    if (title != null) {
      data['title'] = title;
      data['category'] = category ?? sermonCategory(title);
    }
    if (speaker != null) data['speaker'] = speaker;
    if (audioUrl != null) data['audioUrl'] = audioUrl;
    if (artworkUrl != null) {
      data['thumbnailUrl'] = artworkUrl;
      data['artworkUrl'] = artworkUrl;
    }
    if (durationSeconds != null) data['duration'] = durationSeconds;
    if (publishedAt != null) data['publishedAt'] = Timestamp.fromDate(publishedAt);
    if (series != null) data['series'] = series;
    if (description != null) data['description'] = description;
    if (category != null) data['category'] = category;
    if (videoId != null) data['videoId'] = videoId;
    if (source != null) data['source'] = source;
    if (isFeatured != null) data['isFeatured'] = isFeatured;
    return _firestore.collection('sermons').doc(id).update(data);
  }

  /// Deletes a sermon document.
  Future<void> deleteSermon(String id) =>
      _firestore.collection('sermons').doc(id).delete();

  /// Toggles the featured flag on a sermon.
  Future<void> setFeatured(String id, bool featured) =>
      _firestore.collection('sermons').doc(id).update({'isFeatured': featured});

  /// Streams sermons for the admin panel, newest first.
  Stream<List<Sermon>> watchSermons({int limit = 100}) {
    return _firestore
        .collection('sermons')
        .orderBy('publishedAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map(_docToSermon).toList());
  }

  /// Prefix search on the `title` field using Firestore range queries.
  ///
  /// Falls back to in-memory filter over mock data when Firestore is
  /// unreachable.
  Future<List<Sermon>> search(String query, {int limit = 20}) async {
    if (query.isEmpty) return getSermons(limit: limit);
    try {
      final end = query.substring(0, query.length - 1) +
          String.fromCharCode(query.codeUnitAt(query.length - 1) + 1);
      final snapshot = await _firestore
          .collection('sermons')
          .where('title', isGreaterThanOrEqualTo: query)
          .where('title', isLessThan: end)
          .limit(limit)
          .get();
      return snapshot.docs.map(_docToSermon).toList();
    } catch (_) {
      final q = query.toLowerCase();
      final catalogue = await loadCatalogue();
      return catalogue
          .where((s) => s.title.toLowerCase().contains(q))
          .toList();
    }
  }

  @override
  Future<List<Sermon>> loadCatalogue() => _mock.loadCatalogue();

  // ── Mapping ────────────────────────────────────────────────────────────────

  Sermon _docToSermon(QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
      _mapData(doc.id, doc.data());

  Sermon _mapData(String id, Map<String, dynamic> data) {
    return Sermon(
      id: id,
      title: decodeHtmlEntities(data['title'] as String? ?? ''),
      speaker: data['speaker'] as String? ?? '',
      audioUrl: data['audioUrl'] as String? ?? '',
      artworkUrl: data['thumbnailUrl'] as String? ?? data['artworkUrl'] as String?,
      duration: data['duration'] != null
          ? Duration(seconds: (data['duration'] as num).toInt())
          : null,
      publishedAt: (data['publishedAt'] as Timestamp?)?.toDate(),
      series: data['series'] as String?,
      description: data['description'] as String?,
      artworkColor: (data['artworkColor'] as num?)?.toInt(),
      category: data['category'] as String? ??
          sermonCategory(data['title'] as String? ?? ''),
      videoId: data['videoId'] as String?,
      source: data['source'] as String?,
      isFeatured: data['isFeatured'] as bool? ?? false,
    );
  }
}
