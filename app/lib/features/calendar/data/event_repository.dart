import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:kharis_app/core/constants/api_config.dart';

@immutable
class Event {
  const Event({
    required this.id,
    required this.title,
    required this.startTime,
    this.endTime,
    this.description,
    this.location,
    this.address,
    this.branch,
    this.imageUrl,
    this.isFeatured = false,
  });

  final String id;
  final String title;
  final String? description;

  /// Venue name, e.g. "Kensington Town Hall".
  final String? location;

  /// Street address of [location], for maps and the event detail screen.
  final String? address;

  /// Branch / campus this event belongs to (e.g. "London", "Manchester").
  /// `null` means the event applies to all branches; a blank stored value is
  /// read as `null` too, exactly as the API reads it.
  final String? branch;

  /// True when a member whose campus is [memberBranch] should see this event:
  /// its campus is theirs, it is all-campus, or they follow all campuses.
  bool isVisibleTo(String? memberBranch) =>
      memberBranch == null || branch == null || branch == memberBranch;

  final DateTime startTime;

  /// Optional end instant. The backend declares `endTime` as optional
  /// (`backend/functions/src/types.ts`) and older documents omit it, so this
  /// must never be assumed present — use [effectiveEndTime] instead.
  final DateTime? endTime;

  final String? imageUrl;
  final bool isFeatured;

  /// The instant the event is over. Events with no explicit end are treated
  /// as ending when they start.
  DateTime get effectiveEndTime => endTime ?? startTime;

  /// True once the event has finished. An event that has started but not yet
  /// ended is deliberately *not* past, so it stays in "Upcoming" while it runs.
  bool isPastAt(DateTime now) => effectiveEndTime.isBefore(now);

  @override
  bool operator ==(Object other) =>
      other is Event && other.id == id && other.startTime == startTime;

  @override
  int get hashCode => Object.hash(id, startTime);

  @override
  String toString() => 'Event(id: $id, title: $title, branch: $branch)';
}

/// Reads events from the `getEvents` API with a realtime Firestore fallback.
///
/// Both an upcoming and a past view are supported. Past-ness is decided by
/// [Event.effectiveEndTime], not by `startTime`, so an in-progress event does
/// not vanish from "Upcoming" the moment it begins.
class EventRepository {
  /// [dio] is the client for the `getEvents` API; tests pass one with a stub
  /// adapter so the Firestore path is exercised without the network.
  EventRepository({FirebaseFirestore? firestore, Dio? dio})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _dio = dio ?? _defaultDio;

  final FirebaseFirestore _firestore;
  final Dio _dio;

  static const String _apiUrl = ApiConfig.getEvents;

  /// Firestore can only range-filter on `startTime`, so the upcoming query
  /// reaches this far back to pick up events that have already started but
  /// have not finished. Bounded to keep the query cheap; anything longer than
  /// this is treated as past once the window slides past it.
  static const Duration _inProgressLookback = Duration(days: 2);

  /// The Past view is a capped archive, not a full history: only the 15 most
  /// recent finished events are ever fetched or shown. Older events stay in
  /// Firestore — this is a view cap, and it also bounds the query cost.
  /// Mirrors `PAST_EVENT_LIMIT` in `backend/functions/src/index.ts`.
  static const int pastEventLimit = 15;

  /// `whereIn` accepts at most 30 values per query.
  static const int _whereInChunk = 30;

