import 'package:flutter/foundation.dart';

/// What the app should ask for at an engagement moment, if anything.
enum ReviewPromptAction {
  none,

  /// The OS rating card (App Store / Play). Rare: the platforms cap it and
  /// may silently show nothing.
  nativeReview,

  /// Our own stars + comment sheet, saved to the church's backend.
  feedbackSheet,
}

/// How the member left the feedback sheet. Drives the sheet's own cooldown
/// only; it never influences whether the native review card is requested
/// (that would be review gating, which Google Play forbids).
enum FeedbackSheetOutcome { sent, notNow, optOut }

/// Persisted engagement and prompt history. Immutable; see
/// `ReviewPromptStore` for persistence.
@immutable
class ReviewPromptState {
  const ReviewPromptState({
    this.firstOpenAt,
    this.activeDays = 0,
    this.completedListens = 0,
    this.lastSheetAt,
    this.lastSheetOutcome,
    this.sheetAutoShows = 0,
    this.lastNativeAt,
    this.nativeRequests = 0,
  });

  /// First launch that recorded engagement. Null until the first launch.
  final DateTime? firstOpenAt;

  /// Distinct calendar days the app was opened.
  final int activeDays;

  /// Audio messages played through to the end.
  final int completedListens;

  final DateTime? lastSheetAt;
  final FeedbackSheetOutcome? lastSheetOutcome;

  /// Times the sheet opened by itself (Settings opens do not count).
  final int sheetAutoShows;

  final DateTime? lastNativeAt;
  final int nativeRequests;

  bool get sheetOptedOut => lastSheetOutcome == FeedbackSheetOutcome.optOut;
}

/// Decides when to ask. Pure, so every threshold is unit-testable.
///
/// Platform rules this encodes:
/// - Apple 5.6.1: store ratings only through the system prompt, which iOS
///   caps at 3 per 365 days; never on launch or from a button.
/// - Google Play: no opinion question before the rating card, so our sheet
///   and the native card are never chained and the sheet's answer is ignored
///   when deciding on the native card.
///
/// Cadence follows the 5 Sep product call: automatic prompts at most once a
/// quarter (any kind), with the More-menu row always available.
abstract final class ReviewPromptPolicy {
  // Native store review: rare, for established listeners.
  static const nativeMinInstallDays = 7;
  static const nativeMinActiveDays = 5;
  static const nativeMinCompletedListens = 3;
  static const nativeCooldown = Duration(days: 120);
  static const nativeMaxRequests = 3;

  // Our feedback sheet.
  static const sheetMinInstallDays = 3;
  static const sheetMinActiveDays = 3;
  static const sheetMinCompletedListens = 2;
  static const sheetCooldownAfterDismiss = Duration(days: 90);
  static const sheetCooldownAfterSend = Duration(days: 180);
  static const sheetMaxAutoShows = 4;

  /// Minimum gap between any two automatic prompts, of either kind: at most
  /// one a quarter.
  static const crossPromptGap = Duration(days: 90);

  /// [nativeAvailable] is false where the OS card cannot show (web, devices
  /// without Play Store); the sheet may then take the moment instead.
  static ReviewPromptAction decide(
    ReviewPromptState s,
    DateTime now, {
    required bool nativeAvailable,
  }) {
    final firstOpen = s.firstOpenAt;
    if (firstOpen == null) return ReviewPromptAction.none;
    final installAge = now.difference(firstOpen);

    bool elapsed(DateTime? since, Duration gap) =>
        since == null || now.difference(since) >= gap;

    final nativeDue =
        nativeAvailable &&
        installAge >= const Duration(days: nativeMinInstallDays) &&
        s.activeDays >= nativeMinActiveDays &&
        s.completedListens >= nativeMinCompletedListens &&
        s.nativeRequests < nativeMaxRequests &&
        elapsed(s.lastNativeAt, nativeCooldown) &&
        elapsed(s.lastSheetAt, crossPromptGap);
    if (nativeDue) return ReviewPromptAction.nativeReview;

    final sheetCooldown = s.lastSheetOutcome == FeedbackSheetOutcome.sent
        ? sheetCooldownAfterSend
        : sheetCooldownAfterDismiss;
    final sheetDue =
        !s.sheetOptedOut &&
        installAge >= const Duration(days: sheetMinInstallDays) &&
        s.activeDays >= sheetMinActiveDays &&
        s.completedListens >= sheetMinCompletedListens &&
        s.sheetAutoShows < sheetMaxAutoShows &&
        elapsed(s.lastSheetAt, sheetCooldown) &&
        elapsed(s.lastNativeAt, crossPromptGap);
    if (sheetDue) return ReviewPromptAction.feedbackSheet;

    return ReviewPromptAction.none;
  }
}
