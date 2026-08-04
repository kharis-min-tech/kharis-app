import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';

import 'event_repository.dart';

/// A single member's RSVP to a single event.
///
/// Stored in the `rsvps` collection under the deterministic document ID
/// `{userId}_{eventId}`, which makes an RSVP idempotent (tapping twice cannot
/// create duplicates) and lets the Firestore rules bind ownership to the
/// document ID rather than only to the payload.
@immutable
class Rsvp {
  const Rsvp({
    required this.id,
    required this.userId,
    required this.eventId,
    required this.eventStartTime,
    this.branch,
    this.createdAt,
  });

  final String id;
  final String userId;
  final String eventId;

  /// Denormalised copy of the event's start time so "My RSVPs" can be split
  /// into upcoming and past without reading every event document.
  final DateTime eventStartTime;

  final String? branch;
  final DateTime? createdAt;

  @override
  bool operator ==(Object other) => other is Rsvp && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Rsvp(user: $userId, event: $eventId)';
}

/// RSVP'd events split by the same cutoff the Events tabs use, so an event
/// whose date has passed is never presented as upcoming.
///
/// Grouping happens once, at the provider, because both the split and the
/// per-group ordering are product rules rather than layout concerns.
@immutable
class RsvpEvents {
  const RsvpEvents({required this.upcoming, required this.past});

  static const RsvpEvents empty = RsvpEvents(upcoming: [], past: []);

  /// Not yet finished, soonest first.
  final List<Event> upcoming;

  /// Finished, most recent first.
  final List<Event> past;

  bool get isEmpty => upcoming.isEmpty && past.isEmpty;

  /// Splits [events] on [Event.isPastAt] and orders each group.
  factory RsvpEvents.split(List<Event> events, DateTime now) {
    final upcoming = <Event>[];
    final past = <Event>[];
    for (final e in events) {
      (e.isPastAt(now) ? past : upcoming).add(e);
    }
    upcoming.sort((a, b) => a.startTime.compareTo(b.startTime));
    past.sort((a, b) => b.startTime.compareTo(a.startTime));
    return RsvpEvents(upcoming: upcoming, past: past);
  }
}

/// Thrown when an RSVP action is attempted without a signed-in user.
///
/// Callers must gate on auth and prompt sign-in; this exists so a missing
/// session can never be swallowed into a silent no-op.
class RsvpAuthRequiredException implements Exception {
  const RsvpAuthRequiredException();

  @override
  String toString() => 'Sign in to RSVP to events.';
}

/// Persists event RSVPs in the Firestore `rsvps` collection.
class RsvpRepository {
  RsvpRepository({fb.FirebaseAuth? auth, FirebaseFirestore? firestore})
      : _auth = auth ?? fb.FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final fb.FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  static const String _collection = 'rsvps';

  CollectionReference<Map<String, dynamic>> get _rsvps =>
      _firestore.collection(_collection);

  /// Deterministic document ID. Keep in sync with `backend/firestore.rules`,
  /// which recomputes it to authorise reads, creates and deletes.
  static String docId(String uid, String eventId) => '${uid}_$eventId';

  String? get _uid {
    final uid = _auth.currentUser?.uid;
    return (uid == null || uid.isEmpty) ? null : uid;
  }

  /// Records an RSVP for [event]. Idempotent — re-running it rewrites the same
  /// document rather than creating a second one.
  ///
  /// [branch] defaults to the event's own branch; pass the member's active
  /// branch for all-campus events so attendance can be attributed.
  ///
  /// Throws [RsvpAuthRequiredException] when signed out.
  Future<void> rsvp(Event event, {String? branch}) {
    final uid = _uid;
    if (uid == null) throw const RsvpAuthRequiredException();
    return _rsvps.doc(docId(uid, event.id)).set({
      'userId': uid,
      'eventId': event.id,
      'branch': branch ?? event.branch,
      'eventStartTime': Timestamp.fromDate(event.startTime),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Removes the signed-in member's RSVP for [eventId]. Deleting a document
  /// that is not there is a no-op in Firestore, so this is safe to call twice.
  ///
  /// Throws [RsvpAuthRequiredException] when signed out.
  Future<void> cancelRsvp(String eventId) {
    final uid = _uid;
    if (uid == null) throw const RsvpAuthRequiredException();
    return _rsvps.doc(docId(uid, eventId)).delete();
  }

  /// Whether the signed-in member has RSVP'd to [eventId]. `false` when
  /// signed out or when the lookup fails.
  Future<bool> isRsvped(String eventId) async {
    final uid = _uid;
    if (uid == null) return false;
    try {
      final doc = await _rsvps.doc(docId(uid, eventId)).get();
      return doc.exists;
    } catch (_) {
      return false;
    }
  }

  /// Adds or removes the RSVP for [event] and returns the resulting state:
  /// `true` when the member is now going, `false` when they cancelled.
  Future<bool> toggleRsvp(Event event, {String? branch}) async {
    if (await isRsvped(event.id)) {
      await cancelRsvp(event.id);
      return false;
    }
    await rsvp(event, branch: branch);
    return true;
  }

  /// Realtime stream of the signed-in member's RSVPs, latest event first.
  ///
  /// Emits an empty list while signed out and re-subscribes on sign-in /
  /// sign-out, so a single listener survives the whole session.
  Stream<List<Rsvp>> watchMyRsvps() {
    final controller = StreamController<List<Rsvp>>();
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? docs;
    late final StreamSubscription<fb.User?> auth;

    Future<void> resubscribe(fb.User? user) async {
      await docs?.cancel();
      docs = null;
      final uid = user?.uid;
      if (uid == null || uid.isEmpty) {
        if (!controller.isClosed) controller.add(const []);
        return;
      }
      docs = _rsvps
          .where('userId', isEqualTo: uid)
          .orderBy('eventStartTime', descending: true)
          .snapshots()
          .listen(
        (snap) {
          if (!controller.isClosed) {
            controller.add(snap.docs.map(_map).whereType<Rsvp>().toList());
          }
        },
        onError: (_) {
          if (!controller.isClosed) controller.add(const []);
        },
      );
    }

    auth = _auth.authStateChanges().listen(resubscribe);
    controller.onCancel = () async {
      await docs?.cancel();
      await auth.cancel();
    };
    return controller.stream;
  }

  Rsvp? _map(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final userId = data['userId'] as String?;
    final eventId = data['eventId'] as String?;
    final start = data['eventStartTime'];
    if (userId == null || eventId == null || start is! Timestamp) return null;
    final createdAt = data['createdAt'];
    return Rsvp(
      id: doc.id,
      userId: userId,
      eventId: eventId,
      eventStartTime: start.toDate(),
      branch: data['branch'] as String?,
      createdAt: createdAt is Timestamp ? createdAt.toDate() : null,
    );
  }
}
