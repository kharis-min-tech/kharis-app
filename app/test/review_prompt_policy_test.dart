import 'package:flutter_test/flutter_test.dart';
import 'package:kharis_app/features/feedback/domain/review_prompt_policy.dart';

final _now = DateTime(2026, 10, 3, 12);
DateTime _daysAgo(int d) => _now.subtract(Duration(days: d));

ReviewPromptAction _decide(ReviewPromptState s, {bool native = true}) =>
    ReviewPromptPolicy.decide(s, _now, nativeAvailable: native);

/// An engaged listener who clears every threshold for both prompts.
ReviewPromptState _engaged({
  DateTime? lastSheetAt,
  FeedbackSheetOutcome? lastSheetOutcome,
  int sheetAutoShows = 0,
  DateTime? lastNativeAt,
  int nativeRequests = 0,
  int activeDays = 10,
  int completedListens = 10,
}) => ReviewPromptState(
  firstOpenAt: _daysAgo(30),
  activeDays: activeDays,
  completedListens: completedListens,
  lastSheetAt: lastSheetAt,
  lastSheetOutcome: lastSheetOutcome,
  sheetAutoShows: sheetAutoShows,
  lastNativeAt: lastNativeAt,
  nativeRequests: nativeRequests,
);

void main() {
  test('never asks before engagement has been recorded', () {
    expect(_decide(const ReviewPromptState()), ReviewPromptAction.none);
  });

  test('a brand-new listener is not asked, even after completed listens', () {
    final s = ReviewPromptState(
      firstOpenAt: _daysAgo(1),
      activeDays: 2,
      completedListens: 5,
    );
    expect(_decide(s), ReviewPromptAction.none);
  });

  test('sheet becomes due at 3 days, 3 active days, 2 completed listens', () {
    final s = ReviewPromptState(
      firstOpenAt: _daysAgo(3),
      activeDays: 3,
      completedListens: 2,
    );
    expect(_decide(s), ReviewPromptAction.feedbackSheet);
    expect(
      _decide(
        ReviewPromptState(
          firstOpenAt: _daysAgo(3),
          activeDays: 3,
          completedListens: 1,
        ),
      ),
      ReviewPromptAction.none,
    );
  });

  test('an established listener gets the native card first', () {
    expect(_decide(_engaged()), ReviewPromptAction.nativeReview);
  });

  test('without a native card available, the sheet takes the moment', () {
    expect(
      _decide(_engaged(), native: false),
      ReviewPromptAction.feedbackSheet,
    );
  });

  test('native card respects its 120-day cooldown and lifetime cap', () {
    expect(
      _decide(_engaged(lastNativeAt: _daysAgo(119)), native: true),
      ReviewPromptAction.feedbackSheet,
    );
    expect(
      _decide(_engaged(lastNativeAt: _daysAgo(120))),
      ReviewPromptAction.nativeReview,
    );
    expect(
      _decide(_engaged(lastNativeAt: _daysAgo(400), nativeRequests: 3)),
      ReviewPromptAction.feedbackSheet,
    );
  });

  test('automatic prompts of either kind are at least a quarter apart', () {
    // Native just asked: the sheet waits too.
    expect(
      _decide(_engaged(lastNativeAt: _daysAgo(89), nativeRequests: 1)),
      ReviewPromptAction.none,
    );
    // Sheet just shown: the native card waits.
    expect(
      _decide(
        _engaged(
          lastSheetAt: _daysAgo(89),
          lastSheetOutcome: FeedbackSheetOutcome.sent,
        ),
      ),
      ReviewPromptAction.none,
    );
  });

  test('the sheet answer never decides whether the native card is shown', () {
    // Same history apart from the sheet answer: identical native decision.
    for (final outcome in FeedbackSheetOutcome.values) {
      expect(
        _decide(
          _engaged(lastSheetAt: _daysAgo(100), lastSheetOutcome: outcome),
        ),
        ReviewPromptAction.nativeReview,
        reason: 'outcome $outcome',
      );
    }
  });

  group('sheet cooldowns (native unavailable)', () {
    ReviewPromptAction sheet(ReviewPromptState s) => _decide(s, native: false);

    test('"Not now" waits a quarter (90 days)', () {
      expect(
        sheet(
          _engaged(
            lastSheetAt: _daysAgo(89),
            lastSheetOutcome: FeedbackSheetOutcome.notNow,
          ),
        ),
        ReviewPromptAction.none,
      );
      expect(
        sheet(
          _engaged(
            lastSheetAt: _daysAgo(90),
            lastSheetOutcome: FeedbackSheetOutcome.notNow,
          ),
        ),
        ReviewPromptAction.feedbackSheet,
      );
    });

    test('after sending, waits 180 days', () {
      expect(
        sheet(
          _engaged(
            lastSheetAt: _daysAgo(179),
            lastSheetOutcome: FeedbackSheetOutcome.sent,
          ),
        ),
        ReviewPromptAction.none,
      );
      expect(
        sheet(
          _engaged(
            lastSheetAt: _daysAgo(180),
            lastSheetOutcome: FeedbackSheetOutcome.sent,
          ),
        ),
        ReviewPromptAction.feedbackSheet,
      );
    });

    test('"Don\'t ask again" stops the automatic sheet for good', () {
      expect(
        sheet(
          _engaged(
            lastSheetAt: _daysAgo(3000),
            lastSheetOutcome: FeedbackSheetOutcome.optOut,
          ),
        ),
        ReviewPromptAction.none,
      );
    });

    test('the automatic sheet shows at most 4 times', () {
      expect(
        sheet(_engaged(sheetAutoShows: 3)),
        ReviewPromptAction.feedbackSheet,
      );
      expect(sheet(_engaged(sheetAutoShows: 4)), ReviewPromptAction.none);
    });
  });
}
