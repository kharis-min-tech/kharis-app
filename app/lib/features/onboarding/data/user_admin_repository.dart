import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:kharis_app/shared/models/user.dart';

/// Admin-only access to the `users` collection: list every profile and change
/// roles. Firestore rules enforce that only admins may read all users or
/// mutate the `role` field.
class UserAdminRepository {
  UserAdminRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Stream<List<User>> watchUsers() {
    return _firestore.collection('users').snapshots().map((snap) {
      final users = snap.docs.map((d) => _map(d.id, d.data())).toList();
      users.sort((a, b) =>
          a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));
      return users;
    });
  }

  Future<void> setRole(String uid, String role) =>
      _firestore.collection('users').doc(uid).update({'role': role});

  User _map(String id, Map<String, dynamic> data) => User(
        id: id,
        email: data['email'] as String? ?? '',
        displayName: data['displayName'] as String? ?? 'Member',
        role: data['role'] as String? ?? 'member',
        branch: data['branch'] as String?,
        photoUrl: data['photoUrl'] as String?,
        createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      );
}
