import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:kharis_app/features/messages/data/curation_repository.dart'
    show FeaturedMode;
import 'package:kharis_app/shared/models/campus_config.dart';

/// Content Studio writes for the church-wide app settings in `config/*`.
///
/// The app reads these through its own providers; the schema is fixed:
///   * `config/featured` = {mode: 'auto'|'pinned'|'off', setAt}
///   * `config/giving` = [GivingDetails] JSON; absent ⇒ built-in details
///   * `config/home` = [HomeLayout] JSON; absent ⇒ [HomeLayout.fallback]
/// All are public-read, super-admin-write (backend/firestore.rules).
class ContentConfigRepository {
  ContentConfigRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _config(String id) =>
      _firestore.collection('config').doc(id);

  // ── Featured ───────────────────────────────────────────────────────────────

  Stream<FeaturedMode> watchFeaturedMode() => _config(
    'featured',
  ).snapshots().map((doc) => FeaturedMode.parse(doc.data()?['mode']));

  Future<void> setFeaturedMode(FeaturedMode mode) => _config(
    'featured',
  ).set({'mode': mode.name, 'setAt': FieldValue.serverTimestamp()});

  // ── Giving ─────────────────────────────────────────────────────────────────

  /// Church-wide giving details; null while Studio has set none.
  Stream<GivingDetails?> watchChurchGiving() => _config(
    'giving',
  ).snapshots().map((doc) => GivingDetails.fromJson(doc.data()));

  /// Replaces `config/giving`; null (or empty details) deletes it so the app
  /// falls back to its built-in details.
  Future<void> setChurchGiving(GivingDetails? giving) =>
      giving == null || giving.isEmpty
      ? _config('giving').delete()
      : _config('giving').set(giving.toJson());

  // ── Home layout ────────────────────────────────────────────────────────────

  /// Church-wide default Home layout; null while Studio has set none.
  Stream<HomeLayout?> watchChurchHome() =>
      _config('home').snapshots().map((doc) => HomeLayout.fromJson(doc.data()));

  /// Replaces `config/home`; null deletes it so the app uses
  /// [HomeLayout.fallback].
  Future<void> setChurchHome(HomeLayout? home) => home == null
      ? _config('home').delete()
      : _config('home').set(home.toJson());
}
