import 'package:cloud_firestore/cloud_firestore.dart';

/// How the Messages featured carousel is chosen (Studio `config/featured`).
enum FeaturedMode {
  /// The newest YouTube uploads, mapped to their audio twins.
  auto,

  /// The Studio-starred `sermons` docs (`isFeatured == true`).
  pinned,
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

  Stream<FeaturedMode> watchFeaturedMode() async* {
    try {
      yield* _firestore
          .collection('config')
          .doc('featured')
          .snapshots()
          .map(
            (doc) => doc.data()?['mode'] == 'pinned'
                ? FeaturedMode.pinned
                : FeaturedMode.auto,
          );
    } catch (_) {
      yield FeaturedMode.auto;
    }
  }

  /// The sermon id scheduled for [dateKey] (`YYYY-MM-DD`), or null.
  Stream<String?> watchScheduledMotd(String dateKey) async* {
    try {
      yield* _firestore.collection('motdSchedule').doc(dateKey).snapshots().map(
        (doc) {
          final id = (doc.data()?['sermonId'] as String?)?.trim();
          return (id == null || id.isEmpty) ? null : id;
        },
      );
    } catch (_) {
      yield null;
    }
  }
}
