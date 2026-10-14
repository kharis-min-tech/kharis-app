import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kharis_app/features/messages/presentation/widgets/sermon_list_item.dart';
import 'package:kharis_app/features/player/data/playback_history.dart';
import 'package:kharis_app/shared/models/sermon.dart';
import 'package:kharis_app/shared/providers/audio_provider.dart';
import 'package:kharis_app/shared/providers/cache_provider.dart';

import 'support/fake_cache_service.dart';

const _sermon = Sermon(
  id: '2700',
  title: 'Let The Bible Speak',
  speaker: 'David Antwi',
  audioUrl: 'https://x.test/2700.mp3',
  duration: Duration(minutes: 56),
);

void main() {
  group('PlaybackHistory.progressOf', () {
    late PlaybackHistory history;
    setUp(() => history = PlaybackHistory(FakeCacheService()));

    test('never played, or only a few seconds, is not started', () {
      expect(history.progressOf(_sermon), isA<NotStarted>());
      history.savePosition(_sermon, const Duration(seconds: 8));
      expect(history.progressOf(_sermon), isA<NotStarted>());
    });

    test('part-way through reports time left and a fraction', () {
      history.savePosition(_sermon, const Duration(minutes: 28));
      final p = history.progressOf(_sermon) as InProgress;
      expect(p.remaining, const Duration(minutes: 28));
      expect(p.fraction, closeTo(0.5, 0.001));
    });

    test('played to the end is finished, and restarts from the top', () {
      history.savePosition(_sermon, const Duration(minutes: 40));
      history.markFinished(_sermon);
      expect(history.progressOf(_sermon), isA<Finished>());
      expect(history.resumePoint(_sermon), isNull);
    });

    test('playing a finished message again shows its new progress', () {
      history.markFinished(_sermon);
      history.savePosition(_sermon, const Duration(minutes: 10));
      expect(history.progressOf(_sermon), isA<InProgress>());
    });

    test('a position in the closing seconds counts as finished', () {
      history.savePosition(_sermon, const Duration(minutes: 55, seconds: 50));
      expect(history.progressOf(_sermon), isA<Finished>());
    });

    test('unknown length: in progress without time left', () {
      const noLength = Sermon(
        id: '9',
        title: 'x',
        speaker: 'y',
        audioUrl: 'https://x.test/9.mp3',
      );
      history.savePosition(noLength, const Duration(minutes: 3));
      final p = history.progressOf(noLength) as InProgress;
      expect(p.remaining, isNull);
      expect(p.fraction, isNull);
    });
  });

  test('time left labels', () {
    expect(timeLeftLabel(const Duration(seconds: 30)), 'Under 1 min left');
    expect(timeLeftLabel(const Duration(minutes: 28)), '28 min left');
    expect(
      timeLeftLabel(const Duration(minutes: 27, seconds: 10)),
      '28 min left',
    );
    expect(timeLeftLabel(const Duration(minutes: 60)), '1 h left');
    expect(timeLeftLabel(const Duration(minutes: 65)), '1 h 5 min left');
  });

  group('row', () {
    Future<PlaybackHistory> pumpRow(WidgetTester tester) async {
      final container = ProviderContainer(
        overrides: [cacheServiceProvider.overrideWithValue(FakeCacheService())],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) => SermonListItem(
                  title: _sermon.title,
                  speaker: _sermon.speaker,
                  durationLabel: '56m',
                  dateLabel: 'Aug 2026',
                  listening: ref.watch(listeningProgressProvider(_sermon)),
                ),
              ),
            ),
          ),
        ),
      );
      return container.read(playbackHistoryProvider);
    }

    testWidgets('shows length until played, then time left with a bar, '
        'then Finished, updating live', (tester) async {
      final history = await pumpRow(tester);
      expect(find.text('Aug 2026 · 56m'), findsOneWidget);
      expect(find.byKey(const Key('listening-progress')), findsNothing);

      history.savePosition(_sermon, const Duration(minutes: 28));
      await tester.pumpAndSettle();
      expect(find.text('Aug 2026 · 28 min left'), findsOneWidget);
      expect(find.byKey(const Key('listening-progress')), findsOneWidget);

      history.markFinished(_sermon);
      await tester.pumpAndSettle();
      expect(find.text('Aug 2026 · 56m · Finished'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
      expect(find.byKey(const Key('listening-progress')), findsNothing);
    });
  });
}
