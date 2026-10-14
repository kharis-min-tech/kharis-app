import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kharis_app/features/home/data/daily_content_repository.dart';

// Plain `test`s: Firestore snapshot streams do not deliver under flutter_test's
// FakeAsync zone.
void main() {
  group('DailyContentRepository', () {
    test(
      'a plan day past the book is bounded and carries its plan day',
      () async {
        final firestore = FakeFirebaseFirestore();
        final start = DateTime.now().subtract(const Duration(days: 15));
        await firestore.collection('readingPlans').doc('p').set({
          'title': '2 Corinthians',
          'book': '2 Corinthians',
          'startDate':
              '${start.year.toString().padLeft(4, '0')}-'
              '${start.month.toString().padLeft(2, '0')}-'
              '${start.day.toString().padLeft(2, '0')}',
          'days': 20,
          'mode': 'chapter',
          'startChapter': 1,
        });
        final repo = DailyContentRepository(firestore: firestore);
        final now = DateTime.now();
        final key =
            '${now.year.toString().padLeft(4, '0')}-'
            '${now.month.toString().padLeft(2, '0')}-'
            '${now.day.toString().padLeft(2, '0')}';

        final resolved = await repo.resolveForDate(key);

        expect(resolved.content.reading.reference, '2 Corinthians 13');
        expect(resolved.content.planDay, 16);
        expect(resolved.content.planDays, 20);
      },
    );
  });
}
