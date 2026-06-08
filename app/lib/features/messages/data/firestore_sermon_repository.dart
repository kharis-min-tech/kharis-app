import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../shared/models/sermon.dart';
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

  /// Fetches sermons with optional filtering.
  ///
  /// [limit] – maximum documents to return (default 20).
  /// [offset] is not directly supported by Firestore; pass [startAfterDoc]
  ///   for cursor-based pagination instead (offset kept for API parity).
  /// [source] – unused by default; reserved for multi-source collections.
  /// [type] – filters by the `category` field when provided.
  @override
  Future<List<Sermon>> getSermons({
    int limit = 20,
    int offset = 0,
    String? source,
    String? type,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _firestore
          .collection('sermons')
          .orderBy('publishedAt', descending: true);
      if (type != null) query = query.where('category', isEqualTo: type);
      if (limit > 0) query = query.limit(limit);
      final snapshot = await query.get();
      return snapshot.docs.map(_docToSermon).toList();
    } catch (_) {
      return getMockSermons();
    }
  }

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
      return getMockSermons()
          .where((s) => s.title.toLowerCase().contains(q))
          .toList();
    }
  }

  @override
  List<Sermon> getMockSermons() => _mock.getMockSermons();

  // ── Mapping ────────────────────────────────────────────────────────────────

  Sermon _docToSermon(QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
      _mapData(doc.id, doc.data());

  Sermon _mapData(String id, Map<String, dynamic> data) {
    return Sermon(
      id: id,
      title: data['title'] as String? ?? '',
      speaker: data['speaker'] as String? ?? '',
      audioUrl: data['audioUrl'] as String? ?? '',
      artworkUrl: data['artworkUrl'] as String?,
      duration: data['durationSeconds'] != null
          ? Duration(seconds: (data['durationSeconds'] as num).toInt())
          : null,
      publishedAt: (data['publishedAt'] as Timestamp?)?.toDate(),
      series: data['series'] as String?,
      description: data['description'] as String?,
      artworkColor: (data['artworkColor'] as num?)?.toInt(),
      category: data['category'] as String?,
    );
  }
}
