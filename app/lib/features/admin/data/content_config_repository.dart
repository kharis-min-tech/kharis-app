import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'package:kharis_app/features/home/data/reading_plan.dart'
    show readingDateKey;

/// How the Messages tab picks its featured carousel (`config/featured.mode`).
enum FeaturedMode {
  /// The newest YouTube uploads, mapped to their audio twins. The default
  /// whenever the doc or its `mode` is missing.
  auto,

  /// Firestore `sermons` docs the Studio starred (`isFeatured == true`).
  pinned;

  static FeaturedMode parse(Object? raw) =>
      raw == 'pinned' ? FeaturedMode.pinned : FeaturedMode.auto;
}

/// One scheduled Message of the Day: `motdSchedule/{dateKey}`.
@immutable
class MotdEntry {
  const MotdEntry({
    required this.dateKey,
    required this.sermonId,
    required this.title,
    this.setAt,
  });

  /// Device-local calendar date, `YYYY-MM-DD`.
  final String dateKey;

  /// API sermon id (numeric string) or a Firestore `sermons` doc id.
  final String sermonId;
  final String title;
  final DateTime? setAt;
}

/// Content Studio writes for the Messages tab's curated slots.
///
/// The app reads these through the messages providers; the schema is fixed:
///   * `config/featured` = {mode: 'auto'|'pinned', setAt}
///   * `motdSchedule/{YYYY-MM-DD}` = {sermonId, title, setAt}
/// Both are public-read, admin-write (backend/firestore.rules).
class ContentConfigRepository {
  ContentConfigRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> get _featured =>
      _firestore.collection('config').doc('featured');

  DocumentReference<Map<String, dynamic>> get _legacyMotd =>
      _firestore.collection('config').doc('messageOfTheDay');

  CollectionReference<Map<String, dynamic>> get _schedule =>
      _firestore.collection('motdSchedule');

  // ── Featured ───────────────────────────────────────────────────────────────

  Stream<FeaturedMode> watchFeaturedMode() => _featured.snapshots().map(
    (doc) => FeaturedMode.parse(doc.data()?['mode']),
  );

  Future<void> setFeaturedMode(FeaturedMode mode) =>
      _featured.set({'mode': mode.name, 'setAt': FieldValue.serverTimestamp()});

  // ── Message of the Day ─────────────────────────────────────────────────────

  /// Scheduled days from [from] onwards (inclusive), soonest first.
  Stream<List<MotdEntry>> watchSchedule({
    required DateTime from,
    int limit = 30,
  }) {
    return _schedule
        .where(
          FieldPath.documentId,
          isGreaterThanOrEqualTo: readingDateKey(from),
        )
        .orderBy(FieldPath.documentId)
        .limit(limit)
        .snapshots()
        .map(
          (snap) => [for (final doc in snap.docs) ?_entry(doc.id, doc.data())],
        );
  }

  /// Makes [sermonId] the Message of the Day for [date]'s calendar day,
  /// replacing whatever that day held.
  Future<void> scheduleMotd({
    required DateTime date,
    required String sermonId,
    required String title,
  }) => _schedule.doc(readingDateKey(date)).set({
    'sermonId': sermonId,
    'title': title,
    'setAt': FieldValue.serverTimestamp(),
  });

  /// Clears [date]; the app falls back to its automatic daily pick.
  Future<void> clearMotd(DateTime date) =>
      _schedule.doc(readingDateKey(date)).delete();

  /// One-shot move of the retired `config/messageOfTheDay` pointer into
  /// today's schedule slot. Today's slot is only filled when empty, so a
  /// newer schedule always wins; the legacy doc is deleted either way.
  /// Returns true when a legacy doc was found.
  Future<bool> migrateLegacyMotd({DateTime? today}) async {
    final legacy = await _legacyMotd.get();
    final data = legacy.data();
    if (!legacy.exists || data == null) return false;
    final sermonId = (data['sermonId'] as String?)?.trim() ?? '';
    final slot = _schedule.doc(readingDateKey(today ?? DateTime.now()));
    if (sermonId.isNotEmpty && !(await slot.get()).exists) {
      await slot.set({
        'sermonId': sermonId,
        'title': (data['title'] as String?) ?? '',
        'setAt': FieldValue.serverTimestamp(),
      });
    }
    await _legacyMotd.delete();
    return true;
  }

  static MotdEntry? _entry(String dateKey, Map<String, dynamic> data) {
    final sermonId = (data['sermonId'] as String?)?.trim() ?? '';
    if (sermonId.isEmpty) return null;
    return MotdEntry(
      dateKey: dateKey,
      sermonId: sermonId,
      title: (data['title'] as String?) ?? '',
      setAt: (data['setAt'] as Timestamp?)?.toDate(),
    );
  }
}
