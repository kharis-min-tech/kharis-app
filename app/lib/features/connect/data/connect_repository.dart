import 'package:cloud_firestore/cloud_firestore.dart';

/// Writes visitor and testimony records to Firestore.
class ConnectRepository {
  ConnectRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  /// Adds a new visitor card to the [visitors] collection.
  ///
  /// Throws if Firestore is unavailable or the write fails.
  Future<void> submitVisitor({
    required String name,
    required String phone,
    required String email,
    required String branch,
    required DateTime firstVisitDate,
  }) async {
    await _firestore.collection('visitors').add({
      'name': name,
      'phone': phone,
      'email': email,
      'branch': branch,
      'firstVisitDate': Timestamp.fromDate(firstVisitDate),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Adds a new testimony to the [testimonies] collection with status 'pending'.
  ///
  /// Throws if Firestore is unavailable or the write fails.
  Future<void> submitTestimony({
    required String name,
    required String email,
    required String branch,
    required String text,
  }) async {
    await _firestore.collection('testimonies').add({
      'name': name,
      'email': email,
      'branch': branch,
      'text': text,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
