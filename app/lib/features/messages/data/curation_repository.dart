import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

/// How the Messages featured carousel is chosen (Studio `config/featured`).
///
/// The one definition shared by the member read side ([CurationRepository])
/// and the Studio write side (`ContentConfigRepository`).
enum FeaturedMode {
  /// The newest YouTube uploads, mapped to their audio twins. The default
  /// whenever the doc or its `mode` is missing.
  auto,

  /// The Studio-starred `sermons` docs (`isFeatured == true`).
  pinned;

  /// The mode stored in `config/featured.mode`; anything but `'pinned'` is
  /// [auto].
  static FeaturedMode parse(Object? raw) => raw == 'pinned' ? pinned : auto;
}

/// Reads the Studio's curation documents:
/// - `config/featured` = `{mode: 'auto' | 'pinned', setAt}`;
/// - `motdSchedule/{YYYY-MM-DD}` = `{sermonId, title, setAt}`, keyed by the
///   member's local calendar date.
///
/// Missing docs, blank fields and read errors all map to the default (auto
/// featured, no scheduled message), so a Firestore outage degrades to the
/// automatic picks instead of an empty Messages tab.
class CurationRepository {
  CurationRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Stream<FeaturedMode> watchFeaturedMode() => _firestore
      .collection('config')
      .doc('featured')
      .snapshots()
      .map((doc) => FeaturedMode.parse(doc.data()?['mode']))
      .transform(_orDefault(FeaturedMode.auto));

  /// The sermon id scheduled for [dateKey] (`YYYY-MM-DD`), or null.
  Stream<String?> watchScheduledMotd(String dateKey) => _firestore
      .collection('motdSchedule')
      .doc(dateKey)
      .snapshots()
      .map((doc) {
        final id = (doc.data()?['sermonId'] as String?)?.trim();
        return (id == null || id.isEmpty) ? null : id;
      })
      .transform(_orDefault<String?>(null));
}

/// Replaces a stream error (e.g. permission-denied) with [fallback].
StreamTransformer<T, T> _orDefault<T>(T fallback) =>
    StreamTransformer<T, T>.fromHandlers(
      handleError: (_, _, sink) => sink.add(fallback),
    );