  static final Dio _defaultDio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 15),
    ),
  );

  // ── Reads ──────────────────────────────────────────────────────────────────

  /// How many recent past events a branch-scoped Past view reads before the
  /// in-memory branch filter, so other campuses' events cannot crowd a
  /// campus's own history out of the [pastEventLimit] cap.
  static const int _scopedPastWindow = 60;

  /// Realtime stream of upcoming events, optionally branch-filtered: that
  /// campus's events plus all-campus ones (null, blank or absent `branch`).
  Stream<List<Event>> watchUpcomingEvents({String? branch}) =>
      _watchEvents(branch: branch, past: false);

  /// Realtime stream of the [pastEventLimit] most recent finished events.
  Stream<List<Event>> watchPastEvents({String? branch}) =>
      _watchEvents(branch: branch, past: true);

  Stream<List<Event>> _watchEvents({
    required String? branch,
    required bool past,
  }) async* {
    // API-first: one-shot fetch from the Cloud Functions endpoint so content
    // appears even when Firestore is cold/unreachable, then hand over to the
    // realtime Firestore stream below.
    final apiEvents = await _fetchFromApi(branch: branch, past: past);
    if (apiEvents != null && apiEvents.isNotEmpty) yield apiEvents;
    try {
      // One unfiltered window, scoped in memory: an equality filter on
      // `branch` can never match a doc with no `branch` key, which is how
      // all-campus events written before the field existed are stored.
      yield* _windowQuery(
        now: DateTime.now(),
        past: past,
        pastLimit: branch == null ? pastEventLimit : _scopedPastWindow,
      ).snapshots().map((snap) {
        // Re-evaluate past-ness against the current clock on every snapshot so
        // an event moves between tabs as it starts and finishes.
        final at = DateTime.now();
        final events = _mapDocs(
          snap.docs,
          now: at,
          past: past,
        ).where((e) => e.isVisibleTo(branch)).toList();
        return _sorted(events, past: past);
      });
    } catch (_) {
      yield const [];
    }
  }

  /// The Firestore range window for a view. Client-side filtering on
  /// [Event.isPastAt] narrows this to the exact set.
  ///
  /// The past window is bounded at [pastLimit] documents so the query
  /// itself — not just the rendered list — stays capped. An event that has
  /// started but not finished falls inside the range yet is filtered out as
  /// not-past, so a running event can leave the Past tab one short; that is
  /// the deliberate cost of not paying for a wider read.
  Query<Map<String, dynamic>> _windowQuery({
    required DateTime now,
    required bool past,
    int pastLimit = pastEventLimit,
  }) {
    final events = _firestore.collection('events');
    if (past) {
      return events
          .where('startTime', isLessThan: Timestamp.fromDate(now))
          .orderBy('startTime', descending: true)
          .limit(pastLimit);
    }
    return events
        .where(
          'startTime',
          isGreaterThanOrEqualTo: Timestamp.fromDate(
            now.subtract(_inProgressLookback),
          ),
        )
        .orderBy('startTime');
  }

  /// Fetches events by document ID, chunked to Firestore's `whereIn` limit so
  /// resolving an RSVP list costs O(n / 30) reads instead of one read each.
  /// Missing IDs are simply absent from the result.
  Future<List<Event>> getEventsByIds(List<String> ids) async {
    final unique = ids.toSet().toList(growable: false);
    if (unique.isEmpty) return const [];
    try {
      final chunks = <List<String>>[];
      for (var i = 0; i < unique.length; i += _whereInChunk) {
        chunks.add(
          unique.sublist(i, math.min(i + _whereInChunk, unique.length)),
        );
      }
      final snaps = await Future.wait(
        chunks.map(
          (chunk) => _firestore
              .collection('events')
              .where(FieldPath.documentId, whereIn: chunk)
              .get(),
        ),
      );
      return [
        for (final snap in snaps)
          ...snap.docs.map(_docToEvent).whereType<Event>(),
      ];
    } catch (_) {
      return const [];
    }
  }

  /// Fetches a single event by its Firestore document ID.
  Future<Event?> getEventById(String id) async {
    try {
      final doc = await _firestore.collection('events').doc(id).get();
      final data = doc.data();
      if (!doc.exists || data == null) return null;
      return _mapData(doc.id, data);
    } catch (_) {
      return null;
    }
  }

  /// One-shot fetch from the `getEvents` API. Returns `null` on any failure
  /// so callers fall straight through to Firestore.
  Future<List<Event>?> _fetchFromApi({
    required String? branch,
    required bool past,
  }) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        _apiUrl,
        queryParameters: {
          'branch': ?branch,
          'when': past ? 'past' : 'upcoming',
          'limit': past ? pastEventLimit : 50,
        },
      );
      final raw = (res.data?['events'] as List?) ?? const [];
      final now = DateTime.now();
      final events = raw
          .whereType<Map<String, dynamic>>()
          .map(_mapApi)
          .whereType<Event>()
          .where((e) => e.isPastAt(now) == past)
          .toList();
      return _sorted(events, past: past);
    } catch (_) {
      return null;
    }
  }

  // ── Admin writes ────────────────────────────────────────────────────────────

  /// Creates an event. Blank optional strings are stored as `null`; a blank
  /// [branch] means all-campus.
  Future<void> addEvent({
    required String title,
    String? description,
    String? location,
    String? address,
    String? branch,
    required DateTime startTime,
    required DateTime endTime,
    String? imageUrl,
    bool isFeatured = false,
  }) {
    return _firestore.collection('events').add({
      'title': title,
      'description': _blankToNull(description),
      'location': _blankToNull(location),
      'address': _blankToNull(address),
      'branch': _blankToNull(branch),
      'startTime': Timestamp.fromDate(startTime),
      'endTime': Timestamp.fromDate(endTime),
      'imageUrl': _blankToNull(imageUrl),
      'isFeatured': isFeatured,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Partial update: only the arguments that are passed are written.
  ///
  /// `null` means "leave as stored", so a form that does not edit the banner
  /// or the featured flag can never wipe them, and a campus-scoped screen
  /// cannot silently re-scope an all-campus event. To CLEAR an optional
  /// string pass `''`, which is stored as `null` (for [branch]: all-campus).
  Future<void> updateEvent(
    String id, {
    String? title,
    String? description,
    String? location,
    String? address,
    String? branch,
    DateTime? startTime,
    DateTime? endTime,
    String? imageUrl,
    bool? isFeatured,
  }) {
    final data = <String, Object?>{
      'title': ?title,
      if (description != null) 'description': _blankToNull(description),
      if (location != null) 'location': _blankToNull(location),
      if (address != null) 'address': _blankToNull(address),
      if (branch != null) 'branch': _blankToNull(branch),
      if (startTime != null) 'startTime': Timestamp.fromDate(startTime),
      if (endTime != null) 'endTime': Timestamp.fromDate(endTime),
      if (imageUrl != null) 'imageUrl': _blankToNull(imageUrl),
      'isFeatured': ?isFeatured,
    };
    if (data.isEmpty) return Future.value();
    return _firestore.collection('events').doc(id).update(data);
  }

  Future<void> deleteEvent(String id) =>
      _firestore.collection('events').doc(id).delete();

  static String? _blankToNull(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  // ── Mapping ────────────────────────────────────────────────────────────────

  /// Maps documents and keeps only those on the requested side of [now].
  List<Event> _mapDocs(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs, {
    required DateTime now,
    required bool past,
  }) => docs
      .map(_docToEvent)
      .whereType<Event>()
      .where((e) => e.isPastAt(now) == past)
      .toList();

  /// Orders a page and, for the Past view, applies [pastEventLimit]. Every
  /// read path — Firestore one-shot, Firestore stream and the API fetch —
  /// returns through here, so the cap cannot be bypassed by adding a caller.
  List<Event> _sorted(List<Event> events, {required bool past}) {
    final sorted = [...events]
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
    if (!past) return sorted;
    return sorted.reversed.take(pastEventLimit).toList();
  }

  Event? _docToEvent(QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
      _mapData(doc.id, doc.data());

  /// Returns `null` when the document has no usable `startTime` — a single
  /// malformed document must never take out the whole list. `endTime` is
  /// genuinely optional, so its absence is not a failure.
  Event? _mapData(String id, Map<String, dynamic> data) {
    final start = _toDate(data['startTime']);
    if (start == null) return null;
    return Event(
      id: id,
      title: data['title'] as String? ?? '',
      description: data['description'] as String?,
      location: _blankToNull(data['location'] as String?),
      address: _blankToNull(data['address'] as String?),
      branch: _blankToNull(data['branch'] as String?),
      startTime: start,
      endTime: _toDate(data['endTime']),
      imageUrl: _blankToNull(data['imageUrl'] as String?),
      isFeatured: data['isFeatured'] as bool? ?? false,
    );
  }

  Event? _mapApi(Map<String, dynamic> j) {
    final id = j['id'] as String?;
    final title = j['title'] as String?;
    if (id == null || title == null) return null;
    final start = _toDate(j['startTime']);
    if (start == null) return null;
    return Event(
      id: id,
      title: title,
      description: j['description'] as String?,
      location: _blankToNull(j['location'] as String?),
      address: _blankToNull(j['address'] as String?),
      branch: _blankToNull(j['branch'] as String?),
      startTime: start,
      endTime: _toDate(j['endTime']),
      imageUrl: _blankToNull(j['imageUrl'] as String?),
      isFeatured: j['isFeatured'] as bool? ?? false,
    );
  }

  static DateTime? _toDate(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    // API instants are ISO-8601 UTC ('...Z'); render them on the device clock
    // like Firestore Timestamps, or a 19:00 BST event reads as 18:00.
    if (value is String) return DateTime.tryParse(value)?.toLocal();
    return null;
  }
}
