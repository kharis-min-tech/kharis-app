import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kharis_app/features/admin/data/content_config_repository.dart';
import 'package:kharis_app/features/messages/data/curation_repository.dart';

/// Firestore whose document listens fail, as on permission-denied.
class _DeniedFirestore extends Fake implements FirebaseFirestore {
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      _DeniedCollection();
}

// Test doubles, as fake_cloud_firestore does for the same sealed types.
// ignore: subtype_of_sealed_class
class _DeniedCollection extends Fake
    implements CollectionReference<Map<String, dynamic>> {
  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) => _DeniedDoc();
}

// ignore: subtype_of_sealed_class
class _DeniedDoc extends Fake
    implements DocumentReference<Map<String, dynamic>> {
  @override
  Stream<DocumentSnapshot<Map<String, dynamic>>> snapshots({
    bool includeMetadataChanges = false,
    ListenSource source = ListenSource.defaultSource,
  }) => Stream.error(
    FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'),
  );
}

void main() {
  test('a failed listen degrades to auto featured', () async {
    final repo = CurationRepository(firestore: _DeniedFirestore());
    expect(await repo.watchFeaturedMode().toList(), [FeaturedMode.auto]);
  });

  test("'off' is read as off; anything unknown stays auto", () async {
    final db = FakeFirebaseFirestore();
    final member = CurationRepository(firestore: db);
    await db.collection('config').doc('featured').set({'mode': 'off'});
    expect(await member.watchFeaturedMode().first, FeaturedMode.off);
  });

  test(
    'the Studio writer and the member reader share one FeaturedMode',
    () async {
      final db = FakeFirebaseFirestore();
      final studio = ContentConfigRepository(firestore: db);
      final member = CurationRepository(firestore: db);

      expect(await member.watchFeaturedMode().first, FeaturedMode.auto);
      await studio.setFeaturedMode(FeaturedMode.pinned);
      expect(await member.watchFeaturedMode().first, FeaturedMode.pinned);
      expect(await studio.watchFeaturedMode().first, FeaturedMode.pinned);

      await db.collection('config').doc('featured').set({'mode': 'bogus'});
      expect(await member.watchFeaturedMode().first, FeaturedMode.auto);
      expect(await studio.watchFeaturedMode().first, FeaturedMode.auto);
    },
  );
}
