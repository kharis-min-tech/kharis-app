import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:kharis_app/core/theme/theme.dart';

/// Rate & feedback sheet (tracker KA-012).
///
/// One surface, two doors:
/// - **Rate the app** — the OS in-app review flow when the store exposes it.
///   TestFlight and internal-test builds usually don't, so unavailability
///   degrades to a thank-you toast instead of a broken store hop.
/// - **Send feedback** — the church help page, so bug reports reach the team
///   while star ratings wait for the public launch.
///
/// The same sheet serves the always-available More row and the quarterly
/// [FeedbackNudge] — the agreed cadence (product call, 5 Sep): pop-ups at
/// most quarterly, a manual button forever.
class FeedbackSheet extends StatelessWidget {
  const FeedbackSheet({super.key});

  /// Where "Send feedback" lands. Shares the Help & Support destination until
  /// a dedicated feedback form exists.
  static const String feedbackUrl = 'https://kharis.org/help';

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      // Size to content and scroll on short viewports (iPhone SE, landscape)
      // instead of the default 9/16-height cap, which clips "Not now".
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const FeedbackSheet(),
    );
  }

  Future<void> _rate(BuildContext context) async {
    // Captured before the pop tears this context out of the tree.
    final messenger = ScaffoldMessenger.maybeOf(context);
    Navigator.of(context).pop();
    var shown = false;
    try {
      final review = InAppReview.instance;
      if (await review.isAvailable()) {
        await review.requestReview();
        shown = true;
      }
    } catch (_) {
      // Store front unreachable — same handling as unavailable.
    }
    if (!shown) {
      messenger?.showSnackBar(
        const SnackBar(
          content: Text(
            'Thank you! Ratings unlock once the app is live on the stores.',
          ),
        ),
      );
    }
  }

  void _sendFeedback(BuildContext context) {
    Navigator.of(context).pop();
    unawaited(
      launchUrl(Uri.parse(feedbackUrl), mode: LaunchMode.externalApplication),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
        padding: const EdgeInsets.fromLTRB(24, 14, 24, 18),
        decoration: BoxDecoration(
          color: context.kc.surface,
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.kc.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Center(
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: context.kc.accentInk.withValues(alpha: 0.14),
                  ),
                  child: Icon(
                    Icons.star_rounded,
                    color: context.kc.accentInk,
                    size: 28,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Enjoying the Kharis app?',
                textAlign: TextAlign.center,
                style: AppTypography.display(
                  size: 19,
                  weight: FontWeight.w700,
                ).copyWith(color: context.kc.onBg),
              ),
              const SizedBox(height: 6),
              Text(
                'Your feedback shapes what gets built next.',
                textAlign: TextAlign.center,
                style: AppTypography.ui(
                  size: 13,
                  weight: FontWeight.w500,
                ).copyWith(color: context.kc.muted),
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: () => unawaited(_rate(context)),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  'Rate the app',
                  style: AppTypography.ui(size: 15, weight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: () => _sendFeedback(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: context.kc.onBg,
                  side: BorderSide(color: context.kc.divider),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  'Send feedback',
                  style: AppTypography.ui(size: 15, weight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'Not now',
                  style: AppTypography.ui(
                    size: 13,
                    weight: FontWeight.w600,
                  ).copyWith(color: context.kc.muted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Quarterly nudge scheduling for [FeedbackSheet].
///
/// Cadence agreed on the 5 Sep product call: nudge at most once a quarter,
/// never in a member's first sessions, and never on top of another prompt
/// (branch selection wins the first launch). The More-menu row stays as the
/// always-available manual path.
class FeedbackNudge {
  FeedbackNudge._();

  /// SharedPreferences keys. Public so tests can stage a member's history.
  @visibleForTesting
  static const String lastShownKey = 'feedback_nudge_last_ms';
  @visibleForTesting
  static const String sessionsKey = 'feedback_nudge_sessions';

  /// Quarterly, per the product call.
  static const Duration cadence = Duration(days: 90);

  /// A member has to have opened the app this many times before the first
  /// nudge — new joiners get to form an opinion first.
  static const int minSessions = 3;

  /// Call once per launch from the dashboard shell, post-frame.
  static Future<void> maybeShow(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();

    final sessions = (prefs.getInt(sessionsKey) ?? 0) + 1;
    await prefs.setInt(sessionsKey, sessions);
    if (sessions < minSessions) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    final last = prefs.getInt(lastShownKey);
    if (last != null && now - last < cadence.inMilliseconds) return;

    // Let launch work settle (mini-player restore, branch prompt); if some
    // other surface took over the screen, skip quietly until next launch.
    await Future<void>.delayed(const Duration(seconds: 4));
    if (!context.mounted) return;
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) return;

    await prefs.setInt(lastShownKey, now);
    if (context.mounted) {
      unawaited(FeedbackSheet.show(context));
    }
  }
}
