import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../shared/models/user.dart';

// ── Exceptions ──────────────────────────────────────────────────────────────

class InvalidCredentialsException implements Exception {
  const InvalidCredentialsException(
      [this.message = 'Invalid email or password']);
  final String message;
  @override
  String toString() => message;
}

class EmailAlreadyInUseException implements Exception {
  const EmailAlreadyInUseException([this.message = 'Email already in use']);
  final String message;
  @override
  String toString() => message;
}

// ── Abstract interface ────────────────────────────────────────────────────────

/// Swap [TestAuthRepository] for a real implementation without touching callers.
abstract class AuthRepository {
  Future<User> login(String email, String password);

  Future<User> register({
    required String email,
    required String password,
    required String displayName,
    required String role,
  });

  /// Creates a transient guest session — no credentials required.
  Future<User> loginAsGuest();

  Future<void> logout();

  User? get currentUser;
  bool get isAuthenticated;
  Stream<User?> get authStateChanges;
}

// ── Test implementation ───────────────────────────────────────────────────────

/// Local mock auth backed by [SharedPreferences].
///
/// Hardcoded test accounts:
///   • david@kharis.org / test1234  → member, London branch
///   • guest@kharis.org / guest     → guest
///
/// Any other email triggers register, creating a local account.
class TestAuthRepository implements AuthRepository {
  static const _authUserKey = 'auth_user';
  static const _localUsersKey = 'auth_local_users';

  static const _hardcoded = <Map<String, String?>>[
    {
      'id': '1',
      'email': 'david@kharis.org',
      'password': 'test1234',
      'displayName': 'David',
      'role': 'member',
      'branch': 'London',
    },
    {
      'id': '2',
      'email': 'guest@kharis.org',
      'password': 'guest',
      'displayName': 'Guest',
      'role': 'guest',
      'branch': null,
    },
  ];

  final SharedPreferences _prefs;
  final _authController = StreamController<User?>.broadcast();
  User? _currentUser;

  TestAuthRepository(this._prefs) {
    _currentUser = _readCurrentUser();
    // Emit initial auth state after a microtask so subscribers are ready.
    Future.microtask(() => _authController.add(_currentUser));
  }

  // ── Internals ──────────────────────────────────────────────────────────────

  User? _readCurrentUser() {
    final raw = _prefs.getString(_authUserKey);
    if (raw == null) return null;
    try {
      return User.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> _persist(User? user) async {
    if (user == null) {
      await _prefs.remove(_authUserKey);
    } else {
      await _prefs.setString(_authUserKey, jsonEncode(user.toJson()));
    }
    _currentUser = user;
    _authController.add(user);
  }

  Map<String, Map<String, dynamic>> _readLocalUsers() {
    final raw = _prefs.getString(_localUsersKey);
    if (raw == null) return {};
    return (jsonDecode(raw) as Map<String, dynamic>)
        .map((k, v) => MapEntry(k, v as Map<String, dynamic>));
  }

  Future<void> _writeLocalUsers(
      Map<String, Map<String, dynamic>> users) async {
    await _prefs.setString(_localUsersKey, jsonEncode(users));
  }

  // ── Public API ─────────────────────────────────────────────────────────────

  @override
  User? get currentUser => _currentUser;

  @override
  bool get isAuthenticated => _currentUser != null;

  @override
  Stream<User?> get authStateChanges => _authController.stream;

  @override
  Future<User> login(String email, String password) async {
    // Simulate network latency.
    await Future.delayed(const Duration(milliseconds: 800));

    // Check hardcoded accounts.
    for (final u in _hardcoded) {
      if (u['email'] == email && u['password'] == password) {
        final user = User(
          id: u['id']!,
          email: u['email']!,
          displayName: u['displayName']!,
          role: u['role']!,
          branch: u['branch'],
          createdAt: DateTime(2024),
        );
        await _persist(user);
        return user;
      }
    }

    // Check locally registered accounts.
    final local = _readLocalUsers();
    final stored = local[email];
    if (stored != null && stored['password'] == password) {
      final user = User.fromJson(stored);
      await _persist(user);
      return user;
    }

    throw const InvalidCredentialsException();
  }

  @override
  Future<User> register({
    required String email,
    required String password,
    required String displayName,
    required String role,
  }) async {
    await Future.delayed(const Duration(milliseconds: 800));

    if (_hardcoded.any((u) => u['email'] == email)) {
      throw const EmailAlreadyInUseException();
    }

    final local = _readLocalUsers();
    if (local.containsKey(email)) throw const EmailAlreadyInUseException();

    final id = 'local_${DateTime.now().millisecondsSinceEpoch}';
    final user = User(
      id: id,
      email: email,
      displayName: displayName,
      role: role,
      createdAt: DateTime.now(),
    );

    local[email] = {...user.toJson(), 'password': password};
    await _writeLocalUsers(local);
    await _persist(user);
    return user;
  }

  @override
  Future<User> loginAsGuest() async {
    final user = User(
      id: 'guest_${DateTime.now().millisecondsSinceEpoch}',
      email: '',
      displayName: 'Guest',
      role: 'guest',
      createdAt: DateTime.now(),
    );
    await _persist(user);
    return user;
  }

  @override
  Future<void> logout() async {
    await _persist(null);
  }

  void dispose() {
    _authController.close();
  }
}
