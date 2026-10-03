import 'package:shared_preferences/shared_preferences.dart';

import 'package:kharis_app/features/feedback/domain/review_prompt_policy.dart';

/// Persists [ReviewPromptState] in SharedPreferences.
///
/// Device-local on purpose: the OS rating quota is per device, and a member
/// who reinstalls is a fresh listener to ask.
class ReviewPromptStore {
  ReviewPromptStore(this._prefs);

  final SharedPreferences _prefs;

  static const _kFirstOpen = 'review_first_open_ms';
  static const _kLastActiveDay = 'review_last_active_day';
  static const _kActiveDays = 'review_active_days';
  static const _kCompleted = 'review_completed_listens';
  static const _kSheetAt = 'review_sheet_last_ms';
  static const _kSheetOutcome = 'review_sheet_outcome';
  static const _kSheetShows = 'review_sheet_auto_shows';
  static const _kNativeAt = 'review_native_last_ms';
  static const _kNativeCount = 'review_native_requests';

  /// Written by the retired quarterly launch nudge (KA-012). A member it
  /// already asked keeps that date, so the cutover never re-prompts early.
  static const _kLegacyNudgeAt = 'feedback_nudge_last_ms';

  ReviewPromptState read() {
    final outcome = _prefs.getString(_kSheetOutcome);
    final legacyNudgeAt = _time(_kLegacyNudgeAt);
    final sheetAt = _time(_kSheetAt);
    return ReviewPromptState(
      firstOpenAt: _time(_kFirstOpen),
      activeDays: _prefs.getInt(_kActiveDays) ?? 0,
      completedListens: _prefs.getInt(_kCompleted) ?? 0,
      lastSheetAt: sheetAt ?? legacyNudgeAt,
      lastSheetOutcome:
          FeedbackSheetOutcome.values
              .where((o) => o.name == outcome)
              .firstOrNull ??
          (legacyNudgeAt != null ? FeedbackSheetOutcome.notNow : null),
      sheetAutoShows: _prefs.getInt(_kSheetShows) ?? 0,
      lastNativeAt: _time(_kNativeAt),
      nativeRequests: _prefs.getInt(_kNativeCount) ?? 0,
    );
  }

  /// Records that the app was opened on [now]'s calendar day. Idempotent
  /// within a day; stamps the first-open date on the very first call.
  Future<void> recordActiveDay(DateTime now) async {
    if (_prefs.getInt(_kFirstOpen) == null) {
      await _prefs.setInt(_kFirstOpen, now.millisecondsSinceEpoch);
    }
    final day = '${now.year}-${now.month}-${now.day}';
    if (_prefs.getString(_kLastActiveDay) == day) return;
    await _prefs.setString(_kLastActiveDay, day);
    await _prefs.setInt(_kActiveDays, (_prefs.getInt(_kActiveDays) ?? 0) + 1);
  }

  Future<void> recordCompletedListen() =>
      _prefs.setInt(_kCompleted, (_prefs.getInt(_kCompleted) ?? 0) + 1);

  Future<void> recordSheetAutoShown() =>
      _prefs.setInt(_kSheetShows, (_prefs.getInt(_kSheetShows) ?? 0) + 1);

  /// Records how the sheet was left, from either the automatic prompt or the
  /// Settings entry, so a member who just sent feedback is not asked again.
  Future<void> recordSheetOutcome(
    FeedbackSheetOutcome outcome,
    DateTime now,
  ) async {
    await _prefs.setInt(_kSheetAt, now.millisecondsSinceEpoch);
    await _prefs.setString(_kSheetOutcome, outcome.name);
  }

  Future<void> recordNativeRequested(DateTime now) async {
    await _prefs.setInt(_kNativeAt, now.millisecondsSinceEpoch);
    await _prefs.setInt(_kNativeCount, (_prefs.getInt(_kNativeCount) ?? 0) + 1);
  }

  DateTime? _time(String key) {
    final ms = _prefs.getInt(key);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }
}
