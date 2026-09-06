import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';

import 'package:kharis_app/shared/models/user.dart';
import 'auth_repository.dart';

/// Real authentication backed by Firebase Auth + a Firestore `users/{uid}`
/// profile document.
///
/// The profile doc is the single source of truth for display name, branch,
/// avatar and role. Admin status is the `admin` custom claim OR a profile
/// `role == 'admin'`, evaluated by the Firestore rules and [authStateChanges].
class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository({fb.FirebaseAuth? auth, FirebaseFirestore? firestore})
      : _auth = auth ?? fb.FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final fb.FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  User? _cached;

  @override
  User? get currentUser => _cached;

  @override
  bool get isAuthenticated => _auth.currentUser != null;

  @override
  Stream<User?> get authStateChanges async* {
    await for (final fbUser in _auth.authStateChanges()) {
      if (fbUser == null) {
        _cached = null;
        yield null;
      } else {
        final user = await _hydrate(fbUser);
        _cached = user;
        yield user;
      }
    }
  }

  @override
  Future<User> login(String email, String password) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = await _hydrate(cred.user!);
      _cached = user;
      return user;
    } on fb.FirebaseAuthException catch (e) {
      throw _mapError(e);
    }
  }

  @override
  Future<User> register({
    required String email,
    required String password,
    required String displayName,
    required String role,
  }) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final fbUser = cred.user!;
      await fbUser.updateDisplayName(displayName);
      // New accounts never self-assign admin; that is an admin-only action.
      final safeRole = role == 'admin' ? 'member' : role;
      final user = User(
        id: fbUser.uid,
        email: email.trim(),
        displayName: displayName,
        role: safeRole,
        createdAt: DateTime.now(),
      );
      // The Auth account already exists at this point, so a failed profile
      // write must not fail the whole signup — that surfaces as a raw
      // "database" error on an account the member can actually sign into, and
      // retrying just hits email-already-in-use. [_hydrate] recreates the
      // profile on the next auth emission, so log and continue.
      try {
        await _firestore.collection('users').doc(fbUser.uid).set({
          'email': user.email,
          'displayName': user.displayName,
          'role': user.role,
          'branch': user.branch,
          'photoUrl': user.photoUrl,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        debugPrint(
          '[auth] profile write failed for ${fbUser.uid}: $e — '
          '_hydrate will backfill it on the next auth emission.',
        );
      }
      _cached = user;
      return user;
    } on fb.FirebaseAuthException catch (e) {
      throw _mapError(e);
    }
  }

  @override
  Future<User> loginAsGuest() async {
    final cred = await _auth.signInAnonymously();
    final user = User(
      id: cred.user!.uid,
      email: '',
      displayName: 'Guest',
      role: 'guest',
      createdAt: DateTime.now(),
    );
    _cached = user;
    return user;
  }

  @override
  Future<void> logout() => _auth.signOut();

  /// Updates the signed-in user's editable profile fields and refreshes cache.
  Future<User> updateProfile({
    String? displayName,
    String? branch,
    String? photoUrl,
    String? phone,
    DateTime? dob,
  }) async {
    final fbUser = _auth.currentUser;
    if (fbUser == null) {
      throw const InvalidCredentialsException('Not signed in');
    }
    final updates = <String, Object?>{
      'displayName': ?displayName,
      'branch': ?branch,
      'photoUrl': ?photoUrl,
      'phone': ?phone,
      if (dob != null) 'dob': dob.toIso8601String().substring(0, 10),
    };
    if (updates.isNotEmpty) {
      await _upsertProfile(fbUser, updates);
    }
    if (displayName != null) await fbUser.updateDisplayName(displayName);
    final user = await _hydrate(fbUser);
    _cached = user;
    return user;
  }

  /// Persists notification preference toggles to the user's Firestore doc.
  Future<void> updateNotificationPrefs(Map<String, bool> prefs) async {
    final fbUser = _auth.currentUser;
    if (fbUser == null) return;
    await _upsertProfile(fbUser, {'notificationPrefs': prefs});
  }

  /// Merges [updates] into the caller's `users/{uid}` doc, creating the full
  /// profile first when the doc is missing.
  ///
  /// Accounts created while the app pointed at the dead Firebase project have
  /// no profile doc, and a bare merge-set on a missing doc is a rules-level
  /// CREATE — which the rules reject because it carries no `role`. So:
  /// existing doc → plain merge that never sends `role` (rules pin it to its
  /// current value); missing doc → the same profile shape and safe role that
  /// [register] writes, with [updates] layered on top.
  Future<void> _upsertProfile(
    fb.User fbUser,
    Map<String, Object?> updates,
  ) async {
    final ref = _firestore.collection('users').doc(fbUser.uid);
    final exists = (await ref.get()).exists;
    if (exists) {
      await ref.set(updates, SetOptions(merge: true));
      return;
    }
    await ref.set({
      'email': fbUser.email ?? '',
      'displayName':
          fbUser.displayName ?? (fbUser.isAnonymous ? 'Guest' : 'Member'),
      'role': fbUser.isAnonymous ? 'guest' : 'member',
      'branch': null,
      'photoUrl': fbUser.photoURL,
      'createdAt': FieldValue.serverTimestamp(),
      ...updates,
    }, SetOptions(merge: true));
  }

  /// True when the current user is an admin (custom claim or profile role).
  Future<bool> isCurrentUserAdmin() async {
    final fbUser = _auth.currentUser;
    if (fbUser == null) return false;
    if (_cached?.role == 'admin') return true;
    try {
      final token = await fbUser.getIdTokenResult(true);
      if (token.claims?['admin'] == true) return true;
    } catch (_) {}
    return false;
  }

  /// Accepts the 'yyyy-MM-dd' strings we write plus any legacy Timestamp.
  static DateTime? _parseDob(Object? raw) {
    if (raw is Timestamp) return raw.toDate();
    if (raw is String && raw.isNotEmpty) return DateTime.tryParse(raw);
    return null;
  }

  /// Reads (or lazily creates) the Firestore profile doc for [fbUser].
  Future<User> _hydrate(fb.User fbUser) async {
    final ref = _firestore.collection('users').doc(fbUser.uid);
    try {
      final snap = await ref.get();
      if (snap.exists) {
        final data = snap.data()!;
        return User(
          id: fbUser.uid,
          email: (data['email'] as String?) ?? fbUser.email ?? '',
          displayName: (data['displayName'] as String?) ??
              fbUser.displayName ??
              'Member',
          role: (data['role'] as String?) ?? 'member',
          branch: data['branch'] as String?,
          photoUrl: (data['photoUrl'] as String?) ?? fbUser.photoURL,
          phone: data['phone'] as String?,
          dob: _parseDob(data['dob']),
          createdAt:
              (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        );
      }
    } catch (_) {
      // Fall through to a minimal profile from the auth record.
    }
    final user = User(
      id: fbUser.uid,
      email: fbUser.email ?? '',
      displayName:
          fbUser.displayName ?? (fbUser.isAnonymous ? 'Guest' : 'Member'),
      role: fbUser.isAnonymous ? 'guest' : 'member',
      photoUrl: fbUser.photoURL,
      createdAt: DateTime.now(),
    );
    try {
      await ref.set({
        'email': user.email,
        'displayName': user.displayName,
        'role': user.role,
        'branch': user.branch,
        'photoUrl': user.photoUrl,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
    return user;
  }

  Object _mapError(fb.FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return const EmailAlreadyInUseException();
      case 'wrong-password':
      case 'user-not-found':
      case 'invalid-credential':
        return const InvalidCredentialsException();
      case 'weak-password':
        return const InvalidCredentialsException(
            'Password must be at least 6 characters');
      case 'invalid-email':
        return const InvalidCredentialsException('That email looks invalid');
      default:
        return InvalidCredentialsException(e.message ?? 'Authentication failed');
    }
  }
}
