import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// A single announcement: a message from the church.
///
/// Deliberately NOT an event. An event is a dated, located, RSVP-able
/// occurrence and lives in the `events` collection behind `Event`; an
/// announcement is a headline plus optional body and image that may expire.
/// Nothing here carries a start time, a venue, or an RSVP.
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

  /// The announcement categories an admin may choose. `Event` is absent by
  /// design — anything with a date and a venue belongs in `events`.
  static const List<String> types = [
    'Announcement',
    'Ministry',
    'Notice',
    'Update',
  ];

  /// Coerces a stored `type` onto [types]. Docs written before `Event` was
  /// removed from the admin dropdown come back as plain announcements so no
  /// `news` doc can present itself as an event.
  static String normaliseType(String? raw) {
    final value = raw?.trim();
    if (value == null || value.isEmpty) return types.first;
    return types.contains(value) ? value : types.first;
  }

  final String id;
  final String title;
  final String type;
  final DateTime publishedAt;
  final String? body;
  final String? imageUrl;

  /// Campus this announcement is scoped to; `null` means all-campus.
  final String? branch;

  /// When the announcement stops being relevant. Set by the web admin portal
  /// (`admin/index.html`); `null` means it never expires.
  final DateTime? expiresAt;

  /// True once [expiresAt] has passed. Expired items must not be shown.
  bool get isExpired {
    final until = expiresAt;
    return until != null && until.isBefore(DateTime.now());
  }

  /// True when this announcement is visible to a member at [memberBranch].
  bool isVisibleTo(String? memberBranch) =>
      branch == null || memberBranch == null || branch == memberBranch;
}

/// Streams news/announcements from the Firestore `news` collection.
///
/// Realtime: snapshot listeners push admin-panel edits to the app instantly.
/// Falls back to a static list when Firestore is unreachable.
class NewsRepository {
  NewsRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  /// How many docs a branch-scoped read pulls before filtering in memory.
  /// The offline path cannot run the API's two-query branch/all-campus merge,
  /// so it leans on a window wide enough that a branch's notice never falls
  /// off the end — 100 docs is one cheap page and more announcements than the
  /// church has ever had live at once.
  static const int _scopedFetchWindow = 100;

  /// Live announcements, newest first.
  ///
  /// When [branch] is given only that campus's announcements plus all-campus
  /// ones are emitted, matching the `getAnnouncements?branch=` contract.
  ///
  /// Expired items (`expiresAt` in the past) are dropped so the offline /
  /// fallback path honours expiry exactly like the API path; over-fetches so
  /// the post-filter still fills a page. Admin surfaces pass
  /// [includeExpired] so an expired item stays editable instead of vanishing
  /// from the CMS the moment it stops being shown to members.
  Stream<List<NewsItem>> watchNews({
    int limit = 10,
    bool includeExpired = false,
    String? branch,
  }) {
    final fetch = branch != null
        ? _scopedFetchWindow
        : (includeExpired ? limit : limit * 2);
    return _firestore
        .collection('news')
        .orderBy('publishedAt', descending: true)
        .limit(fetch)
        .snapshots()
        .map((snap) => snap.docs
            .map(_docToNews)
            .where((n) => includeExpired || !n.isExpired)
            .where((n) => n.isVisibleTo(branch))
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
      type: NewsItem.normaliseType(data['type'] as String?),
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
