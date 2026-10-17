import 'dart:async';
import 'dart:ui' show Tristate;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:kharis_app/core/utils/playback_timestamp.dart';
import 'package:kharis_app/features/notes/presentation/widgets/sermon_notes_sheet.dart'
    show NoteTimelineBinding;
import 'package:kharis_app/features/player/presentation/widgets/transcript_sheet.dart';
import 'package:kharis_app/shared/models/sermon.dart';
import 'package:kharis_app/shared/providers/audio_provider.dart';
import 'package:kharis_app/shared/providers/transcript_provider.dart';

import 'support/fake_audio_player_service.dart';

/// Answers every request with [status] and [body], or fails the connection.
Dio _dio({int? status, String body = '', bool offline = false}) =>
    Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (offline) {
              handler.reject(
                DioException.connectionError(
                  requestOptions: options,
                  reason: 'offline',
                ),
              );
              return;
            }
            final response = Response<String>(
              requestOptions: options,
              statusCode: status,
              data: body,
            );
            if (status != null && status >= 400) {
              handler.reject(
                DioException.badResponse(
                  statusCode: status,
                  requestOptions: options,
                  response: response,
                ),
              );
            } else {
              handler.resolve(response);
            }
          },
        ),
      );

const _sermon = Sermon(
  id: '23052',
  title: 'Test message',
  speaker: 'David Antwi',
  audioUrl: 'https://x.test/a.mp3',
  transcriptUrl: 'https://x.test/transcripts/23052.txt',
);

const _other = Sermon(
  id: '9004',
  title: 'Another message',
  speaker: 'David Antwi',
  audioUrl: 'https://x.test/b.mp3',
);

/// Forty 30-second stretches, three of them mentioning grace: tall enough
/// to scroll well past the sheet in the 800x600 test view.
String _line(int i) =>
    'Line $i of the message${const {3, 10, 30}.contains(i) ? ' on Grace' : ''}.';
Duration _at(int i) => Duration(seconds: 30 * i);
final _timedBody = [
  for (var i = 0; i < 40; i++)
    '[${formatPlaybackTimestamp(_at(i))}] ${_line(i)}',
].join('\n');

