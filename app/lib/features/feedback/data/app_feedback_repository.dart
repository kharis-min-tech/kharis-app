import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Where a piece of feedback was written.
enum FeedbackSource { prompt, settings }

/// Writes member feedback to the `app_feedback` collection (create-only,
/// admin-read; see backend/firestore.rules).
class AppFeedbackRepository {
  AppFeedbackRepository(this._firestore, {required String? uid})
    : _uid = (uid == null || uid.isEmpty) ? null : uid;

  final FirebaseFirestore _firestore;
  final String? _uid;

  static const maxCommentLength = 2000;

  /// How long to wait for the server before trusting the offline queue.
  static const _ackTimeout = Duration(seconds: 6);

  bool get hasUser => _uid != null;

  /// Saves one rating (1 to 5) with an optional comment.
  ///
  /// Throws [StateError] when there is no signed-in (or anonymous) user yet,
  /// and rethrows a rejected write so the sheet can say so. A write that is
  /// merely slow (offline) is already queued locally by Firestore and syncs
  /// later, so a timeout counts as sent.
  Future<void> submit({
    required int rating,
    required String comment,
    required FeedbackSource source,
  }) async {
    final uid = _uid;
    if (uid == null) throw StateError('No user to attribute feedback to');
    if (rating < 1 || rating > 5) {
      throw ArgumentError.value(rating, 'rating', 'must be 1 to 5');
    }
    final trimmed = comment.trim();
    final body = trimmed.length > maxCommentLength
        ? trimmed.substring(0, maxCommentLength)
        : trimmed;

    final write = _firestore.collection('app_feedback').doc().set({
      'uid': uid,
      'rating': rating,
      'comment': body,
      'source': source.name,
      'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await write.timeout(_ackTimeout, onTimeout: () {});
  }
}
