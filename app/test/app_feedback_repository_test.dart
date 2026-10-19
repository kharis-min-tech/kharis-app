import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kharis_app/features/feedback/data/app_feedback_repository.dart';

void main() {
  test('writes one attributed feedback doc with a trimmed comment', () async {
    final db = FakeFirebaseFirestore();
    await AppFeedbackRepository(db, uid: 'u1').submit(
      rating: 4,
      comment: '  Love the new player  ',
      source: FeedbackSource.prompt,
    );

    final docs = (await db.collection('app_feedback').get()).docs;
    expect(docs, hasLength(1));
    final data = docs.single.data();
    expect(data['uid'], 'u1');
    expect(data['rating'], 4);
    expect(data['comment'], 'Love the new player');
    expect(data['source'], 'prompt');
    expect(data['platform'], isA<String>());
    // Exactly the keys the Firestore rule allows.
    expect(data.keys.toSet(), {
      'uid',
      'rating',
      'comment',
      'source',
      'platform',
      'createdAt',
    });
  });

  test('uses the rules-enforced {uid}_{yyyymmdd} id for the UTC day', () async {
    final db = FakeFirebaseFirestore();
    // 23:30 at UTC-5 on Oct 17 is already Oct 18 in UTC.
    final at = DateTime.utc(2026, 10, 18, 4, 30);
    await AppFeedbackRepository(
      db,
      uid: 'u1',
      clock: () => at,
    ).submit(rating: 5, comment: '', source: FeedbackSource.settings);

    final docs = (await db.collection('app_feedback').get()).docs;
    expect(docs.single.id, 'u1_20261018');
    expect(
      AppFeedbackRepository.docIdFor('u1', DateTime.utc(2027, 1, 2, 23, 59)),
      'u1_20270102',
    );
  });

  test('a second submission the same day replaces the first', () async {
    final db = FakeFirebaseFirestore();
    final repo = AppFeedbackRepository(
      db,
      uid: 'u1',
      clock: () => DateTime.utc(2026, 10, 18, 9),
    );
    await repo.submit(rating: 2, comment: 'meh', source: FeedbackSource.prompt);
    await repo.submit(
      rating: 5,
      comment: 'better',
      source: FeedbackSource.settings,
    );

    final docs = (await db.collection('app_feedback').get()).docs;
    expect(docs, hasLength(1));
    expect(docs.single.data()['rating'], 5);
    expect(docs.single.data()['comment'], 'better');
  });

  test('caps the comment at the rule limit', () async {
    final db = FakeFirebaseFirestore();
    await AppFeedbackRepository(
      db,
      uid: 'u1',
    ).submit(rating: 2, comment: 'x' * 2500, source: FeedbackSource.settings);
    final data = (await db.collection('app_feedback').get()).docs.single.data();
    expect(
      (data['comment'] as String).length,
      AppFeedbackRepository.maxCommentLength,
    );
  });

  test(
    'refuses to write without a user or with an out-of-range rating',
    () async {
      final db = FakeFirebaseFirestore();
      final anonymous = AppFeedbackRepository(db, uid: '');
      expect(anonymous.hasUser, isFalse);
      await expectLater(
        anonymous.submit(rating: 5, comment: '', source: FeedbackSource.prompt),
        throwsStateError,
      );
      await expectLater(
        AppFeedbackRepository(
          db,
          uid: 'u1',
        ).submit(rating: 6, comment: '', source: FeedbackSource.prompt),
        throwsArgumentError,
      );
      expect((await db.collection('app_feedback').get()).docs, isEmpty);
    },
  );
}
