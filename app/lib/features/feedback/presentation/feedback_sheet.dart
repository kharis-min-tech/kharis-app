import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kharis_app/core/theme/theme.dart';
import 'package:kharis_app/features/feedback/data/app_feedback_repository.dart';
import 'package:kharis_app/features/feedback/domain/review_prompt_policy.dart';
import 'package:kharis_app/features/feedback/providers/feedback_providers.dart';
import 'package:kharis_app/shared/providers/auth_provider.dart';

/// Opens the feedback sheet and records how it was left.
///
/// A successful send is recorded even if the member then swipes the thank-you
/// state away. A swipe-away from the automatic prompt otherwise counts as
/// "Not now". From Settings only a send is recorded: a member browsing the
/// menu who backs out has not declined anything.
Future<FeedbackSheetOutcome?> showFeedbackSheet(
  BuildContext context,
  WidgetRef ref, {
  required FeedbackSource source,
}) async {
  final store = ref.read(reviewPromptStoreProvider);
  final now = ref.read(reviewClockProvider);
  var sent = false;
  final popped = await showModalBottomSheet<FeedbackSheetOutcome>(
    context: context,
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => FeedbackSheet(source: source, onSent: () => sent = true),
  );
  final outcome = sent ? FeedbackSheetOutcome.sent : popped;
  final recorded =
      outcome ??
      (source == FeedbackSource.prompt ? FeedbackSheetOutcome.notNow : null);
  if (recorded != null &&
      (source == FeedbackSource.prompt ||
          recorded == FeedbackSheetOutcome.sent)) {
    await store.recordSheetOutcome(recorded, now());
  }
  return outcome;
}

/// Stars + optional comment, saved to the church's backend. This is our own
/// feedback channel, not a store review: it never routes to the App Store.
class FeedbackSheet extends ConsumerStatefulWidget {
  const FeedbackSheet({super.key, required this.source, this.onSent});

  final FeedbackSource source;

  /// Fires once the feedback has been accepted for delivery.
  final VoidCallback? onSent;

  @override
  ConsumerState<FeedbackSheet> createState() => _FeedbackSheetState();
}

class _FeedbackSheetState extends ConsumerState<FeedbackSheet> {
  static const _ratingLabels = [
    'Not good',
    'Could be better',
    'It’s okay',
    'Good',
    'Love it',
  ];

  final _comment = TextEditingController();
  int? _rating;
  bool _sending = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final rating = _rating;
    if (rating == null || _sending) return;
    final repo = ref.read(appFeedbackRepositoryProvider);
    if (!repo.hasUser) {
      ref.read(anonymousSignInProvider).ensure();
      setState(() => _error = 'Still signing you in. Try again in a moment.');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await repo.submit(
        rating: rating,
        comment: _comment.text,
        source: widget.source,
      );
      widget.onSent?.call();
      if (mounted) setState(() => _sent = true);
    } catch (e) {
      debugPrint('FeedbackSheet: submit failed: $e');
      if (mounted) {
        setState(
          () => _error =
              'Couldn’t send right now. Check your connection and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _close(FeedbackSheetOutcome outcome) =>
      Navigator.of(context).pop(outcome);

  @override
  Widget build(BuildContext context) {
    // Watched, not just read at send time: keeps the auth stream subscribed
    // so the member's uid is ready when they tap Send.
    ref.watch(appFeedbackRepositoryProvider);
    final kc = context.kc;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        // Material, not a decorated Container: the star and text-button ink
        // must paint on the sheet surface to be visible.
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          child: Material(
            color: kc.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            clipBehavior: Clip.antiAlias,
            child: AnimatedSize(
              duration: reduceMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 200),
              curve: Curves.easeOutQuart,
              alignment: Alignment.topCenter,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 10),
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: kc.outline,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                    child: _sent ? _thanks(context) : _form(context),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _form(BuildContext context) {
    final kc = context.kc;
    final rating = _rating;
    final lowRating = rating != null && rating <= 3;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'How is the Kharis app serving you?',
          style: AppTypography.display(
            size: 20,
            weight: FontWeight.w700,
            color: kc.onBg,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Your rating goes straight to the Kharis team.',
          style: AppTypography.bodySm.copyWith(color: kc.muted),
        ),
        const SizedBox(height: 18),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var n = 1; n <= 5; n++)
              Semantics(
                button: true,
                selected: rating == n,
                label: '$n of 5 stars, ${_ratingLabels[n - 1]}',
                excludeSemantics: true,
                child: IconButton(
                  key: ValueKey('feedback-star-$n'),
                  iconSize: 36,
                  onPressed: _sending
                      ? null
                      : () => setState(() {
                          _rating = n;
                          _error = null;
                        }),
                  icon: Icon(
                    rating != null && n <= rating
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    // accentInk, not the gold fill: raw gold is 1.9:1 on the
                    // light sheet. The empty star uses full muted (60% gave
                    // 2.4 to 2.9:1) because it is the control.
                    color: rating != null && n <= rating
                        ? kc.accentInk
                        : kc.muted,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          rating == null ? 'Tap a star to rate' : _ratingLabels[rating - 1],
          textAlign: TextAlign.center,
          style: AppTypography.ui(
            size: 13,
            weight: FontWeight.w600,
            color: rating == null ? kc.muted : kc.onBg,
          ),
        ),
        if (rating != null) ...[
          const SizedBox(height: 16),
          TextField(
            key: const ValueKey('feedback-comment'),
            controller: _comment,
            enabled: !_sending,
            minLines: 3,
            maxLines: 5,
            maxLength: AppFeedbackRepository.maxCommentLength,
            textCapitalization: TextCapitalization.sentences,
            style: AppTypography.bodySm.copyWith(color: kc.onBg),
            decoration: InputDecoration(
              hintText: lowRating
                  ? 'What should we improve? (optional)'
                  : 'What do you value most? (optional)',
              counterText: '',
            ),
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(
            _error!,
            style: AppTypography.bodySm.copyWith(color: context.kc.danger),
          ),
        ],
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: rating == null || _sending ? null : _send,
          child: _sending
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: kc.onAccent,
                  ),
                )
              : const Text('Send feedback'),
        ),
        const SizedBox(height: 4),
        if (widget.source == FeedbackSource.prompt)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _quietButton(
                'Don’t ask again',
                () => _close(FeedbackSheetOutcome.optOut),
              ),
              _quietButton(
                'Not now',
                () => _close(FeedbackSheetOutcome.notNow),
              ),
            ],
          )
        else
          Center(
            child: _quietButton('Cancel', () => Navigator.of(context).pop()),
          ),
      ],
    );
  }

  Widget _quietButton(String label, VoidCallback onPressed) => TextButton(
    onPressed: _sending ? null : onPressed,
    style: TextButton.styleFrom(foregroundColor: context.kc.muted),
    child: Text(
      label,
      style: AppTypography.ui(size: 14, weight: FontWeight.w600),
    ),
  );

  Widget _thanks(BuildContext context) {
    final kc = context.kc;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(Icons.check_circle_rounded, size: 44, color: kc.accentInk),
        const SizedBox(height: 12),
        Text(
          'Thank you',
          textAlign: TextAlign.center,
          style: AppTypography.display(
            size: 20,
            weight: FontWeight.w700,
            color: kc.onBg,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Your feedback has been sent to the Kharis team.',
          textAlign: TextAlign.center,
          style: AppTypography.bodySm.copyWith(color: kc.muted),
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: () => _close(FeedbackSheetOutcome.sent),
          child: const Text('Done'),
        ),
      ],
    );
  }
}
