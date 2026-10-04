/// Immutable user model used throughout the Kharis app.
///
/// [role] is one of: 'member' | 'guest' | 'new_here'
class User {
  const User({
    required this.id,
    required this.email,
    required this.displayName,
    required this.role,
    this.branch,
    this.photoUrl,
    this.phone,
    this.dob,
    required this.createdAt,
  });

  final String id;
  final String email;
  final String displayName;
  final String role;
  final String? branch;
  final String? photoUrl;

  /// Optional contact number, collected post-signup via Edit Profile.
  final String? phone;

  /// Optional date of birth; drives birthday greetings.
  final DateTime? dob;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'displayName': displayName,
        'role': role,
        'branch': branch,
        'photoUrl': photoUrl,
        'phone': phone,
        'dob': dob?.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
      };

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'] as String,
        email: json['email'] as String,
        displayName: json['displayName'] as String,
        role: json['role'] as String,
        branch: json['branch'] as String?,
        photoUrl: json['photoUrl'] as String?,
        phone: json['phone'] as String?,
        dob: json['dob'] == null
            ? null
            : DateTime.parse(json['dob'] as String),
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  User copyWith({
    String? id,
    String? email,
    String? displayName,
    String? role,
    String? branch,
    String? photoUrl,
    String? phone,
    DateTime? dob,
    DateTime? createdAt,
  }) =>
      User(
        id: id ?? this.id,
        email: email ?? this.email,
        displayName: displayName ?? this.displayName,
        role: role ?? this.role,
        branch: branch ?? this.branch,
        photoUrl: photoUrl ?? this.photoUrl,
        phone: phone ?? this.phone,
        dob: dob ?? this.dob,
        createdAt: createdAt ?? this.createdAt,
      );

  @override
  String toString() => 'User(id: $id, email: $email, role: $role)';
}
