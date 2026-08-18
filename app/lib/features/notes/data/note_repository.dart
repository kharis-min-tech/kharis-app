import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

// ── Model ─────────────────────────────────────────────────────────────────────

/// A member's written note.
///
/// A note is either *anchored* — captured while a sermon was playing, so it
/// carries [sermonId] and the [positionMs] it was written at — or general,
/// with both null.
@immutable
class Note {
  const Note({
    required this.id,
    this.sermonId,
    this.sermonTitle,
    this.positionMs,
    required this.body,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String? sermonId;
  final String? sermonTitle;

  /// Playback position, in milliseconds, the note was written at.
  /// Null for general notes and for notes tagged to a sermon that was not
  /// playing at the time.
  final int? positionMs;

  final String body;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// True when this note can seek a sermon back to the moment it was written.
  bool get isAnchored => sermonId != null && positionMs != null;

  Map<String, dynamic> toMap() => {
        'id': id,
        'sermonId': sermonId,
        'sermonTitle': sermonTitle,
        'positionMs': positionMs,
        'body': body,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'updatedAt': updatedAt.millisecondsSinceEpoch,
      };

  /// Reads the local (Hive) representation. Accepts the pre-Firestore `text`
  /// key so notes written by older builds survive the upgrade.
  factory Note.fromMap(Map<String, dynamic> map) => Note(
        id: map['id'] as String,
        sermonId: map['sermonId'] as String?,
        sermonTitle: map['sermonTitle'] as String?,
        positionMs: (map['positionMs'] as num?)?.toInt(),
        body: (map['body'] ?? map['text']) as String,
        createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] as int),
      );

