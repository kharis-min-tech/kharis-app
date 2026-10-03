import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Longest playlist name accepted — mirrored by the Firestore rules, so a
/// name the client accepts is never rejected at write time.
const int kPlaylistNameMaxLength = 80;

// ── Model ─────────────────────────────────────────────────────────────────────

/// A member-created playlist: a named, ordered list of sermon ids.
///
/// The ids reference the sermon catalogue ([sermonIds] entries may dangle when
/// a message leaves the library — resolution tolerates that rather than
/// breaking the playlist).
@immutable
class Playlist {
  const Playlist({
    required this.id,
    required this.name,
    required this.sermonIds,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final List<String> sermonIds;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool contains(String sermonId) => sermonIds.contains(sermonId);

  /// Value equality, not identity-by-id: Riverpod's default
  /// `updateShouldNotify` is `previous != next`, so an id-only `==` would
  /// swallow add/remove/rename updates inside derived providers
  /// (`playlistByIdProvider` would recompute an "equal" playlist and never
  /// notify `playlistSermonsProvider`, leaving the detail screen stale).
  @override
  bool operator ==(Object other) =>
      other is Playlist &&
      other.id == id &&
      other.name == name &&
      listEquals(other.sermonIds, sermonIds) &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt;

  @override
  int get hashCode =>
      Object.hash(id, name, Object.hashAll(sermonIds), createdAt, updatedAt);
}

// ── Repository ────────────────────────────────────────────────────────────────

/// Reads and writes the member's playlists at `users/{uid}/playlists`.
///
/// Every account has a uid — signed-in members and anonymous guests alike —
/// so playlists persist and follow the member across relaunches for both.
/// Writes are fire-and-forget on top of the Firestore SDK's offline queue:
/// the local snapshot updates immediately (optimistic UI) and the commit is
/// replayed when the connection returns. Timestamps are client-side for the
/// same reason as [NoteRepository]: a `serverTimestamp()` sentinel reads back
/// null until acked and would drop the doc out of the ordered query offline.
///
/// [uid] is supplied by the provider layer rather than read from
/// `FirebaseAuth` directly: the repository is rebuilt on sign-in / sign-out,
/// which keeps the streams here dumb and the whole thing testable.
class PlaylistRepository {
  PlaylistRepository(this._firestore, {required String? uid})
    : _uid = (uid == null || uid.isEmpty) ? null : uid;

  final String? _uid;
  final FirebaseFirestore _firestore;

  /// False while auth is still resolving (or genuinely signed out) — the UI
  /// asks the member to retry in a moment instead of writing nowhere.
  bool get hasUser => _uid != null;

  CollectionReference<Map<String, dynamic>> _playlistsOf(String uid) =>
      _firestore.collection('users').doc(uid).collection('playlists');

  String _requireUid() {
    final uid = _uid;
    if (uid == null) {
      throw StateError('PlaylistRepository: no signed-in user');
    }
    return uid;
  }

  /// Trims [raw] and rejects names the Firestore rules would reject
  /// (empty, or longer than [kPlaylistNameMaxLength]).
  static String normalizeName(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(raw, 'name', 'Playlist name is required');
    }
    if (trimmed.length > kPlaylistNameMaxLength) {
      throw ArgumentError.value(raw, 'name', 'Playlist name is too long');
    }
    return trimmed;
  }

  // ── Reads ──────────────────────────────────────────────────────────────────

  /// The member's own playlists (their categorisations), most recently
  /// touched first. The Favorites doc shares the collection but is never one
  /// of them, so it is left out here; see [watchFavorites].
  /// Empty while signed out / auth resolving.
  Stream<List<Playlist>> watchPlaylists() {
    final uid = _uid;
    if (uid == null) return Stream.value(const <Playlist>[]);
    return _playlistsOf(uid)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map(
          (snap) => [
            for (final doc in snap.docs)
              if (doc.id != favoritesId) ?_fromDoc(doc),
          ],
        );
  }

  /// The member's Favorites (the player's heart), or null until the first
  /// heart creates the doc. Null while signed out / auth resolving.
  Stream<Playlist?> watchFavorites() {
    final uid = _uid;
    if (uid == null) return Stream.value(null);
    return _playlistsOf(
      uid,
    ).doc(favoritesId).snapshots().map((snap) => _fromDoc(snap));
  }

  // ── Writes ─────────────────────────────────────────────────────────────────

  /// Creates an empty playlist named [name] and returns its id immediately —
  /// the id is minted locally, so the caller can navigate or add sermons
  /// while the commit is still in flight.
  String create(String name) {
    final uid = _requireUid();
    final trimmed = normalizeName(name);
    final now = Timestamp.now();
    final doc = _playlistsOf(uid).doc();
    _commit(
      doc.set({
        'name': trimmed,
        'sermonIds': const <String>[],
        'createdAt': now,
        'updatedAt': now,
      }),
      'create',
    );
    return doc.id;
  }

  void rename(String playlistId, String name) {
    final uid = _requireUid();
    final trimmed = normalizeName(name);
    _commit(
      _playlistsOf(
        uid,
      ).doc(playlistId).update({'name': trimmed, 'updatedAt': Timestamp.now()}),
      'rename',
    );
  }

  void deletePlaylist(String playlistId) {
    final uid = _requireUid();
    _commit(_playlistsOf(uid).doc(playlistId).delete(), 'delete');
  }

  /// Appends [sermonId] to the playlist. `arrayUnion` makes this idempotent:
  /// adding a message that is already there is a no-op, never a duplicate.
  void addSermon(String playlistId, String sermonId) {
    final uid = _requireUid();
    _commit(
      _playlistsOf(uid).doc(playlistId).update({
        'sermonIds': FieldValue.arrayUnion([sermonId]),
        'updatedAt': Timestamp.now(),
      }),
      'addSermon',
    );
  }

  void removeSermon(String playlistId, String sermonId) {
    final uid = _requireUid();
    _commit(
      _playlistsOf(uid).doc(playlistId).update({
        'sermonIds': FieldValue.arrayRemove([sermonId]),
        'updatedAt': Timestamp.now(),
      }),
      'removeSermon',
    );
  }

  /// Doc id of the member's Favorites, which the player's heart fills. It
  /// lives beside the playlists (`users/{uid}/playlists/liked`, so the
  /// existing rules cover it) but is not one of them: a fixed id keeps it a
  /// single list however often the heart is tapped, and every playlist
  /// surface leaves it out. [FieldValue.arrayUnion] appends, so its
  /// `sermonIds` are in the order they were favorited, oldest first.
  static const String favoritesId = 'liked';
  static const String favoritesName = 'Favorites';

  /// Favorites or unfavorites [sermonId]. [favoritesExist] says whether the
  /// Favorites doc already exists: the first heart creates it, later ones
  /// update it in place. Unfavoriting also removes [aliases] (other ids the
  /// same message was favorited under).
  ///
  /// The create path merges rather than replaces: if the doc does exist
  /// after all (a snapshot that had not caught up, another device), the
  /// favorite is added to it instead of overwriting every earlier one.
  void setLiked(
    String sermonId, {
    required bool liked,
    required bool favoritesExist,
    Iterable<String> aliases = const [],
  }) {
    final uid = _requireUid();
    final doc = _playlistsOf(uid).doc(favoritesId);
    final now = Timestamp.now();
    if (!favoritesExist) {
      if (!liked) return;
      _commit(
        doc.set({
          'name': favoritesName,
          'sermonIds': FieldValue.arrayUnion([sermonId]),
          'createdAt': now,
          'updatedAt': now,
        }, SetOptions(merge: true)),
        'like',
      );
      return;
    }
    _commit(
      doc.update({
        'sermonIds': liked
            ? FieldValue.arrayUnion([sermonId])
            : FieldValue.arrayRemove([sermonId, ...aliases]),
        'updatedAt': now,
      }),
      liked ? 'like' : 'unlike',
    );
  }

  /// Fire-and-forget commit: the optimistic snapshot has already updated the
  /// UI, and the SDK's offline queue owns delivery. A rejection (rules, doc
  /// deleted on another device) is logged, not surfaced mid-scroll.
  void _commit(Future<void> write, String op) {
    unawaited(
      write.catchError((Object error) {
        debugPrint('PlaylistRepository: $op rejected — $error');
      }),
    );
  }

  // ── Mapping ────────────────────────────────────────────────────────────────

  Playlist? _fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) return null;
    final name = data['name'];
    final updatedAt = data['updatedAt'];
    if (name is! String || updatedAt is! Timestamp) return null;
    final createdAt = data['createdAt'];
    final rawIds = data['sermonIds'];
    return Playlist(
      id: doc.id,
      name: name,
      sermonIds: rawIds is List
          ? rawIds.whereType<String>().toList()
          : const [],
      createdAt: createdAt is Timestamp
          ? createdAt.toDate()
          : updatedAt.toDate(),
      updatedAt: updatedAt.toDate(),
    );
  }
}
