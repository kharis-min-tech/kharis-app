import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:kharis_app/shared/models/campus_config.dart';

/// Content Studio writes for one campus's own settings on `branches/{id}`:
/// giving, Home layout, contact and service times.
///
/// Every write is a partial `update()` of just those fields (plus
/// `updatedAt`), never `name`, `order`, `group` or `isActive`, so a campus
/// admin's save stays within what the rules let them change.
class BranchSettingsRepository {
  BranchSettingsRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _branch(String id) =>
      _firestore.collection('branches').doc(id);

  /// The raw branch doc, realtime; null when it does not exist (a bundled
  /// seed campus that was never saved to Firestore).
  Stream<Map<String, dynamic>?> watchBranch(String id) =>
      _branch(id).snapshots().map((doc) => doc.data());

  Future<void> _update(String id, Map<String, Object?> fields) => _branch(
    id,
  ).update({...fields, 'updatedAt': FieldValue.serverTimestamp()});

  /// null (or empty details) removes `giving`: the campus gives to the
  /// church-wide account.
  Future<void> setGiving(String id, GivingDetails? giving) => _update(id, {
    'giving': giving == null || giving.isEmpty
        ? FieldValue.delete()
        : giving.toJson(),
  });

  /// null removes `home`: the campus uses the church-wide default layout.
  Future<void> setHome(String id, HomeLayout? home) =>
      _update(id, {'home': home?.toJson() ?? FieldValue.delete()});

  /// Writes `contact` and the top-level `instagram`.
  Future<void> setContact(String id, CampusContact contact) => _update(id, {
    'contact': contact.toJson(),
    'instagram': contact.instagram ?? FieldValue.delete(),
  });

  /// Replaces `services` with [services], in their order.
  Future<void> setServices(String id, List<CampusService> services) =>
      _update(id, {
        'services': [for (final s in services) s.toJson()],
      });

  /// The legacy flat venue fields (`address`, `meetingDays`, `meetingTime`)
  /// older app builds read; null clears one.
  Future<void> setVenueSummary(
    String id, {
    String? address,
    String? meetingDays,
    String? meetingTime,
  }) => _update(id, {
    'address': address,
    'meetingDays': meetingDays,
    'meetingTime': meetingTime,
  });
}
