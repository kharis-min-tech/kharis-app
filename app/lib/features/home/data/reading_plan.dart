/// Reading plans — the model and the date-resolution rules.
///
/// A plan is authored ONCE and covers a range of dates, resolving a reading for
/// every day inside it with no further admin action: Proverbs 1 on day 1,
/// Proverbs 2 on day 2, and so on. Resolution mirrors
/// `backend/functions/src/reading-plans.ts` exactly, so the app shows the same
/// reading whether it came from the API or from the Firestore fallback.
///
/// Deliberately import-free: the plan arithmetic is pure Dart and can be
/// exercised without Flutter or Firestore. Firestore access lives in
/// `reading_plan_repository.dart`. Every class here is immutable by
/// construction — const constructor, all fields final.
library;

/// How a plan advances from one day to the next.
enum ReadingPlanMode {
  /// One chapter per day. Day N is `startChapter + N - 1`.
  chapter,

  /// A verse block per day inside a single chapter — the "Hosea 1:1 through
  /// 1:10 over ten days" shape.
  verse,
}

/// `YYYY-MM-DD` key for [date], matching the `dailyContent` document IDs.
String readingDateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

/// Parses a `YYYY-MM-DD` key into a date-only [DateTime], or `null`.
DateTime? parseReadingDate(String key) {
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(key);
  if (match == null) return null;
  return DateTime(
    int.parse(match.group(1)!),
    int.parse(match.group(2)!),
    int.parse(match.group(3)!),
  );
}

/// Whole days since the epoch for [date]'s calendar day.
///
/// Deliberately built through [DateTime.utc]: plan arithmetic is calendar
/// arithmetic, and `add`/`difference` on local dates silently drifts by an hour
/// across a BST switch, which is enough to shift a reading by a whole day.
int readingDayNumber(DateTime date) =>
    DateTime.utc(date.year, date.month, date.day).millisecondsSinceEpoch ~/
        Duration.millisecondsPerDay;

/// Strips the time component so a picked date compares cleanly.
DateTime dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

/// Human reference for a reading; `1-end` means the whole chapter.
String formatReadingReference(String book, int chapter, String verse) {
  if (book.isEmpty) return '';
  if (verse.isEmpty || verse == '1-end') return '$book $chapter';
  return '$book $chapter:$verse';
}

/// The reading a plan yields for one of its days.
class PlanDayReading {
  const PlanDayReading({
    required this.book,
    required this.chapter,
    required this.verse,
    required this.prayer,
    required this.prayerReference,
  });

  final String book;
  final int chapter;
  final String verse;
  final String prayer;
  final String prayerReference;

  /// Human reference, collapsing the "whole chapter" verse range.
  String get reference => formatReadingReference(book, chapter, verse);
}

class ReadingPlan {
  const ReadingPlan({
    required this.id,
    required this.title,
    required this.book,
    required this.startDate,
    required this.days,
    required this.startChapter,
    this.mode = ReadingPlanMode.chapter,
    this.verses,
    this.startVerse = 1,
    this.versesPerDay = 1,
    this.prayer = '',
    this.prayerReference = '',
  });

  /// Firestore document ID; empty for a plan that has not been saved yet.
  final String id;
  final String title;
  final String book;

  /// Inclusive first day of the plan (date-only).
  final DateTime startDate;

  /// Plan length in days, inclusive of [startDate].
  final int days;

  final ReadingPlanMode mode;
  final int startChapter;

  /// [ReadingPlanMode.chapter]: verse range shown every day (`1-end` when null).
  final String? verses;

  /// [ReadingPlanMode.verse]: first verse of day 1.
  final int startVerse;

  /// [ReadingPlanMode.verse]: how many verses each day covers.
  final int versesPerDay;

  final String prayer;
  final String prayerReference;

  /// Inclusive last day of the plan. Built through the [DateTime] constructor
  /// (which normalises day overflow) rather than `add`, so it lands on midnight
  /// of the right calendar day even across a BST switch.
  DateTime get endDate =>
      DateTime(startDate.year, startDate.month, startDate.day + days - 1);

  bool covers(DateTime date) {
    final day = readingDayNumber(date);
    final start = readingDayNumber(startDate);
    return day >= start && day <= start + days - 1;
  }

  /// 0-based day offset of [date] within the plan (may fall outside the range).
  int offsetFor(DateTime date) =>
      readingDayNumber(date) - readingDayNumber(startDate);

  /// The last reading the plan yields.
  PlanDayReading get lastReading => readingForDay(days - 1);

