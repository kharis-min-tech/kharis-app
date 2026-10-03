import 'dart:async';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kharis_app/features/feedback/data/app_feedback_repository.dart';
import 'package:kharis_app/features/feedback/data/review_prompt_store.dart';
import 'package:kharis_app/features/feedback/data/store_review.dart';
import 'package:kharis_app/features/feedback/domain/review_prompt_policy.dart';
import 'package:kharis_app/features/feedback/presentation/feedback_sheet.dart';
import 'package:kharis_app/features/feedback/presentation/review_prompt_listener.dart';
import 'package:kharis_app/features/feedback/providers/feedback_providers.dart';
import 'package:kharis_app/shared/models/user.dart';
import 'package:kharis_app/shared/providers/audio_provider.dart';
import 'package:kharis_app/shared/providers/auth_provider.dart';
import 'package:kharis_app/shared/providers/branch_provider.dart';
import 'package:kharis_app/shared/providers/onboarding_provider.dart';

class _FakeStoreReview extends StoreReview {
  _FakeStoreReview({required this.available});

  final bool available;
  int requests = 0;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<void> request() async => requests++;
}

final _now = DateTime(2026, 10, 3, 12);
final _today = '${_now.year}-${_now.month}-${_now.day}';

/// Prefs for a listener who is one completed listen away from [target].
Map<String, Object> _readyFor(ReviewPromptAction target) => {
  'review_first_open_ms': _now
      .subtract(const Duration(days: 10))
      .millisecondsSinceEpoch,
  'review_last_active_day': _today,
  'review_active_days': target == ReviewPromptAction.nativeReview ? 5 : 3,
  'review_completed_listens': target == ReviewPromptAction.nativeReview ? 2 : 1,
};

class _Harness {
  _Harness(this.player, this.db, this.storeReview, this.prefs);

  final StreamController<PlayerState> player;
  final FakeFirebaseFirestore db;
  final _FakeStoreReview storeReview;
  final SharedPreferences prefs;

  ReviewPromptState get state => ReviewPromptStore(prefs).read();

  /// Plays a message through to the end and lets the settle delay pass.
  Future<void> finishListen(WidgetTester tester) async {
    player.add(PlayerState(true, ProcessingState.ready));
    await tester.pump();
    player.add(PlayerState(true, ProcessingState.completed));
    await tester.pump();
    await tester.pump(ReviewPromptListener.settleDelay);
    await tester.pumpAndSettle();
  }
}

