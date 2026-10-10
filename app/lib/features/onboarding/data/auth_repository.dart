import 'package:kharis_app/shared/models/user.dart';

// ── Exceptions ──────────────────────────────────────────────────────────────

class InvalidCredentialsException implements Exception {
  const InvalidCredentialsException([
    this.message = 'Invalid email or password',
  ]);
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

/// The auth backend refused a sensitive operation (account deletion) because
/// the sign-in is too old. Re-authenticate with [AuthRepository.reauthenticate]
/// and retry.
class RecentLoginRequiredException implements Exception {
  const RecentLoginRequiredException([
    this.message = 'Please confirm your password to continue',
  ]);
  final String message;
  @override
  String toString() => message;
}

// ── Abstract interface ────────────────────────────────────────────────────────

/// The app's auth contract. `FirebaseAuthRepository` is the implementation;
/// tests substitute fakes without touching callers.
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

  /// Emails a password-reset link to [email].
  ///
  /// Throws [InvalidCredentialsException] with a readable message when the
  /// address is malformed. An unknown address completes normally so the
  /// screen cannot be used to probe which emails have accounts.
  Future<void> sendPasswordResetEmail(String email);

  /// Whether the signed-in account signs in with email + password, so
  /// [reauthenticate] can confirm it before a sensitive operation.
  bool get usesPasswordSignIn;

  /// Confirms the signed-in member's identity with [password].
  ///
  /// Throws [InvalidCredentialsException] when the password is wrong.
  Future<void> reauthenticate(String password);

  /// Permanently deletes the signed-in auth account, which also signs out.
  ///
  /// Delete the member's stored data first: once the account is gone the
  /// security rules no longer let this device touch it. Throws
  /// [RecentLoginRequiredException] when the sign-in is too old — call
  /// [reauthenticate] and retry.
  Future<void> deleteAccount();

  User? get currentUser;
  bool get isAuthenticated;
  Stream<User?> get authStateChanges;
}