Future<void> _openSheet(
  WidgetTester tester,
  Dio dio, {
  FakeAudioPlayerService? audio,
  NoteTimelineBinding? timeline,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        transcriptDioProvider.overrideWithValue(dio),
        audioPlayerServiceProvider.overrideWithValue(
          audio ?? FakeAudioPlayerService(),
        ),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: TranscriptSheet(sermon: _sermon, timeline: timeline),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder get _viewport => find.byType(SingleChildScrollView);

double _scrollOffset(WidgetTester tester) =>
    tester.widget<SingleChildScrollView>(_viewport).controller!.offset;

/// Where [text]'s top sits in the scroll view, as a fraction of its height.
double _placement(WidgetTester tester, String text) {
  final view = tester.getRect(_viewport);
  return (tester.getRect(find.text(text)).top - view.top) / view.height;
}

bool _isSpoken(WidgetTester tester, String text) =>
    tester
        .getSemantics(find.text(text))
        .getSemanticsData()
        .flagsCollection
        .isSelected ==
    Tristate.isTrue;

int _spokenCount(WidgetTester tester) => [
  for (var i = 0; i < 40; i++)
    if (_isSpoken(tester, _line(i))) i,
].length;

Future<void> _play(
  WidgetTester tester,
  FakeAudioPlayerService audio,
  Duration at,
) async {
  audio.positions.add(at);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('states', () {
    // The R2 catalogue lists transcript links whose files were never
    // uploaded; that is "no transcript", not a connection problem.
    for (final status in [404, 403]) {
      testWidgets('a $status transcript file reads as no transcript, '
          'with no retry', (tester) async {
        await _openSheet(tester, _dio(status: status));
        expect(
          find.text('No transcript is available for this message.'),
          findsOneWidget,
        );
        expect(find.textContaining('connection'), findsNothing);
        expect(find.text('Retry'), findsNothing);
      });
    }

    testWidgets('an empty file reads as no transcript', (tester) async {
      await _openSheet(tester, _dio(status: 200, body: '  \n'));
      expect(
        find.text('No transcript is available for this message.'),
        findsOneWidget,
      );
    });

    testWidgets('a real connection failure still offers a retry', (
      tester,
    ) async {
      await _openSheet(tester, _dio(offline: true));
      expect(find.textContaining('connection'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('a transcript without timestamps is shown as plain text', (
      tester,
    ) async {
      final audio = FakeAudioPlayerService()..current = _sermon;
      await _openSheet(
        tester,
        _dio(status: 200, body: 'Welcome to Kharis Church'),
        audio: audio,
      );
      expect(find.text('Welcome to Kharis Church'), findsOneWidget);

      await tester.tap(find.text('Welcome to Kharis Church'));
      await tester.pump();
      expect(audio.calls, isEmpty, reason: 'nothing to seek to');
    });
  });

  group('follow-along', () {
    late FakeAudioPlayerService audio;

    setUp(() => audio = FakeAudioPlayerService());

    Future<void> open(WidgetTester tester, {Sermon? playing}) async {
      audio.current = playing;
      await _openSheet(
        tester,
        _dio(status: 200, body: _timedBody),
        audio: audio,
      );
    }

    testWidgets('highlights the stretch being spoken and keeps it a third '
        'of the way down', (tester) async {
      await open(tester, playing: _sermon);
      expect(find.text('0:00'), findsOneWidget);
      expect(_isSpoken(tester, _line(0)), isTrue);

      await _play(tester, audio, _at(12) + const Duration(seconds: 29));
      expect(_isSpoken(tester, _line(12)), isTrue);
      expect(_spokenCount(tester), 1);
      expect(_placement(tester, _line(12)), closeTo(1 / 3, 0.1));

      await _play(tester, audio, _at(25));
      expect(_isSpoken(tester, _line(25)), isTrue);
      expect(_placement(tester, _line(25)), closeTo(1 / 3, 0.1));
    });

    testWidgets('another message on air highlights nothing', (tester) async {
      await open(tester, playing: _other);
      await _play(tester, audio, _at(12));
      expect(_spokenCount(tester), 0);
      expect(_scrollOffset(tester), 0);
      expect(find.text('Back to now'), findsNothing);
    });

    testWidgets('scrolling by hand pauses follow-along until Back to now', (
      tester,
    ) async {
      await open(tester, playing: _sermon);
      await _play(tester, audio, _at(20));
      expect(find.text('Back to now'), findsNothing);

      await tester.drag(_viewport, const Offset(0, 250));
      await tester.pumpAndSettle();
      expect(find.text('Back to now'), findsOneWidget);

      final parked = _scrollOffset(tester);
      await _play(tester, audio, _at(21));
      expect(_isSpoken(tester, _line(21)), isTrue);
      expect(_scrollOffset(tester), parked, reason: 'no longer following');

      await tester.tap(find.text('Back to now'));
      await tester.pumpAndSettle();
      expect(find.text('Back to now'), findsNothing);
      expect(_placement(tester, _line(21)), closeTo(1 / 3, 0.1));

      await _play(tester, audio, _at(24));
      expect(_placement(tester, _line(24)), closeTo(1 / 3, 0.1));
    });

    testWidgets('tapping a stretch plays the message from its timestamp', (
      tester,
    ) async {
      await open(tester, playing: _sermon);
      await tester.tap(find.text(_line(3)));
      await tester.pumpAndSettle();

      expect(audio.calls, hasLength(1));
      expect(audio.calls.single.sermon.id, _sermon.id);
      expect(audio.calls.single.startAt, _at(3));
      expect(_isSpoken(tester, _line(3)), isTrue);
    });

    testWidgets('in video mode it follows and seeks the bound engine', (
      tester,
    ) async {
      final positions = StreamController<Duration>.broadcast();
      addTearDown(positions.close);
      final seeks = <Duration>[];
      await _openSheet(
        tester,
        _dio(status: 200, body: _timedBody),
        audio: audio,
        timeline: NoteTimelineBinding(
          position: positions.stream,
          seek: (target) async => seeks.add(target),
        ),
      );

      positions.add(_at(2) + const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(_isSpoken(tester, _line(2)), isTrue);

      await tester.tap(find.text(_line(5)));
      await tester.pumpAndSettle();
      expect(seeks, [_at(5)]);
      expect(audio.calls, isEmpty);
      expect(audio.seekCalls, isEmpty);
    });
  });

  group('search', () {
    testWidgets('counts and steps through matches, case-insensitively', (
      tester,
    ) async {
      final audio = FakeAudioPlayerService()..current = _sermon;
      await _openSheet(
        tester,
        _dio(status: 200, body: _timedBody),
        audio: audio,
      );

      await tester.enterText(find.byType(TextField), 'grace');
      await tester.pumpAndSettle();
      expect(find.text('1 of 3'), findsOneWidget);
      // Searching takes the view off "now".
      expect(find.text('Back to now'), findsOneWidget);

      await tester.tap(find.byTooltip('Next match'));
      await tester.pumpAndSettle();
      expect(find.text('2 of 3'), findsOneWidget);
      expect(_placement(tester, _line(10)), closeTo(1 / 3, 0.1));

      await tester.tap(find.byTooltip('Previous match'));
      await tester.tap(find.byTooltip('Previous match'));
      await tester.pumpAndSettle();
      expect(find.text('3 of 3'), findsOneWidget, reason: 'wraps around');
      expect(_placement(tester, _line(30)), closeTo(1 / 3, 0.1));

      // A match's stretch seeks like any other.
      await tester.tap(find.text(_line(30)));
      await tester.pumpAndSettle();
      expect(audio.calls.single.startAt, _at(30));

      await tester.enterText(find.byType(TextField), 'mercy');
      await tester.pumpAndSettle();
      expect(find.text('No matches in this transcript'), findsOneWidget);

      await tester.tap(find.byTooltip('Clear search'));
      await tester.pumpAndSettle();
      expect(find.text('No matches in this transcript'), findsNothing);
      expect(find.textContaining(' of 3'), findsNothing);
    });
  });
}
