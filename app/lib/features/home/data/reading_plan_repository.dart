import 'package:cloud_firestore/cloud_firestore.dart';

import 'reading_plan.dart';

// The model and resolution rules live in `reading_plan.dart` (pure Dart) and are
// re-exported so callers only ever import this repository.
export 'reading_plan.dart';

/// Firestore access for [ReadingPlan] documents — `readingPlans/{planId}`.
class ReadingPlanRepository {
  ReadingPlanRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  /// Mirrors `PLAN_LOOKBACK` in `reading-plans.ts`.
  static const int _lookback = 25;

  CollectionReference<Map<String, dynamic>> get _plans =>
      _firestore.collection('readingPlans');

  /// Plans that had already started on or before [date], newest start first —
  /// the order [resolvePlanReading] and the backend both expect. Single-field
  /// range + order, so this needs no composite index.
  Future<List<ReadingPlan>> plansThrough(DateTime date) async {
    final snapshot = await _plans
        .where('startDate', isLessThanOrEqualTo: readingDateKey(dateOnly(date)))
        .orderBy('startDate', descending: true)
        .limit(_lookback)
        .get();
    return _parse(snapshot.docs);
  }

  /// All plans, newest start first — the Content Studio list.
  Stream<List<ReadingPlan>> watchPlans({int limit = 50}) {
    return _plans
        .orderBy('startDate', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => _parse(snapshot.docs));
  }

  /// Creates [plan] when its id is empty, otherwise overwrites it.
  Future<void> savePlan(ReadingPlan plan) async {
    final data = plan.toMap();
    if (plan.id.isEmpty) {
      await _plans.add(data);
      return;
    }
    await _plans.doc(plan.id).set(data);
  }

  Future<void> deletePlan(String id) => _plans.doc(id).delete();

  List<ReadingPlan> _parse(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final plans = <ReadingPlan>[];
    for (final doc in docs) {
      final plan = ReadingPlan.fromMap(doc.id, doc.data());
      if (plan != null) plans.add(plan);
    }
    return plans;
  }
}
