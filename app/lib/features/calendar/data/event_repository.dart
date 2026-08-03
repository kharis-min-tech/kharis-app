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
    this.branch,
    this.imageUrl,
    this.isFeatured = false,
  });

  final String id;
  final String title;
  final String? description;
  final String? location;

  /// Branch / campus this event belongs to (e.g. "London", "Manchester").
  /// `null` means the event applies to all branches.
  final String? branch;

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
  EventRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const String _apiUrl = ApiConfig.getEvents;

  /// Firestore can only range-filter on `startTime`, so the upcoming query
  /// reaches this far back to pick up events that have already started but
  /// have not finished. Bounded to keep the query cheap; anything longer than
  /// this is treated as past once the window slides past it.
  static const Duration _inProgressLookback = Duration(days: 2);

  /// `whereIn` accepts at most 30 values per query.
  static const int _whereInChunk = 30;

  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 15),
    ),
  );

  // ── Reads ──────────────────────────────────────────────────────────────────

  /// Returns upcoming (not yet finished) events ordered by [Event.startTime].
  ///
  /// [branch] – when provided, returns only events for that branch plus
  /// events where `branch` is null (all-campus events).
  Future<List<Event>> getUpcomingEvents({String? branch}) =>
      _getEvents(branch: branch, past: false);

  /// Returns finished events, most recent first. Mirrors [getUpcomingEvents].
  Future<List<Event>> getPastEvents({String? branch}) =>
      _getEvents(branch: branch, past: true);

  /// Realtime stream of upcoming events, optionally branch-filtered.
  Stream<List<Event>> watchUpcomingEvents({String? branch}) =>
      _watchEvents(branch: branch, past: false);

  /// Realtime stream of past events, most recent first.
  Stream<List<Event>> watchPastEvents({String? branch}) =>
      _watchEvents(branch: branch, past: true);

  Future<List<Event>> _getEvents({
    required String? branch,
    required bool past,
  }) async {
    try {
      final now = DateTime.now();
      final query = _windowQuery(now: now, past: past);
      if (branch != null) {
        // Firestore can't OR-filter in a single query; fetch branch-specific
        // events and all-campus events separately, then merge.
        final branchSnap = await query.where('branch', isEqualTo: branch).get();
        final allSnap = await query.where('branch', isNull: true).get();
        final merged = <String, Event>{
          for (final e in _mapDocs(branchSnap.docs, now: now, past: past))
            e.id: e,
          for (final e in _mapDocs(allSnap.docs, now: now, past: past)) e.id: e,
        };
        return _sorted(merged.values.toList(), past: past);
      }
      final snapshot = await query.get();
      return _sorted(_mapDocs(snapshot.docs, now: now, past: past), past: past);
    } catch (_) {
      return const [];
    }
  }

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
      yield* _windowQuery(now: DateTime.now(), past: past)
          .snapshots()
          .map((snap) {
        // Re-evaluate past-ness against the current clock on every snapshot so
        // an event moves between tabs as it starts and finishes.
        final at = DateTime.now();
        final events = _mapDocs(snap.docs, now: at, past: past)
            .where((e) =>
                branch == null || e.branch == null || e.branch == branch)
            .toList();
        return _sorted(events, past: past);
      });
    } catch (_) {
      yield const [];
    }
  }

  /// The Firestore range window for a view. Client-side filtering on
  /// [Event.isPastAt] narrows this to the exact set.
  Query<Map<String, dynamic>> _windowQuery({
    required DateTime now,
    required bool past,
  }) {
    final events = _firestore.collection('events');
    if (past) {
      return events
          .where('startTime', isLessThan: Timestamp.fromDate(now))
          .orderBy('startTime', descending: true);
    }
    return events
        .where(
          'startTime',
          isGreaterThanOrEqualTo:
              Timestamp.fromDate(now.subtract(_inProgressLookback)),
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
        chunks.map((chunk) => _firestore
            .collection('events')
            .where(FieldPath.documentId, whereIn: chunk)
            .get()),
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
          'limit': 50,
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

  Future<void> addEvent({
    required String title,
    String? description,
    String? location,
    String? branch,
    required DateTime startTime,
    required DateTime endTime,
    String? imageUrl,
    bool isFeatured = false,
  }) {
    return _firestore.collection('events').add(_toData(
          title: title,
          description: description,
          location: location,
          branch: branch,
          startTime: startTime,
          endTime: endTime,
          imageUrl: imageUrl,
          isFeatured: isFeatured,
        ));
  }

  Future<void> updateEvent(
    String id, {
    required String title,
    String? description,
    String? location,
    String? branch,
    required DateTime startTime,
    required DateTime endTime,
    String? imageUrl,
    bool isFeatured = false,
  }) {
    return _firestore.collection('events').doc(id).update(_toData(
          title: title,
          description: description,
          location: location,
          branch: branch,
          startTime: startTime,
          endTime: endTime,
          imageUrl: imageUrl,
          isFeatured: isFeatured,
        ));
  }

  Future<void> deleteEvent(String id) =>
      _firestore.collection('events').doc(id).delete();

  Map<String, Object?> _toData({
    required String title,
    String? description,
    String? location,
    String? branch,
    required DateTime startTime,
    required DateTime endTime,
    String? imageUrl,
    bool isFeatured = false,
  }) =>
      {
        'title': title,
        'description': description,
        'location': location,
        'branch': branch,
        'startTime': Timestamp.fromDate(startTime),
        'endTime': Timestamp.fromDate(endTime),
        'imageUrl': imageUrl,
        'isFeatured': isFeatured,
      };

  // ── Mapping ────────────────────────────────────────────────────────────────

  /// Maps documents and keeps only those on the requested side of [now].
  List<Event> _mapDocs(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs, {
    required DateTime now,
    required bool past,
  }) =>
      docs
          .map(_docToEvent)
          .whereType<Event>()
          .where((e) => e.isPastAt(now) == past)
          .toList();

  List<Event> _sorted(List<Event> events, {required bool past}) {
    final sorted = [...events]
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
    return past ? sorted.reversed.toList() : sorted;
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
      location: data['location'] as String?,
      branch: data['branch'] as String?,
      startTime: start,
      endTime: _toDate(data['endTime']),
      imageUrl: data['imageUrl'] as String?,
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
      location: j['location'] as String?,
      branch: j['branch'] as String?,
      startTime: start,
      endTime: _toDate(j['endTime']),
      imageUrl: j['imageUrl'] as String?,
      isFeatured: j['isFeatured'] as bool? ?? false,
    );
  }

  static DateTime? _toDate(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}
