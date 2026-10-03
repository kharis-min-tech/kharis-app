import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import 'package:kharis_app/features/feedback/data/app_feedback_repository.dart';
import 'package:kharis_app/features/feedback/domain/review_prompt_policy.dart';
import 'package:kharis_app/features/feedback/presentation/feedback_sheet.dart';
import 'package:kharis_app/features/feedback/providers/feedback_providers.dart';
import 'package:kharis_app/shared/providers/audio_provider.dart';

/// Asks for a rating or feedback at the end of a listen, at most once per
/// app session.
///
/// Tracks engagement (active days, completed listens) and, when an audio
/// message plays through to the end while the app is in the foreground,
/// waits [settleDelay] and asks [ReviewPromptPolicy] what to do. Never fires
/// on launch, mid-playback, or while [canInterrupt] says no.
class ReviewPromptListener extends ConsumerStatefulWidget {
  const ReviewPromptListener({
    super.key,
    required this.child,
    this.canInterrupt,
  });

  final Widget child;

  /// Return false on screens that must not be interrupted (e.g. Giving).
  final bool Function()? canInterrupt;

  /// Pause after a listen ends, so the prompt never cuts the last words off.
  static const settleDelay = Duration(seconds: 2);

  @override
  ConsumerState<ReviewPromptListener> createState() =>
      _ReviewPromptListenerState();
}

class _ReviewPromptListenerState extends ConsumerState<ReviewPromptListener>
    with WidgetsBindingObserver {
  bool _askedThisSession = false;
  ProcessingState? _lastProcessing;
  Timer? _pending;
  AppLifecycleState _lifecycle =
      WidgetsBinding.instance.lifecycleState ?? AppLifecycleState.resumed;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _recordActiveDay();
  }

  @override
  void dispose() {
    _pending?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycle = state;
    if (state == AppLifecycleState.resumed) {
      _recordActiveDay();
    } else {
      _pending?.cancel();
    }
  }

  void _recordActiveDay() => unawaited(
    ref
        .read(reviewPromptStoreProvider)
        .recordActiveDay(ref.read(reviewClockProvider)()),
  );

  Future<void> _onListenCompleted() async {
    await ref.read(reviewPromptStoreProvider).recordCompletedListen();
    if (!mounted ||
        _askedThisSession ||
        _lifecycle != AppLifecycleState.resumed) {
      return;
    }
    _pending?.cancel();
    _pending = Timer(ReviewPromptListener.settleDelay, _maybeAsk);
  }

  Future<void> _maybeAsk() async {
    if (!_canAskNow()) return;
    final storeReview = ref.read(storeReviewProvider);
    final nativeAvailable = await storeReview.isAvailable();
    if (!_canAskNow()) return;

    final store = ref.read(reviewPromptStoreProvider);
    final now = ref.read(reviewClockProvider)();
    final action = ReviewPromptPolicy.decide(
      store.read(),
      now,
      nativeAvailable: nativeAvailable,
    );
    switch (action) {
      case ReviewPromptAction.none:
        return;
      case ReviewPromptAction.nativeReview:
        _askedThisSession = true;
        await store.recordNativeRequested(now);
        await storeReview.request();
      case ReviewPromptAction.feedbackSheet:
        _askedThisSession = true;
        await store.recordSheetAutoShown();
        if (!mounted) return;
        await showFeedbackSheet(context, ref, source: FeedbackSource.prompt);
    }
  }

  bool _canAskNow() {
    if (!mounted ||
        _askedThisSession ||
        _lifecycle != AppLifecycleState.resumed) {
      return false;
    }
    if (widget.canInterrupt?.call() == false) return false;
    // The member already started something else: don't interrupt it.
    final state = ref.read(playerStateProvider).valueOrNull;
    if (state != null &&
        state.playing &&
        state.processingState != ProcessingState.completed) {
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<PlayerState>>(playerStateProvider, (_, next) {
      final processing = next.valueOrNull?.processingState;
      final previous = _lastProcessing;
      _lastProcessing = processing;
      if (processing == ProcessingState.completed &&
          previous != ProcessingState.completed) {
        unawaited(_onListenCompleted());
      }
    });
    return widget.child;
  }
}
