import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

@immutable
class NewsItem {
  const NewsItem({
    required this.id,
    required this.title,
    required this.type,
    required this.publishedAt,
    this.body,
    this.imageUrl,
    this.branch,
    this.expiresAt,
  });

  final String id;
  final String title;
  final String type;
  final DateTime publishedAt;
  final String? body;
  final String? imageUrl;
  final String? branch;

  /// When the announcement stops being relevant. Set by the web admin portal
  /// (`admin/index.html`); `null` means it never expires.
  final DateTime? expiresAt;

  /// True once [expiresAt] has passed. Expired items must not be shown.
  bool get isExpired {
    final until = expiresAt;
    return until != null && until.isBefore(DateTime.now());
  }
}

/// Streams news/announcements from the Firestore `news` collection.
///
/// Realtime: snapshot listeners push admin-panel edits to the app instantly.
/// Falls back to a static list when Firestore is unreachable.
class NewsRepository {
  NewsRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  /// Live announcements, newest first.
  ///
  /// Expired items (`expiresAt` in the past) are dropped so the offline /
  /// fallback path honours expiry exactly like the API path; over-fetches so
  /// the post-filter still fills a page. Admin surfaces pass
  /// [includeExpired] so an expired item stays editable instead of vanishing
  /// from the CMS the moment it stops being shown to members.
  Stream<List<NewsItem>> watchNews({
    int limit = 10,
    bool includeExpired = false,
  }) {
    return _firestore
        .collection('news')
        .orderBy('publishedAt', descending: true)
        .limit(includeExpired ? limit : limit * 2)
        .snapshots()
        .map((snap) => snap.docs
            .map(_docToNews)
            .where((n) => includeExpired || !n.isExpired)
            .take(limit)
            .toList())
        .handleError((Object _) {})
        .defaultIfEmpty(const []);
  }

  // ── Admin writes ────────────────────────────────────────────────────────────

  Future<void> addNews({
    required String title,
    required String type,
    String? body,
    String? imageUrl,
    String? branch,
  }) {
    return _firestore.collection('news').add({
      'title': title,
      'type': type,
      'body': body,
      'imageUrl': imageUrl,
      'branch': branch,
      'publishedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateNews(
    String id, {
    required String title,
    required String type,
    String? body,
    String? imageUrl,
    String? branch,
  }) {
    return _firestore.collection('news').doc(id).update({
      'title': title,
      'type': type,
      'body': body,
      'imageUrl': imageUrl,
      'branch': branch,
    });
  }

  Future<void> deleteNews(String id) =>
      _firestore.collection('news').doc(id).delete();

  NewsItem _docToNews(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    return NewsItem(
      id: doc.id,
      title: data['title'] as String? ?? '',
      type: data['type'] as String? ?? 'Announcement',
      publishedAt:
          (data['publishedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      body: data['body'] as String?,
      imageUrl: data['imageUrl'] as String?,
      branch: data['branch'] as String?,
      expiresAt: (data['expiresAt'] as Timestamp?)?.toDate(),
    );
  }

}

extension<T> on Stream<List<T>> {
  /// Emits [fallback] if the stream completes/errors before any event.
  Stream<List<T>> defaultIfEmpty(List<T> fallback) async* {
    var emitted = false;
    try {
      await for (final value in this) {
        emitted = true;
        yield value;
      }
    } catch (_) {
      // Swallow and fall through to the fallback below.
    }
    if (!emitted) yield fallback;
  }
}
