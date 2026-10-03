import 'package:flutter_test/flutter_test.dart';
import 'package:kharis_app/features/feedback/data/review_prompt_store.dart';
import 'package:kharis_app/features/feedback/domain/review_prompt_policy.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ReviewPromptStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = ReviewPromptStore(await SharedPreferences.getInstance());
  });

  test('a fresh install has no history', () {
    final s = store.read();
    expect(s.firstOpenAt, isNull);
    expect(s.activeDays, 0);
    expect(s.completedListens, 0);
    expect(s.lastSheetOutcome, isNull);
  });

  test('active days count calendar days, not launches', () async {
    final day1 = DateTime(2026, 10, 1, 9);
    await store.recordActiveDay(day1);
    await store.recordActiveDay(day1.add(const Duration(hours: 10)));
    expect(store.read().activeDays, 1);

    await store.recordActiveDay(DateTime(2026, 10, 2, 8));
    expect(store.read().activeDays, 2);
    // First open is stamped once and never moves.
    expect(store.read().firstOpenAt, day1);
  });

  test('outcomes, shows and native requests survive a relaunch', () async {
    final now = DateTime(2026, 10, 3, 12);
    await store.recordCompletedListen();
    await store.recordCompletedListen();
    await store.recordSheetAutoShown();
    await store.recordSheetOutcome(FeedbackSheetOutcome.optOut, now);
    await store.recordNativeRequested(now);

    final relaunched = ReviewPromptStore(await SharedPreferences.getInstance());
    final s = relaunched.read();
    expect(s.completedListens, 2);
    expect(s.sheetAutoShows, 1);
    expect(s.lastSheetOutcome, FeedbackSheetOutcome.optOut);
    expect(s.sheetOptedOut, isTrue);
    expect(s.lastSheetAt, now);
    expect(s.lastNativeAt, now);
    expect(s.nativeRequests, 1);
  });

  test(
    'a member the retired launch nudge asked is not re-asked early',
    () async {
      final nudgedAt = DateTime(2026, 9, 20, 18);
      SharedPreferences.setMockInitialValues({
        'feedback_nudge_last_ms': nudgedAt.millisecondsSinceEpoch,
      });
      final s = ReviewPromptStore(await SharedPreferences.getInstance()).read();
      expect(s.lastSheetAt, nudgedAt);
      expect(s.lastSheetOutcome, FeedbackSheetOutcome.notNow);
      expect(
        ReviewPromptPolicy.decide(
          ReviewPromptState(
            firstOpenAt: DateTime(2026, 1, 1),
            activeDays: 50,
            completedListens: 50,
            lastSheetAt: s.lastSheetAt,
            lastSheetOutcome: s.lastSheetOutcome,
          ),
          DateTime(2026, 10, 3),
          nativeAvailable: true,
        ),
        ReviewPromptAction.none,
      );
    },
  );
}
