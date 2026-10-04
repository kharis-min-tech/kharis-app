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
  pinned,

  /// No featured carousel: the Messages tab leads with its latest messages.
  off;

  /// The mode stored in `config/featured.mode`; anything unrecognised is
  /// [auto].
  static FeaturedMode parse(Object? raw) => switch (raw) {
    'pinned' => pinned,
    'off' => off,
    _ => auto,
  };
}

/// Reads the Studio's curation document `config/featured` =
/// `{mode: 'auto' | 'pinned' | 'off', setAt}`.
///
/// A missing doc, a blank field and read errors all map to auto, so a
/// Firestore outage degrades to the automatic picks instead of an empty
/// Messages tab.
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
}

/// Replaces a stream error (e.g. permission-denied) with [fallback].
StreamTransformer<T, T> _orDefault<T>(T fallback) =>
    StreamTransformer<T, T>.fromHandlers(
      handleError: (_, _, sink) => sink.add(fallback),
    );
