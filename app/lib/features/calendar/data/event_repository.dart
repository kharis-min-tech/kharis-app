import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

@immutable
class Event {
  const Event({
    required this.id,
    required this.title,
    required this.startTime,
    required this.endTime,
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

  /// Branch / campus this event belongs to (e.g. "Main", "North").
  /// `null` means the event applies to all branches.
  final String? branch;

  final DateTime startTime;
  final DateTime endTime;
  final String? imageUrl;
  final bool isFeatured;

  @override
  bool operator ==(Object other) =>
      other is Event && other.id == id && other.startTime == startTime;

  @override
  int get hashCode => Object.hash(id, startTime);

  @override
  String toString() => 'Event(id: $id, title: $title, branch: $branch)';
}

/// Reads upcoming events from the Firestore `events` collection.
///
/// Falls back to [_mockEvents] when Firestore is unavailable.
class EventRepository {
  EventRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  /// Returns upcoming events ordered by [startTime].
  ///
  /// [branch] – when provided, returns only events for that branch plus
  /// events where `branch` is null (all-campus events).
  Future<List<Event>> getUpcomingEvents({String? branch}) async {
    try {
      final now = Timestamp.fromDate(DateTime.now());
      Query<Map<String, dynamic>> query = _firestore
          .collection('events')
          .where('startTime', isGreaterThanOrEqualTo: now)
          .orderBy('startTime');
      if (branch != null) {
        // Firestore can't OR-filter in a single query; fetch branch-specific
        // events and all-campus events separately, then merge.
        final branchSnap = await query.where('branch', isEqualTo: branch).get();
        final allSnap = await query.where('branch', isNull: true).get();
        final merged = {
          for (final d in branchSnap.docs) d.id: _docToEvent(d),
          for (final d in allSnap.docs) d.id: _docToEvent(d),
        };
        final events = merged.values.toList()
          ..sort((a, b) => a.startTime.compareTo(b.startTime));
        return events;
      }
      final snapshot = await query.get();
      return snapshot.docs.map(_docToEvent).toList();
    } catch (_) {
      if (branch != null) {
        return _mockEvents
            .where((e) => e.branch == null || e.branch == branch)
            .toList();
      }
      return List.of(_mockEvents);
    }
  }

  /// Fetches a single event by its Firestore document ID.
  Future<Event?> getEventById(String id) async {
    try {
      final doc = await _firestore.collection('events').doc(id).get();
      if (!doc.exists || doc.data() == null) return null;
      return _mapData(doc.id, doc.data()!);
    } catch (_) {
      return _mockEvents.where((e) => e.id == id).firstOrNull;
    }
  }

  // ── Mapping ────────────────────────────────────────────────────────────────

  Event _docToEvent(QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
      _mapData(doc.id, doc.data());

  Event _mapData(String id, Map<String, dynamic> data) {
    return Event(
      id: id,
      title: data['title'] as String? ?? '',
      description: data['description'] as String?,
      location: data['location'] as String?,
      branch: data['branch'] as String?,
      startTime: (data['startTime'] as Timestamp).toDate(),
      endTime: (data['endTime'] as Timestamp).toDate(),
      imageUrl: data['imageUrl'] as String?,
      isFeatured: data['isFeatured'] as bool? ?? false,
    );
  }

  // ── Mock data ──────────────────────────────────────────────────────────────

  static final _mockEvents = [
    Event(
      id: 'mock_event_1',
      title: 'Sunday Service',
      description: 'Join us for our weekly Sunday worship service.',
      location: 'Main Auditorium',
      branch: null,
      startTime: DateTime.now().add(const Duration(days: 2, hours: 9)),
      endTime: DateTime.now().add(const Duration(days: 2, hours: 11)),
      isFeatured: true,
    ),
    Event(
      id: 'mock_event_2',
      title: 'Prayer Night',
      description: 'A night of corporate prayer and worship.',
      location: 'Chapel',
      branch: 'Main',
      startTime: DateTime.now().add(const Duration(days: 4, hours: 19)),
      endTime: DateTime.now().add(const Duration(days: 4, hours: 21)),
    ),
    Event(
      id: 'mock_event_3',
      title: 'Youth Conference',
      description: 'Annual youth gathering with speakers and workshops.',
      location: 'Community Hall',
      branch: null,
      startTime: DateTime.now().add(const Duration(days: 10, hours: 9)),
      endTime: DateTime.now().add(const Duration(days: 10, hours: 17)),
      isFeatured: true,
    ),
  ];
}
