import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kharis_app/features/feedback/data/app_feedback_repository.dart';
import 'package:kharis_app/features/feedback/domain/review_prompt_policy.dart';
import 'package:kharis_app/features/feedback/providers/feedback_providers.dart';
import 'package:kharis_app/shared/providers/auth_provider.dart';
import 'package:kharis_app/ui/components/components.dart';

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
  final popped = await showKBottomSheet<FeedbackSheetOutcome>(
    // The root navigator, so the sheet covers the tab bar and mini player.
    context: Navigator.of(context, rootNavigator: true).context,
    title: 'How is the Kharis app serving you?',
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
///
/// The content of the sheet [showFeedbackSheet] opens, which supplies the
/// title.
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

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: _sent ? _thanks(context) : _form(context),
      ),
    );
  }

  Widget _form(BuildContext context) {
    final k = context.k;
    final rating = _rating;
    final lowRating = rating != null && rating <= 3;
    final error = _error;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Your rating goes straight to the Kharis team.',
                style: KharisText.meta.copyWith(color: k.muted),
              ),
            ),
            const SizedBox(width: KSpace.md),
            KIconButton(
              icon: KIcons.close,
              label: 'Close feedback',
              onPressed: _sending ? null : () => Navigator.of(context).pop(),
            ),
          ],
        ),
        const SizedBox(height: KSpace.x3),
        Row(
          children: [
            for (var n = 1; n <= 5; n++) ...[
              if (n > 1) const SizedBox(width: KSpace.md),
              Expanded(
                child: _Star(
                  key: ValueKey('feedback-star-$n'),
                  number: n,
                  label: _ratingLabels[n - 1],
                  filled: rating != null && n <= rating,
                  selected: rating == n,
                  onTap: _sending
                      ? null
                      : () => setState(() {
                          _rating = n;
                          _error = null;
                        }),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: KSpace.md),
        Text(
          rating == null ? 'Tap a star to rate' : _ratingLabels[rating - 1],
          textAlign: TextAlign.center,
          style: KharisText.itemTitle.copyWith(
            color: rating == null ? k.muted : k.text,
          ),
        ),
        if (rating != null) ...[
          const SizedBox(height: KSpace.x3),
          KTextField(
            key: const ValueKey('feedback-comment'),
            controller: _comment,
            label: lowRating
                ? 'What should we improve? (optional)'
                : 'What do you value most? (optional)',
            enabled: !_sending,
            minLines: 3,
            maxLines: 5,
            maxLength: AppFeedbackRepository.maxCommentLength,
            textCapitalization: TextCapitalization.sentences,
          ),
        ],
        if (error != null) ...[
          const SizedBox(height: KSpace.lg),
          KInlineError(error),
        ],
        const SizedBox(height: KSpace.x3),
        KButton(
          label: 'Send feedback',
          size: KButtonSize.cta,
          expand: true,
          loading: _sending,
          onPressed: rating == null ? null : _send,
        ),
        const SizedBox(height: KSpace.xs),
        if (widget.source == FeedbackSource.prompt)
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: KSpace.md,
            children: [
              KTextLink(
                label: 'Don’t ask again',
                onTap: _sending
                    ? null
                    : () => _close(FeedbackSheetOutcome.optOut),
              ),
              KTextLink(
                label: 'Not now',
                onTap: _sending
                    ? null
                    : () => _close(FeedbackSheetOutcome.notNow),
              ),
            ],
          )
        else
          Center(
            child: KTextLink(
              label: 'Cancel',
              onTap: _sending ? null : () => Navigator.of(context).pop(),
            ),
          ),
      ],
    );
  }

  Widget _thanks(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: KEmptyState(
        icon: KIcons.check,
        title: 'Thank you',
        hint: 'Your feedback has been sent to the Kharis team.',
        action: KButton(
          label: 'Done',
          expand: true,
          onPressed: () => _close(FeedbackSheetOutcome.sent),
        ),
      ),
    );
  }
}

/// One step of the five-star rating: the star mark over its number. Stars up
/// to the chosen rating are filled tiles, the rest outlined, and the chosen
/// one is announced as selected, so the rating never rests on colour alone.
class _Star extends StatelessWidget {
  const _Star({
    super.key,
    required this.number,
    required this.label,
    required this.filled,
    required this.selected,
    required this.onTap,
  });

  final int number;
  final String label;
  final bool filled;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final ink = filled ? k.onInverse : k.muted;
    const shape = BorderRadius.all(Radius.circular(KRadius.button));

    return Semantics(
      button: true,
      enabled: onTap != null,
      selected: selected,
      label: '$number of 5 stars, $label',
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: filled ? k.inverse : k.sheet,
        shape: RoundedRectangleBorder(
          borderRadius: shape,
          side: BorderSide(
            color: filled ? k.inverse : k.line,
            width: KSize.outline,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: KSize.touchMin,
              minHeight: KSize.listRow,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: KSpace.md),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  KIcon(KIcons.sparkle, color: ink),
                  const SizedBox(height: KSpace.xxs),
                  Text(
                    '$number',
                    style: KharisText.caption.copyWith(color: ink),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