  Note copyWith({
    String? sermonId,
    String? sermonTitle,
    int? positionMs,
    String? body,
    DateTime? updatedAt,
  }) =>
      Note(
        id: id,
        sermonId: sermonId ?? this.sermonId,
        sermonTitle: sermonTitle ?? this.sermonTitle,
        positionMs: positionMs ?? this.positionMs,
        body: body ?? this.body,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  @override
  bool operator ==(Object other) => other is Note && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

// ── Local store ───────────────────────────────────────────────────────────────

/// Hive-backed note storage.
///
/// Two jobs: it holds notes written while signed out (Firestore rules require
/// an owner), and it holds the legacy notes of members who upgrade from the
/// local-only build. Both are drained into Firestore by
/// [NoteRepository] the moment a user is signed in.
class LocalNoteStore {
  LocalNoteStore(this._box);

  final Box<dynamic> _box;

  List<Note> list() {
    final notes = _box.values
        .map((raw) {
          try {
            return Note.fromMap(
              Map<String, dynamic>.from(jsonDecode(raw as String) as Map),
            );
          } catch (_) {
            return null;
          }
        })
        .whereType<Note>()
        .toList();
    notes.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return notes;
  }

  /// Current contents, then a fresh list on every box mutation.
  Stream<List<Note>> watch() async* {
    yield list();
    await for (final _ in _box.watch()) {
      yield list();
    }
  }

  Future<void> upsert(Note note) => _box.put(note.id, jsonEncode(note.toMap()));

  Future<void> delete(String id) => _box.delete(id);

  /// Removes only the notes named — never the whole box, so a note written
  /// while an upload was in flight is not swept away with it.
  Future<void> deleteAll(Iterable<String> ids) => _box.deleteAll(ids);
}

// ── Repository ────────────────────────────────────────────────────────────────

/// Reads and writes member notes.
///
/// Signed in, the store of record is `users/{uid}/notes/{noteId}` — notes
/// survive reinstall and follow the member across devices. The Firestore SDK's
/// own offline cache is the offline path: writes are applied to it at once,
/// queued durably, and replayed when the connection returns.
///
/// Signed out — and while auth is still resolving — notes go to
/// [LocalNoteStore] and are uploaded the moment a [uid] is known, so nothing a
/// member writes is ever dropped.
///
/// [uid] is supplied by the provider layer rather than read from
/// `FirebaseAuth` directly: the repository is rebuilt on sign-in / sign-out,
/// which keeps the streams here dumb and the whole thing testable.
class NoteRepository {
  NoteRepository(
    this._local, {
    required String? uid,
    FirebaseFirestore? firestore,
  })  : _uid = (uid == null || uid.isEmpty) ? null : uid,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final LocalNoteStore _local;
  final String? _uid;
  final FirebaseFirestore _firestore;

  /// Guards against a second upload while an earlier one is still unacked
  /// (offline commits stay pending until the connection returns).
  bool _uploading = false;

  CollectionReference<Map<String, dynamic>> _notesOf(String uid) =>
      _firestore.collection('users').doc(uid).collection('notes');

  /// A collision-free note ID, generated offline by the Firestore SDK (the
  /// path is irrelevant — `doc()` mints a random 20-character ID locally).
  /// Doubles as the document ID, which makes every write idempotent.
  String newId() => _firestore.collection('notes').doc().id;

  // ── Reads ──────────────────────────────────────────────────────────────────

  /// Every note the member owns, newest edit first.
  ///
  /// Merges the cloud collection with anything still held locally (notes
  /// written signed out, or a write the server has not acked yet) so a note
  /// never flickers out of the list. The cloud copy wins on ID collisions.
  ///
  /// Subscribing is also what triggers the one-off upload of local notes.
  Stream<List<Note>> watchNotes() {
    final uid = _uid;
    if (uid == null) return _local.watch();

    unawaited(_uploadLocalNotes(uid));

    final controller = StreamController<List<Note>>();
    var cloud = const <Note>[];
    var local = const <Note>[];
    var hasCloud = false;
    var hasLocal = false;

    void emit() {
      // Wait for one value from each side, so the first frame is not a
      // half-populated list.
      if (controller.isClosed || !hasCloud || !hasLocal) return;
      controller.add(_merge(cloud, local));
    }

    final localSub = _local.watch().listen((notes) {
      local = notes;
      hasLocal = true;
      emit();
    });

    final cloudSub = _notesOf(uid)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .listen(
      (snap) {
        cloud = snap.docs.map(_fromDoc).whereType<Note>().toList();
        hasCloud = true;
        emit();
      },
      onError: (Object error) {
        debugPrint('NoteRepository: notes stream failed — $error');
        cloud = const [];
        hasCloud = true;
        emit();
      },
    );

    controller.onCancel = () async {
      await cloudSub.cancel();
      await localSub.cancel();
    };
    return controller.stream;
  }

  // ── Writes ─────────────────────────────────────────────────────────────────

  /// Creates or replaces [note].
  ///
  /// The note is written to the local store first and only dropped from it
  /// once the server acks, so a crash — or a platform without a durable
  /// offline write queue — cannot lose it. The merged stream dedupes on ID,
  /// so the member never sees two copies in the meantime.
  Future<void> upsert(Note note) async {
    final uid = _uid;
    await _local.upsert(note);
    if (uid == null) return;

    unawaited(
      _notesOf(uid)
          .doc(note.id)
          .set(_toDoc(note), SetOptions(merge: true))
          .then((_) => _local.delete(note.id))
          .catchError((Object error) {
        debugPrint('NoteRepository: note upsert rejected — $error');
      }),
    );
  }

  /// Removes the note from both stores. Deleting a note that is not there is a
  /// no-op, so this is safe to call twice.
  Future<void> delete(String id) async {
    await _local.delete(id);
    final uid = _uid;
    if (uid == null) return;
    unawaited(_notesOf(uid).doc(id).delete().catchError((Object error) {
      debugPrint('NoteRepository: note delete rejected — $error');
    }));
  }

  /// Uploads everything currently in [LocalNoteStore] to [uid]'s collection.
  /// Covers both the upgrade from the local-only build and notes written while
  /// signed out.
  ///
  /// Only the notes that were actually uploaded are removed locally, and only
  /// once the server acks — an interrupted or offline upload leaves them in
  /// place to be retried on the next auth event.
  Future<void> _uploadLocalNotes(String uid) async {
    if (_uploading) return;
    final pending = _local.list();
    if (pending.isEmpty) return;

    _uploading = true;
    try {
      final batch = _firestore.batch();
      for (final note in pending) {
        batch.set(
          _notesOf(uid).doc(note.id),
          _toDoc(note),
          SetOptions(merge: true),
        );
      }
      await batch.commit();
      await _local.deleteAll(pending.map((n) => n.id));
    } catch (error) {
      debugPrint('NoteRepository: local note migration failed — $error');
    } finally {
      _uploading = false;
    }
  }

  // ── Mapping ────────────────────────────────────────────────────────────────

  /// Timestamps are client-side on purpose: a `serverTimestamp()` sentinel
  /// reads back as null until the server acks, and Firestore drops documents
  /// with a null ordering field from an ordered query — an offline note would
  /// vanish from the list until it synced.
  Map<String, Object?> _toDoc(Note note) => {
        'sermonId': note.sermonId,
        'sermonTitle': note.sermonTitle,
        'positionMs': note.positionMs,
        'body': note.body,
        'createdAt': Timestamp.fromDate(note.createdAt),
        'updatedAt': Timestamp.fromDate(note.updatedAt),
      };

  Note? _fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final body = data['body'];
    final updatedAt = data['updatedAt'];
    if (body is! String || updatedAt is! Timestamp) return null;
    final createdAt = data['createdAt'];
    return Note(
      id: doc.id,
      sermonId: data['sermonId'] as String?,
      sermonTitle: data['sermonTitle'] as String?,
      positionMs: (data['positionMs'] as num?)?.toInt(),
      body: body,
      createdAt: createdAt is Timestamp
          ? createdAt.toDate()
          : updatedAt.toDate(),
      updatedAt: updatedAt.toDate(),
    );
  }

  static List<Note> _merge(List<Note> cloud, List<Note> local) {
    if (local.isEmpty) return cloud;
    final byId = {for (final note in local) note.id: note};
    for (final note in cloud) {
      byId[note.id] = note;
    }
    final merged = byId.values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return merged;
  }
}
