import 'package:flutter_test/flutter_test.dart';

import 'package:kharis_app/features/home/data/reading_plan.dart';

/// Contract 7: a chapter plan never resolves past the end of its book. The
/// live bug was "2 Corinthians 17" (the book has 13 chapters), which the Bible
/// API answers with a 404.
void main() {
  final twoCor = ReadingPlan(
    id: 'p1',
    title: '2 Corinthians',
    book: '2 Corinthians',
    startDate: DateTime(2026, 9, 17),
    days: 20,
    startChapter: 1,
  );

  test('days 1-13 advance one chapter a day', () {
    for (var offset = 0; offset < 13; offset++) {
      expect(twoCor.readingForDay(offset).chapter, offset + 1);
    }
  });

  test('day 14+ holds on 2 Corinthians 13, never 14+', () {
    for (var offset = 13; offset < 20; offset++) {
      final reading = twoCor.readingForDay(offset);
      expect(reading.chapter, 13, reason: 'day ${offset + 1}');
      expect(reading.reference, '2 Corinthians 13');
    }
    expect(twoCor.lastReading.chapter, 13);
  });

  test('the plan reports its overrun and chapters remaining', () {
    expect(twoCor.bookChapters, 13);
    expect(twoCor.chaptersRemaining, 13);
    expect(twoCor.overrunsBook, isTrue);
    expect(twoCor.copyWith(days: 13).overrunsBook, isFalse);
    expect(twoCor.copyWith(startChapter: 10).chaptersRemaining, 4);
  });

  test('verse plans and unknown books are not flagged', () {
    expect(twoCor.copyWith(mode: ReadingPlanMode.verse).overrunsBook, isFalse);
    final unknown = twoCor.copyWith(book: 'Psalm');
    expect(unknown.chaptersRemaining, isNull);
    expect(unknown.readingForDay(19).chapter, 20);
  });

  test('resolution covers and then pins on the bounded last chapter', () {
    final day16 = resolvePlanReading([twoCor], DateTime(2026, 10, 2));
    expect(day16?.reading.chapter, 13);
    expect(day16?.day, 16);
    expect(day16?.pinnedToLastDay, isFalse);

    final after = resolvePlanReading([twoCor], DateTime(2026, 11, 1));
    expect(after?.reading.chapter, 13);
    expect(after?.day, 20);
    expect(after?.pinnedToLastDay, isTrue);
  });
}
