import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

@immutable
class LiveStatus {
  const LiveStatus({
    required this.isLive,
    this.videoId,
    this.title,
  });

  final bool isLive;
  final String? videoId;
  final String? title;

  static const notLive = LiveStatus(isLive: false);
}

/// Watches the `config/live` Firestore document for realtime live-stream state.
class LiveRepository {
  LiveRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  /// Emits [LiveStatus] updates from `config/live`.
  /// Missing doc or fields map to [LiveStatus.notLive].
  /// Any error swallowed to a single non-live emission.
  Stream<LiveStatus> watchLiveStatus() async* {
    try {
      yield* _firestore
          .collection('config')
          .doc('live')
          .snapshots()
          .map((doc) {
        if (!doc.exists || doc.data() == null) return LiveStatus.notLive;
        final data = doc.data()!;
        final isLive = data['isLive'] as bool? ?? false;
        if (!isLive) return LiveStatus.notLive;
        return LiveStatus(
          isLive: true,
          videoId: data['videoId'] as String?,
          title: data['title'] as String?,
        );
      });
    } catch (_) {
      yield LiveStatus.notLive;
    }
  }
}