  /// The reading for day [offset] (0-based).
  PlanDayReading readingForDay(int offset) {
    final firstChapter = startChapter < 1 ? 1 : startChapter;
    final int chapter;
    final String verse;
    if (mode == ReadingPlanMode.verse) {
      final perDay = versesPerDay < 1 ? 1 : versesPerDay;
      final first = (startVerse < 1 ? 1 : startVerse) + offset * perDay;
      chapter = firstChapter;
      verse = perDay == 1 ? '$first' : '$first-${first + perDay - 1}';
    } else {
      chapter = firstChapter + offset;
      final range = (verses ?? '').trim();
      verse = range.isEmpty ? '1-end' : range;
    }
    final reference = formatReadingReference(book, chapter, verse);
    return PlanDayReading(
      book: book,
      chapter: chapter,
      verse: verse,
      prayer: prayer.trim().isEmpty
          ? 'Lord, speak to us through $reference today.'
          : prayer.trim(),
      prayerReference: prayerReference.trim().isEmpty
          ? reference
          : prayerReference.trim(),
    );
  }

  ReadingPlan copyWith({
    String? id,
    String? title,
    String? book,
    DateTime? startDate,
    int? days,
    ReadingPlanMode? mode,
    int? startChapter,
    String? verses,
    int? startVerse,
    int? versesPerDay,
    String? prayer,
    String? prayerReference,
  }) {
    return ReadingPlan(
      id: id ?? this.id,
      title: title ?? this.title,
      book: book ?? this.book,
      startDate: startDate ?? this.startDate,
      days: days ?? this.days,
      mode: mode ?? this.mode,
      startChapter: startChapter ?? this.startChapter,
      verses: verses ?? this.verses,
      startVerse: startVerse ?? this.startVerse,
      versesPerDay: versesPerDay ?? this.versesPerDay,
      prayer: prayer ?? this.prayer,
      prayerReference: prayerReference ?? this.prayerReference,
    );
  }

  /// Parses a Firestore document, returning `null` when the plan is unusable —
  /// the same guard the backend applies, so both sides ignore the same docs.
  static ReadingPlan? fromMap(String id, Map<String, dynamic> data) {
    final start = parseReadingDate((data['startDate'] as String?) ?? '');
    final book = (data['book'] as String?)?.trim() ?? '';
    final days = (data['days'] as num?)?.toInt() ?? 0;
    if (start == null || book.isEmpty || days < 1) return null;
    return ReadingPlan(
      id: id,
      title: (data['title'] as String?)?.trim() ?? '',
      book: book,
      startDate: start,
      days: days,
      mode: data['mode'] == 'verse'
          ? ReadingPlanMode.verse
          : ReadingPlanMode.chapter,
      startChapter: (data['startChapter'] as num?)?.toInt() ?? 1,
      verses: (data['verses'] as String?)?.trim(),
      startVerse: (data['startVerse'] as num?)?.toInt() ?? 1,
      versesPerDay: (data['versesPerDay'] as num?)?.toInt() ?? 1,
      prayer: (data['prayer'] as String?) ?? '',
      prayerReference: (data['prayerReference'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'title': title,
        'book': book,
        'startDate': readingDateKey(startDate),
        'days': days,
        'mode': mode == ReadingPlanMode.verse ? 'verse' : 'chapter',
        'startChapter': startChapter,
        'verses': mode == ReadingPlanMode.chapter ? verses : null,
        'startVerse': startVerse,
        'versesPerDay': versesPerDay,
        'prayer': prayer,
        'prayerReference': prayerReference,
      };
}

/// A resolved plan reading plus why it was chosen.
class PlanResolution {
  const PlanResolution({
    required this.plan,
    required this.reading,
    required this.pinnedToLastDay,
  });

  final ReadingPlan plan;
  final PlanDayReading reading;

  /// True when [plan] had already finished and its LAST day is being shown.
  final bool pinnedToLastDay;
}

/// Resolves [date] against [plans].
///
/// Precedence, mirroring `resolveFromPlans` in the backend:
///   1. the most recently STARTING plan that covers [date];
///   2. otherwise the plan that ENDED most recently, pinned to its last day.
///
/// (2) is an explicit product requirement: when a schedule runs out and nobody
/// has authored the next one, the reading stays on the final day of the old
/// schedule instead of going blank. Do not "simplify" it away.
PlanResolution? resolvePlanReading(List<ReadingPlan> plans, DateTime date) {
  final day = readingDayNumber(date);

  ReadingPlan? covering;
  for (final plan in plans) {
    if (!plan.covers(date)) continue;
    if (covering == null ||
        readingDayNumber(plan.startDate) >
            readingDayNumber(covering.startDate)) {
      covering = plan;
    }
  }
  if (covering != null) {
    return PlanResolution(
      plan: covering,
      reading: covering.readingForDay(covering.offsetFor(date)),
      pinnedToLastDay: false,
    );
  }

  ReadingPlan? pinned;
  for (final plan in plans) {
    if (readingDayNumber(plan.endDate) >= day) continue;
    if (pinned == null ||
        readingDayNumber(plan.endDate) > readingDayNumber(pinned.endDate)) {
      pinned = plan;
    }
  }
  return pinned == null
      ? null
      : PlanResolution(
          plan: pinned,
          reading: pinned.lastReading,
          pinnedToLastDay: true,
        );
}
