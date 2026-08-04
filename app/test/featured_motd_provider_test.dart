import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kharis_app/features/messages/data/motd_repository.dart';
import 'package:kharis_app/shared/models/sermon.dart';
import 'package:kharis_app/shared/providers/sermon_provider.dart';

/// Coverage for the Studio-controlled Messages hero.
///
/// The original defect: `featuredSermonsProvider` fell back to the 3 newest
/// library sermons, so the app showed "featured" content even though the live
/// `sermons` collection had zero `isFeatured` docs — the Studio's star toggle
/// appeared to do nothing.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Sermon sermon(String id, {bool isFeatured = false}) => Sermon(
        id: id,
        title: 'Sermon $id',
        speaker: 'Rev. Test',
        audioUrl: 'https://cdn.example.com/$id.mp3',
        isFeatured: isFeatured,
      );

  /// Container with the live sources stubbed: [cms] is the Firestore
  /// `sermons` stream, [library] the merged CMS+API list, [motdId] the
  /// `config/messageOfTheDay` sermonId (null = doc absent).
  Future<ProviderContainer> settled({
    List<Sermon> cms = const [],
    List<Sermon> library = const [],
    String? motdId,
  }) async {
    final container = ProviderContainer(
      overrides: [
        adminSermonsProvider.overrideWith((ref) => Stream.value(cms)),
        sermonsProvider.overrideWith((ref) async => library),
        motdSermonIdProvider.overrideWith((ref) => Stream.value(motdId)),
      ],
    );
    addTearDown(container.dispose);
    await container.read(adminSermonsProvider.future);
    await container.read(sermonsProvider.future);
    await container.read(motdSermonIdProvider.future);
    return container;
  }

  group('featuredSermonsProvider', () {
    test('zero isFeatured docs -> empty, even with a populated library',
        () async {
      final container = await settled(
        cms: [sermon('a'), sermon('b')],
        library: [sermon('x'), sermon('y'), sermon('z')],
      );
      expect(
        container.read(featuredSermonsProvider),
        isEmpty,
        reason: 'no newest-N fallback: unfeatured docs must never surface',
      );
    });

    test('returns only isFeatured docs, capped at 5', () async {
      final container = await settled(
        cms: [
          for (var i = 0; i < 7; i++) sermon('f$i', isFeatured: true),
          sermon('plain'),
        ],
      );
      final featured = container.read(featuredSermonsProvider);
      expect(featured, hasLength(5));
      expect(featured.every((s) => s.isFeatured), isTrue);
    });
  });

  group('motdSermonProvider', () {
    test('resolves the configured sermonId against the CMS stream', () async {
      final container = await settled(
        cms: [sermon('a'), sermon('motd-1')],
        motdId: 'motd-1',
      );
      expect(container.read(motdSermonProvider)?.id, 'motd-1');
    });

    test('falls through to the merged library for API-sourced ids', () async {
      final container = await settled(
        cms: [sermon('a')],
        library: [sermon('api-9')],
        motdId: 'api-9',
      );
      expect(container.read(motdSermonProvider)?.id, 'api-9');
    });

    test('null when the config doc is absent', () async {
      final container = await settled(cms: [sermon('a')]);
      expect(container.read(motdSermonProvider), isNull);
    });

    test('null when the sermonId dangles (sermon deleted)', () async {
      final container = await settled(
        cms: [sermon('a')],
        library: [sermon('b')],
        motdId: 'gone',
      );
      expect(container.read(motdSermonProvider), isNull);
    });
  });

  group('MotdRepository', () {
    test('emits the sermonId from config/messageOfTheDay', () async {
      final db = FakeFirebaseFirestore();
      await db.collection('config').doc('messageOfTheDay').set({
        'sermonId': 'abc123',
        'setAt': DateTime(2026, 8, 4),
      });
      final repo = MotdRepository(firestore: db);
      expect(await repo.watchSermonId().first, 'abc123');
    });

    test('emits null when the doc is missing', () async {
      final repo = MotdRepository(firestore: FakeFirebaseFirestore());
      expect(await repo.watchSermonId().first, isNull);
    });

    test('emits null when sermonId is blank', () async {
      final db = FakeFirebaseFirestore();
      await db
          .collection('config')
          .doc('messageOfTheDay')
          .set({'sermonId': '  '});
      final repo = MotdRepository(firestore: db);
      expect(await repo.watchSermonId().first, isNull);
    });
  });
}