Future<_Harness> _pump(
  WidgetTester tester, {
  required Map<String, Object> prefs,
  bool nativeAvailable = false,
  bool Function()? canInterrupt,
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final sp = await SharedPreferences.getInstance();
  final player = StreamController<PlayerState>.broadcast();
  addTearDown(player.close);
  final db = FakeFirebaseFirestore();
  final storeReview = _FakeStoreReview(available: nativeAvailable);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sp),
        firestoreProvider.overrideWithValue(db),
        currentUserProvider.overrideWith(
          (ref) => Stream.value(
            User(
              id: 'member-1',
              email: '',
              displayName: 'Guest',
              role: 'guest',
              createdAt: DateTime(2026),
            ),
          ),
        ),
        playerStateProvider.overrideWith((ref) => player.stream),
        storeReviewProvider.overrideWithValue(storeReview),
        reviewClockProvider.overrideWithValue(() => _now),
      ],
      child: MaterialApp(
        home: ReviewPromptListener(
          canInterrupt: canInterrupt,
          child: Scaffold(
            body: Consumer(
              builder: (context, ref, _) => TextButton(
                onPressed: () => showFeedbackSheet(
                  context,
                  ref,
                  source: FeedbackSource.settings,
                ),
                child: const Text('Send Feedback'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return _Harness(player, db, storeReview, sp);
}

final _sheetTitle = find.text('How is the Kharis app serving you?');

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  _settingsTests();

  testWidgets('launching the app counts an active day but never prompts', (
    tester,
  ) async {
    final h = await _pump(tester, prefs: {});
    expect(h.state.firstOpenAt, _now);
    expect(h.state.activeDays, 1);
    expect(_sheetTitle, findsNothing);
    expect(h.storeReview.requests, 0);
  });

  testWidgets('a listen before the thresholds only counts the listen', (
    tester,
  ) async {
    final h = await _pump(tester, prefs: {});
    await h.finishListen(tester);
    expect(h.state.completedListens, 1);
    expect(_sheetTitle, findsNothing);
  });

  testWidgets('end of a listen: sheet opens, low rating + comment is saved, '
      'thanks shown, outcome recorded', (tester) async {
    final h = await _pump(
      tester,
      prefs: _readyFor(ReviewPromptAction.feedbackSheet),
    );
    await h.finishListen(tester);

    expect(_sheetTitle, findsOneWidget);
    expect(h.state.sheetAutoShows, 1);

    // Nothing to send until a star is chosen.
    final send = find.widgetWithText(ElevatedButton, 'Send feedback');
    expect(tester.widget<ElevatedButton>(send).onPressed, isNull);

    await tester.tap(find.byKey(const ValueKey('feedback-star-2')));
    await tester.pumpAndSettle();
    expect(find.text('Could be better'), findsOneWidget);
    expect(find.text('What should we improve? (optional)'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('feedback-comment')),
      'Downloads please',
    );
    await tester.tap(send);
    await tester.pumpAndSettle();

    expect(find.text('Thank you'), findsOneWidget);
    final saved = (await h.db.collection('app_feedback').get()).docs;
    expect(saved, hasLength(1));
    expect(saved.single.data()['rating'], 2);
    expect(saved.single.data()['comment'], 'Downloads please');
    expect(saved.single.data()['source'], 'prompt');
    expect(saved.single.data()['uid'], 'member-1');

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(_sheetTitle, findsNothing);
    expect(h.state.lastSheetOutcome, FeedbackSheetOutcome.sent);
    expect(h.state.lastSheetAt, _now);
    // The rating never triggers the store card.
    expect(h.storeReview.requests, 0);
  });

  testWidgets('a send is recorded even if the thanks is swiped away', (
    tester,
  ) async {
    final h = await _pump(
      tester,
      prefs: _readyFor(ReviewPromptAction.feedbackSheet),
    );
    await h.finishListen(tester);
    await tester.tap(find.byKey(const ValueKey('feedback-star-5')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Send feedback'));
    await tester.pumpAndSettle();

    // Tap the barrier above the sheet.
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.text('Thank you'), findsNothing);
    expect(h.state.lastSheetOutcome, FeedbackSheetOutcome.sent);
  });

  testWidgets('"Don\'t ask again" opts out of the automatic sheet', (
    tester,
  ) async {
    final h = await _pump(
      tester,
      prefs: _readyFor(ReviewPromptAction.feedbackSheet),
    );
    await h.finishListen(tester);
    await tester.tap(find.text('Don’t ask again'));
    await tester.pumpAndSettle();

    expect(_sheetTitle, findsNothing);
    expect(h.state.sheetOptedOut, isTrue);
    expect((await h.db.collection('app_feedback').get()).docs, isEmpty);
  });

  testWidgets('dismissing the sheet counts as "Not now"', (tester) async {
    final h = await _pump(
      tester,
      prefs: _readyFor(ReviewPromptAction.feedbackSheet),
    );
    await h.finishListen(tester);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(_sheetTitle, findsNothing);
    expect(h.state.lastSheetOutcome, FeedbackSheetOutcome.notNow);
  });

  testWidgets('an established listener gets the native card, not the sheet', (
    tester,
  ) async {
    final h = await _pump(
      tester,
      prefs: _readyFor(ReviewPromptAction.nativeReview),
      nativeAvailable: true,
    );
    await h.finishListen(tester);

    expect(h.storeReview.requests, 1);
    expect(_sheetTitle, findsNothing);
    expect(h.state.nativeRequests, 1);
    expect(h.state.lastNativeAt, _now);
  });

  testWidgets('asks at most once per session', (tester) async {
    final h = await _pump(
      tester,
      prefs: _readyFor(ReviewPromptAction.feedbackSheet),
    );
    await h.finishListen(tester);
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();

    // Even if the policy would allow it, a second listen stays quiet.
    await h.prefs.remove('review_sheet_outcome');
    await h.prefs.remove('review_sheet_last_ms');
    await h.finishListen(tester);
    expect(_sheetTitle, findsNothing);
    expect(h.state.sheetAutoShows, 1);
  });

  testWidgets('starting the next message during the pause cancels the prompt', (
    tester,
  ) async {
    final h = await _pump(
      tester,
      prefs: _readyFor(ReviewPromptAction.feedbackSheet),
    );
    h.player.add(PlayerState(true, ProcessingState.ready));
    await tester.pump();
    h.player.add(PlayerState(true, ProcessingState.completed));
    await tester.pump();
    // Member taps the next message before the settle delay ends.
    h.player.add(PlayerState(true, ProcessingState.buffering));
    await tester.pump(ReviewPromptListener.settleDelay);
    await tester.pumpAndSettle();

    expect(_sheetTitle, findsNothing);
    expect(h.state.sheetAutoShows, 0);
  });

  testWidgets('never interrupts a screen that says no (Giving)', (
    tester,
  ) async {
    final h = await _pump(
      tester,
      prefs: _readyFor(ReviewPromptAction.feedbackSheet),
      canInterrupt: () => false,
    );
    await h.finishListen(tester);
    expect(_sheetTitle, findsNothing);
    expect(h.state.completedListens, 2);
  });

  testWidgets('a listen that ends with the app in the background is not used', (
    tester,
  ) async {
    final h = await _pump(
      tester,
      prefs: _readyFor(ReviewPromptAction.feedbackSheet),
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await h.finishListen(tester);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(_sheetTitle, findsNothing);
    expect(h.state.completedListens, 2);
  });
}

void _settingsTests() {
  testWidgets('Settings entry: Cancel records nothing, a send records sent', (
    tester,
  ) async {
    final h = await _pump(tester, prefs: {});

    await tester.tap(find.text('Send Feedback'));
    await tester.pumpAndSettle();
    expect(_sheetTitle, findsOneWidget);
    // Opened on purpose: no "Don't ask again" / "Not now" choices.
    expect(find.text('Don’t ask again'), findsNothing);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(h.state.lastSheetOutcome, isNull);

    await tester.tap(find.text('Send Feedback'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('feedback-star-4')));
    await tester.pumpAndSettle();
    expect(find.text('What do you value most? (optional)'), findsOneWidget);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Send feedback'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    final saved = (await h.db.collection('app_feedback').get()).docs;
    expect(saved.single.data()['source'], 'settings');
    expect(saved.single.data()['comment'], '');
    expect(h.state.lastSheetOutcome, FeedbackSheetOutcome.sent);
    // Opening from Settings is not an automatic show.
    expect(h.state.sheetAutoShows, 0);
  });
}
