import 'package:cloud_firestore/cloud_firestore.dart';

/// Watches the `config/messageOfTheDay` Firestore document written by the
/// web Content Studio: `{ sermonId, setAt }`.
class MotdRepository {
  MotdRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  /// Emits the featured sermon's document id, or null when no Message of the
  /// Day is set. Missing doc, blank field, or any error map to null so the
  /// Messages tab simply omits the card.
  Stream<String?> watchSermonId() async* {
    try {
      yield* _firestore
          .collection('config')
          .doc('messageOfTheDay')
          .snapshots()
          .map((doc) {
        if (!doc.exists || doc.data() == null) return null;
        final id = (doc.data()!['sermonId'] as String?)?.trim();
        return (id == null || id.isEmpty) ? null : id;
      });
    } catch (_) {
      yield null;
    }
  }
}
