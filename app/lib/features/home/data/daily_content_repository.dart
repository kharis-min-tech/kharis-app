import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

@immutable
class DailyContent {
  const DailyContent({
    required this.reading,
    required this.prayer,
    required this.prayerReference,
  });

  final BibleReading reading;
  final String prayer;

  /// Scripture reference for the prayer (e.g. "Philippians 4:6").
  final String prayerReference;
}

@immutable
class BibleReading {
  const BibleReading({
    required this.book,
    required this.chapter,
    required this.verse,
  });

  final String book;
  final int chapter;
  final String verse;

  /// Human-readable reference, e.g. "John 3:16-17".
  String get reference => '$book $chapter:$verse';
}

/// Reads today's devotional content from the Firestore `dailyContent`
/// collection, keyed by date string `"YYYY-MM-DD"`.
///
/// Falls back to [_hardcodedContent] when Firestore is unavailable or the
/// document for today does not yet exist.
class DailyContentRepository {
  DailyContentRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  /// Returns today's content (or the fallback if unavailable).
  Future<DailyContent> getTodaysContent() async {
    final dateKey = _dateKey(DateTime.now());
    return getContentForDate(dateKey);
  }

  /// Realtime stream of today's content; emits the fallback first so the UI
  /// is never empty, then live snapshots as the document changes.
  Stream<DailyContent> watchTodaysContent() async* {
    final dateKey = _dateKey(DateTime.now());
    try {
      yield* _firestore
          .collection('dailyContent')
          .doc(dateKey)
          .snapshots()
          .map((doc) => doc.exists && doc.data() != null
              ? _mapData(doc.data()!)
              : _hardcodedContent);
    } catch (_) {
      yield _hardcodedContent;
    }
  }

  /// Returns content for [dateKey] formatted as `"YYYY-MM-DD"`.
  Future<DailyContent> getContentForDate(String dateKey) async {
    try {
      final doc =
          await _firestore.collection('dailyContent').doc(dateKey).get();
      if (!doc.exists || doc.data() == null) return _hardcodedContent;
      return _mapData(doc.data()!);
    } catch (_) {
      return _hardcodedContent;
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  DailyContent _mapData(Map<String, dynamic> data) {
    final readingData = data['reading'] as Map<String, dynamic>?;
    return DailyContent(
      reading: readingData != null
          ? BibleReading(
              book: readingData['book'] as String? ?? '',
              chapter: (readingData['chapter'] as num?)?.toInt() ?? 1,
              verse: readingData['verse'] as String? ?? '1',
            )
          : _hardcodedContent.reading,
      prayer: data['prayer'] as String? ?? _hardcodedContent.prayer,
      prayerReference: data['prayerReference'] as String? ??
          _hardcodedContent.prayerReference,
    );
  }

  // ── Fallback ───────────────────────────────────────────────────────────────

  static const _hardcodedContent = DailyContent(
    reading: BibleReading(book: 'Psalms', chapter: 23, verse: '1-6'),
    prayer:
        'Lord, thank You for being my Shepherd. Lead me today in paths of righteousness. '
        'Still my heart in moments of uncertainty and let Your goodness and mercy follow me.',
    prayerReference: 'Psalm 23:1',
  );
}
