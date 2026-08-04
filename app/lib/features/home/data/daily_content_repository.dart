import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:kharis_app/core/constants/api_config.dart';
import 'package:kharis_app/features/home/data/reading_plan_repository.dart';

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

  /// Human-readable reference, e.g. "John 3:16-17". A `1-end` verse range means
  /// the whole chapter, so it collapses to "Proverbs 2".
  String get reference => formatReadingReference(book, chapter, verse);
}

/// Where a resolved reading came from.
enum DailyContentSource {
  /// A hand-written `dailyContent/{date}` document.
  day,

  /// A reading plan that covers the date.
  plan,

  /// The last day of an expired plan, because nothing covers the date yet.
  planLastDay,

  /// Nothing is configured at all — the built-in fallback.
  fallback,
}

/// A reading plus why it resolved that way — what the Content Studio previews.
@immutable
class ResolvedDailyContent {
  const ResolvedDailyContent({
    required this.content,
    required this.source,
    this.planTitle,
  });

  final DailyContent content;
  final DailyContentSource source;

  /// Title of the plan behind [content], when it came from one.
  final String? planTitle;
}

/// Reads the devotional content for a date.
///
/// Resolution order matches `getDailyReading` on the backend:
///   1. a hand-written `dailyContent/{YYYY-MM-DD}` document;
///   2. the reading plan covering that date (see [resolvePlanReading]);
///   3. the last day of the most recently expired plan;
///   4. [_hardcodedContent], so the UI is never empty.
class DailyContentRepository {
  DailyContentRepository({
    FirebaseFirestore? firestore,
    ReadingPlanRepository? plans,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _plans = plans ?? ReadingPlanRepository(firestore: firestore);

  final FirebaseFirestore _firestore;
  final ReadingPlanRepository _plans;

  static const String _apiUrl = ApiConfig.getDailyReading;

  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 15),
    ),
  );

  /// Returns today's content (or the fallback if unavailable).
  Future<DailyContent> getTodaysContent() =>
      getContentForDate(readingDateKey(DateTime.now()));

  /// Realtime stream of today's content; emits the fallback first so the UI
  /// is never empty, then live snapshots as the document changes.
  Stream<DailyContent> watchTodaysContent() async* {
    final today = dateOnly(DateTime.now());
    // API-first: one-shot fetch from the Cloud Functions endpoint so content
    // appears even when Firestore is cold/unreachable, then hand over to the
    // realtime Firestore stream below.
    final apiContent = await _fetchFromApi();
    if (apiContent != null) yield apiContent;

    // Plans change rarely, so one fetch is enough to keep this fallback in step
    // with the plan resolution the API performs.
    final plans = await _plansOrEmpty(today);
    try {
      yield* _firestore
          .collection('dailyContent')
          .doc(readingDateKey(today))
          .snapshots()
          .map((doc) {
        final data = doc.data();
        // A hand-written day always wins over the plan.
        if (_hasReading(data)) return _mapData(data!);
        final resolved = resolvePlanReading(plans, today);
        return resolved == null
            ? _hardcodedContent
            : _fromPlan(resolved.reading);
      });
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
  Future<DailyContent> getContentForDate(String dateKey) async =>
      (await resolveForDate(dateKey)).content;

  /// Resolves [dateKey] and reports which rule produced the reading.
  Future<ResolvedDailyContent> resolveForDate(String dateKey) async {
    final date = parseReadingDate(dateKey) ?? dateOnly(DateTime.now());
    try {
      final doc =
          await _firestore.collection('dailyContent').doc(dateKey).get();
      final data = doc.data();
      // A hand-written day BEATS the plan for that date — that is what lets an
      // admin special-case Christmas without disturbing the plan around it.
      if (_hasReading(data)) {
        return ResolvedDailyContent(
          content: _mapData(data!),
          source: DailyContentSource.day,
        );
      }
    } catch (_) {
      // Fall through to plan resolution.
    }

    final resolved = resolvePlanReading(await _plansOrEmpty(date), date);
    if (resolved == null) {
      return const ResolvedDailyContent(
        content: _hardcodedContent,
        source: DailyContentSource.fallback,
      );
    }
    return ResolvedDailyContent(
      content: _fromPlan(resolved.reading),
      source: resolved.pinnedToLastDay
          ? DailyContentSource.planLastDay
          : DailyContentSource.plan,
      planTitle: resolved.plan.title,
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Future<List<ReadingPlan>> _plansOrEmpty(DateTime date) async {
    try {
      return await _plans.plansThrough(date);
    } catch (_) {
      return const [];
    }
  }

  bool _hasReading(Map<String, dynamic>? data) {
    final reading = data?['reading'];
    return reading is Map && (reading['book'] as String?)?.isNotEmpty == true;
  }

  DailyContent _fromPlan(PlanDayReading reading) => DailyContent(
        reading: BibleReading(
          book: reading.book,
          chapter: reading.chapter,
          verse: reading.verse,
        ),
        prayer: reading.prayer,
        prayerReference: reading.prayerReference,
      );

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
