import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'package:kharis_app/shared/models/campus_config.dart';
import 'package:kharis_app/shared/models/user.dart';

/// A `users/{uid}` profile as the Studio users screen shows it: the member
/// plus the campuses a campus admin manages.
@immutable
class AdminUser {
  const AdminUser({
    required this.user,
    this.adminBranchIds = const [],
    this.adminBranchNames = const [],
  });

  final User user;

  /// `adminBranchIds` (branch doc ids); empty unless a campus admin.
  final List<String> adminBranchIds;

  /// `adminBranchNames`, the names matching [adminBranchIds].
  final List<String> adminBranchNames;
}

/// Admin-only access to the `users` collection: list every profile and change
/// roles. Firestore rules enforce that only super admins may read all users
/// or mutate `role`, `adminBranchIds` and `adminBranchNames`.
class UserAdminRepository {
  UserAdminRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Stream<List<AdminUser>> watchUsers() {
    return _firestore.collection('users').snapshots().map((snap) {
      final users = snap.docs.map((d) => _map(d.id, d.data())).toList();
      users.sort(
        (a, b) => a.user.displayName.toLowerCase().compareTo(
          b.user.displayName.toLowerCase(),
        ),
      );
      return users;
    });
  }

  /// Sets [role] in one update. A campus admin ([AdminScope.campusAdminRole])
  /// gets [branchIds] and the matching [branchNames] (1+ campuses); any other
  /// role clears both lists.
  Future<void> setRole(
    String uid,
    String role, {
    List<String> branchIds = const [],
    List<String> branchNames = const [],
  }) {
    final campusAdmin = role == AdminScope.campusAdminRole;
    if (campusAdmin &&
        (branchIds.isEmpty || branchIds.length != branchNames.length)) {
      throw ArgumentError('A campus admin needs 1+ campuses (ids and names).');
    }
    return _firestore.collection('users').doc(uid).update({
      'role': role,
      'adminBranchIds': campusAdmin ? branchIds : FieldValue.delete(),
      'adminBranchNames': campusAdmin ? branchNames : FieldValue.delete(),
    });
  }

  static List<String> _strings(Object? raw) =>
      raw is List ? raw.whereType<String>().toList() : const [];

  AdminUser _map(String id, Map<String, dynamic> data) => AdminUser(
    user: User(
      id: id,
      email: data['email'] as String? ?? '',
      displayName: data['displayName'] as String? ?? 'Member',
      role: data['role'] as String? ?? 'member',
      branch: data['branch'] as String?,
      photoUrl: data['photoUrl'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    ),
    adminBranchIds: _strings(data['adminBranchIds']),
    adminBranchNames: _strings(data['adminBranchNames']),
  );
}
