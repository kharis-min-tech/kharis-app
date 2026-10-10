import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Studio notifications: pushes an admin composes in Content Studio, stored
/// as `notifications/{id}` and sent by `backend/functions/src/notifications.ts`.
///
/// Field limits mirror the `notifications` block in `firestore.rules` and the
/// function's own validation; a doc outside them is rejected by both.
const int kNotificationTitleMax = 65;
const int kNotificationBodyMax = 240;
const int kNotificationLinkMax = 500;

/// Most notifications the inbox and Studio history read at once.
const int kNotificationPageSize = 50;

/// Who a Studio notification goes to.
@immutable
class NotificationAudience {
  const NotificationAudience.all() : type = allType, branch = null;

  const NotificationAudience.branch(String this.branch) : type = branchType;

  /// Staff devices only: every signed-in Studio user's device follows the
  /// `studio_test` topic.
  const NotificationAudience.test() : type = testType, branch = null;

  /// Stored `audience.type` values.
  static const String allType = 'all';
  static const String branchType = 'branch';
  static const String testType = 'test';

  final String type;

  /// Branch NAME when [type] is [branchType].
  final String? branch;

  /// The stored shape; null when [raw] is none of the three.
  static NotificationAudience? fromJson(Object? raw) {
    if (raw is! Map) return null;
    switch (raw['type']) {
      case allType:
        return const NotificationAudience.all();
      case testType:
        return const NotificationAudience.test();
      case branchType:
        final name = raw['branch'];
        if (name is! String || name.trim().isEmpty) return null;
        return NotificationAudience.branch(name.trim());
    }
    return null;
  }

  Map<String, Object> toJson() => {
    'type': type,
    if (type == branchType) 'branch': branch!,
  };

  /// How Studio names this audience.
  String get label => switch (type) {
    allType => 'Everyone',
    testType => 'Staff test devices',
    _ => branch!,
  };

  @override
  bool operator ==(Object other) =>
      other is NotificationAudience &&
      other.type == type &&
      other.branch == branch;

  @override
  int get hashCode => Object.hash(type, branch);
}

/// Where a Studio notification is in its life. Clients write [draft],
/// [scheduled] and [cancelled]; the server writes the rest.
enum StudioNotificationStatus {
  draft('Draft'),
  scheduled('Scheduled'),
  sending('Sending'),
  sent('Sent'),
  failed('Failed'),
  cancelled('Cancelled');

  const StudioNotificationStatus(this.label);

  final String label;

  static StudioNotificationStatus? parse(Object? raw) =>
      values.where((s) => s.name == raw).firstOrNull;

  /// Studio may still cancel it.
  bool get cancellable => this == draft || this == scheduled;
}

/// A stored Studio notification.
@immutable
class StudioNotification {
  const StudioNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.audience,
    required this.status,
    this.link,
    this.sendAt,
    this.sentAt,
    this.createdAt,
    this.createdByName,
    this.error,
  });

  final String id;
  final String title;
  final String body;
  final String? link;
  final NotificationAudience audience;
  final StudioNotificationStatus status;
  final DateTime? sendAt;
  final DateTime? sentAt;
  final DateTime? createdAt;
  final String? createdByName;

  /// `result.error` of a failed send.
  final String? error;

  /// Null for a doc missing its title, body, audience or status: nothing a
  /// member or an admin could act on.
  static StudioNotification? fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    if (data == null) return null;
    final title = data['title'];
    final body = data['body'];
    final audience = NotificationAudience.fromJson(data['audience']);
    final status = StudioNotificationStatus.parse(data['status']);
    if (title is! String || body is! String) return null;
    if (audience == null || status == null) return null;
    DateTime? time(String key) {
      final value = data[key];
      return value is Timestamp ? value.toDate() : null;
    }

    final link = data['link'];
    final result = data['result'];
    final error = result is Map ? result['error'] : null;
    final author = data['createdByName'];
    return StudioNotification(
      id: doc.id,
      title: title,
      body: body,
      link: link is String && link.trim().isNotEmpty ? link.trim() : null,
      audience: audience,
      status: status,
      sendAt: time('sendAt'),
      sentAt: time('sentAt'),
      createdAt: time('createdAt'),
      createdByName: author is String && author.isNotEmpty ? author : null,
      error: error is String ? error : null,
    );
  }
}

/// Why [link] cannot be sent, or null when it is an in-app path (`/m/<id>`,
/// `/giving`, ...) or an https address. Mirrors `isValidLink` in the function.
String? notificationLinkError(String link) {
  if (link.isEmpty) return 'Add a link or choose None';
  if (link.length > kNotificationLinkMax) {
    return 'Keep the link under $kNotificationLinkMax characters';
  }
  if (RegExp(r'\s').hasMatch(link)) return 'Links cannot contain spaces';
  if (link.startsWith('/') && !link.startsWith('//')) return null;
  final uri = Uri.tryParse(link);
  if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
    return 'Use a web address starting with https://';
  }
  return null;
}

/// Reads and writes `notifications`.
class StudioNotificationRepository {
  StudioNotificationRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('notifications');

  /// Queues a notification. [sendAt] null is "Send now": the server stamps
  /// the time and the backend trigger sends it within seconds. A future
  /// [sendAt] is picked up by the 5-minute schedule.
  Future<String> schedule({
    required String title,
    required String body,
    required NotificationAudience audience,
    required String createdBy,
    String? createdByName,
    String? link,
    DateTime? sendAt,
  }) async {
    final ref = _col.doc();
    final trimmedLink = link?.trim();
    final author = createdByName?.trim();
    await ref.set({
      'title': title.trim(),
      'body': body.trim(),
      if (trimmedLink != null && trimmedLink.isNotEmpty) 'link': trimmedLink,
      'audience': audience.toJson(),
      'status': StudioNotificationStatus.scheduled.name,
      'sendAt': sendAt == null
          ? FieldValue.serverTimestamp()
          : Timestamp.fromDate(sendAt),
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': createdBy,
      if (author != null && author.isNotEmpty) 'createdByName': author,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  /// Stops a draft or scheduled notification from going out.
  Future<void> cancel(String id) => _col.doc(id).update({
    'status': StudioNotificationStatus.cancelled.name,
    'updatedAt': FieldValue.serverTimestamp(),
  });

  /// Studio history, newest first. Admins may read every doc.
  Stream<List<StudioNotification>> watchHistory() => _col
      .orderBy('createdAt', descending: true)
      .limit(kNotificationPageSize)
      .snapshots()
      .map(_parse);

  /// Sent notifications for [audience] (everyone, or one branch), newest
  /// first. Constrained on `status` and audience because that is what the
  /// rules let a member read.
  Stream<List<StudioNotification>> watchSent(NotificationAudience audience) {
    var query = _col
        .where('status', isEqualTo: StudioNotificationStatus.sent.name)
        .where('audience.type', isEqualTo: audience.type);
    if (audience.type == NotificationAudience.branchType) {
      query = query.where('audience.branch', isEqualTo: audience.branch);
    }
    return query
        .orderBy('sentAt', descending: true)
        .limit(kNotificationPageSize)
        .snapshots()
        .map(_parse);
  }

  static List<StudioNotification> _parse(
    QuerySnapshot<Map<String, dynamic>> snap,
  ) => [for (final doc in snap.docs) ?StudioNotification.fromDoc(doc)];
}
