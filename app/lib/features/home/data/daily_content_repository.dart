import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:kharis_app/core/constants/api_config.dart';

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

  static const String _apiUrl = ApiConfig.getDailyReading;

  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 15),
    ),
  );

  /// Returns today's content (or the fallback if unavailable).
  Future<DailyContent> getTodaysContent() async {
    final dateKey = _dateKey(DateTime.now());
    return getContentForDate(dateKey);
  }

  /// Realtime stream of today's content; emits the fallback first so the UI
  /// is never empty, then live snapshots as the document changes.
  Stream<DailyContent> watchTodaysContent() async* {
    final dateKey = _dateKey(DateTime.now());
    // API-first: one-shot fetch from the Cloud Functions endpoint so content
    // appears even when Firestore is cold/unreachable, then hand over to the
    // realtime Firestore stream below.
    final apiContent = await _fetchFromApi();
    if (apiContent != null) yield apiContent;
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

  /// One-shot fetch of today's reading from the `getDailyReading` API.
  /// Returns `null` on any failure so callers fall straight through to
  /// Firestore.
  Future<DailyContent?> _fetchFromApi() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(_apiUrl);
      final readings = (res.data?['readings'] as List?) ?? const [];
      final first = readings.isNotEmpty ? readings.first : null;
      if (first is! Map<String, dynamic> || first.isEmpty) return null;
      return _mapData(first);
    } catch (_) {
      return null;
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

  // ── Write methods (admin) ──────────────────────────────────────────────────

  /// Creates or overwrites the dailyContent document for [dateKey] (YYYY-MM-DD).
  Future<void> setContent(String dateKey, DailyContent content) {
    return _firestore.collection('dailyContent').doc(dateKey).set({
      'reading': {
        'book': content.reading.book,
        'chapter': content.reading.chapter,
        'verse': content.reading.verse,
      },
      'prayer': content.prayer,
      'prayerReference': content.prayerReference,
    });
  }

  /// Batch-creates a sequential reading series: one chapter per day starting
  /// from [startDate] for [days] days, beginning at [book] chapter [startChapter].
  Future<int> batchSetContent({
    required String book,
    required int startChapter,
    required DateTime startDate,
    required int days,
    String prayer = '',
  }) async {
    final batch = _firestore.batch();
    for (var i = 0; i < days; i++) {
      final date = startDate.add(Duration(days: i));
      final chapter = startChapter + i;
      final key = _dateKey(date);
      final ref = _firestore.collection('dailyContent').doc(key);
      batch.set(ref, {
        'reading': {
          'book': book,
          'chapter': chapter,
          'verse': '1-end',
        },
        'prayer': prayer.isNotEmpty
            ? prayer
            : 'Lord, speak to us through $book $chapter today.',
        'prayerReference': '$book $chapter:1',
      });
    }
    await batch.commit();
    return days;
  }

  /// Deletes the dailyContent document for [dateKey].
  Future<void> deleteContent(String dateKey) =>
      _firestore.collection('dailyContent').doc(dateKey).delete();

  /// Streams the most recent dailyContent documents for the admin list view.
  Stream<List<MapEntry<String, DailyContent>>> watchRecentContent({int limit = 30}) {
    return _firestore
        .collection('dailyContent')
        .orderBy(FieldPath.documentId, descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => MapEntry(d.id, _mapData(d.data())))
            .toList());
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
