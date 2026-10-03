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
    this.eventId,
    this.linkUrl,
    this.ctaLabel,
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

  /// When the announcement stops being relevant: end of the chosen day,
  /// Europe/London. `null` means it never expires.
  final DateTime? expiresAt;

  /// `events/{eventId}` this announcement promotes; tapping it opens that
  /// event. `null` for a plain message.
  final String? eventId;

  /// Optional call-to-action link (http/https) with its button [ctaLabel].
  final String? linkUrl;

  /// Button text for [linkUrl]; the Studio defaults it to 'Learn more'.
  final String? ctaLabel;

  /// True once [expiresAt] has passed. Expired items must not be shown.
  bool get isExpired {
    final until = expiresAt;
    return until != null && !until.isAfter(DateTime.now());
  }

  /// True while [publishedAt] is still in the future: the Studio scheduled it
  /// and members must not see it yet (the server neither serves nor pushes it).
  bool get isScheduled => publishedAt.isAfter(DateTime.now());

  /// What a member may see right now: published and not expired.
  bool get isLive => !isScheduled && !isExpired;

  /// True when this announcement is visible to a member at [memberBranch].
  /// A blank branch is all-campus, exactly as the API reads it.
  bool isVisibleTo(String? memberBranch) {
    final scope = branch?.trim() ?? '';
    return scope.isEmpty || memberBranch == null || scope == memberBranch;
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
  /// Only [NewsItem.isLive] items are emitted, so the offline / fallback path
  /// honours scheduling and expiry exactly like the API path; over-fetches so
  /// the post-filter still fills a page. Admin surfaces pass
  /// [includeExpired] to also receive scheduled and expired items, so they
  /// stay editable instead of vanishing from the CMS.
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
        .map(
          (snap) => snap.docs
              .map(_docToNews)
              .where((n) => includeExpired || n.isLive)
              .where((n) => n.isVisibleTo(branch))
              .take(limit)
              .toList(),
        )
        .handleError((Object _) {})
        .defaultIfEmpty(const []);
  }

  // ── Admin writes ────────────────────────────────────────────────────────────

  /// Creates an announcement. [publishAt] schedules it (null = now: the
  /// server timestamp); [expiresAt] is the instant it disappears. The
  /// pushPendingAnnouncements poller sends the push once [publishAt] passes.
  Future<void> addNews({
    required String title,
    required String type,
    String? body,
    String? imageUrl,
    String? branch,
    DateTime? publishAt,
    DateTime? expiresAt,
    String? eventId,
    String? linkUrl,
    String? ctaLabel,
  }) {
    return _firestore.collection('news').add({
      ..._formFields(
        title: title,
        type: type,
        body: body,
        imageUrl: imageUrl,
        branch: branch,
        expiresAt: expiresAt,
        eventId: eventId,
        linkUrl: linkUrl,
        ctaLabel: ctaLabel,
      ),
      'publishedAt': publishAt == null
          ? FieldValue.serverTimestamp()
          : Timestamp.fromDate(publishAt),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Updates the form-owned fields of an announcement. [publishAt] is only
  /// written when given, so editing copy never re-dates (or re-pushes) it;
  /// push bookkeeping (`pushedAt`, `createdAt`) is never touched.
  Future<void> updateNews(
    String id, {
    required String title,
    required String type,
    String? body,
    String? imageUrl,
    String? branch,
    DateTime? publishAt,
    DateTime? expiresAt,
    String? eventId,
    String? linkUrl,
    String? ctaLabel,
  }) {
    return _firestore.collection('news').doc(id).update({
      ..._formFields(
        title: title,
        type: type,
        body: body,
        imageUrl: imageUrl,
        branch: branch,
        expiresAt: expiresAt,
        eventId: eventId,
        linkUrl: linkUrl,
        ctaLabel: ctaLabel,
      ),
      if (publishAt != null) 'publishedAt': Timestamp.fromDate(publishAt),
    });
  }

  static Map<String, Object?> _formFields({
    required String title,
    required String type,
    String? body,
    String? imageUrl,
    String? branch,
    DateTime? expiresAt,
    String? eventId,
    String? linkUrl,
    String? ctaLabel,
  }) {
    final link = _blankToNull(linkUrl);
    return {
      'title': title,
      'type': type,
      'body': _blankToNull(body),
      'imageUrl': _blankToNull(imageUrl),
      // '' would read as all-campus in one place and a campus in another.
      'branch': _blankToNull(branch),
      'expiresAt': expiresAt == null ? null : Timestamp.fromDate(expiresAt),
      'eventId': _blankToNull(eventId),
      'linkUrl': link,
      'ctaLabel': link == null
          ? null
          : (_blankToNull(ctaLabel) ?? 'Learn more'),
    };
  }

  static String? _blankToNull(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  Future<void> deleteNews(String id) =>
      _firestore.collection('news').doc(id).delete();

  NewsItem _docToNews(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final branch = (data['branch'] as String?)?.trim();
    return NewsItem(
      id: doc.id,
      title: data['title'] as String? ?? '',
      type: NewsItem.normaliseType(data['type'] as String?),
      publishedAt:
          (data['publishedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      body: data['body'] as String?,
      imageUrl: data['imageUrl'] as String?,
      branch: branch == null || branch.isEmpty ? null : branch,
      expiresAt: (data['expiresAt'] as Timestamp?)?.toDate(),
      eventId: _blankToNull(data['eventId'] as String?),
      linkUrl: _blankToNull(data['linkUrl'] as String?),
      ctaLabel: _blankToNull(data['ctaLabel'] as String?),
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
