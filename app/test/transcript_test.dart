import 'package:flutter_test/flutter_test.dart';

import 'package:kharis_app/core/utils/playback_timestamp.dart';
import 'package:kharis_app/features/player/domain/transcript.dart';

Duration _t(int minutes, [int seconds = 0, int hours = 0]) =>
    Duration(hours: hours, minutes: minutes, seconds: seconds);

void main() {
  group('Transcript.parse', () {
    test('splits at m:ss, mm:ss and h:mm:ss markers, whitespace collapsed', () {
      final t = Transcript.parse(
        '[0:00] Welcome to\n  Kharis.\n\n[12:05] Turn with me '
        '[59:59] to Romans. [1:00:00] Amen.',
      );
      expect(t.segments, const [
        TranscriptSegment(start: Duration.zero, text: 'Welcome to Kharis.'),
        TranscriptSegment(
          start: Duration(minutes: 12, seconds: 5),
          text: 'Turn with me',
        ),
        TranscriptSegment(
          start: Duration(minutes: 59, seconds: 59),
          text: 'to Romans.',
        ),
        TranscriptSegment(start: Duration(hours: 1), text: 'Amen.'),
      ]);
      expect(t.isTimed, isTrue);
    });

    test('text before the first marker is one untimed preamble', () {
      final t = Transcript.parse(
        'This transcript was generated automatically.\n[0:04] Good morning.',
      );
      expect(t.segments.first.start, isNull);
      expect(
        t.segments.first.text,
        'This transcript was generated automatically.',
      );
      expect(t.segments.last.start, _t(0, 4));
    });

    test('a file without markers is one untimed block, still searchable', () {
      final t = Transcript.parse('Grace and peace\nto you.');
      expect(t.segments, const [
        TranscriptSegment(start: null, text: 'Grace and peace to you.'),
      ]);
      expect(t.isTimed, isFalse);
      expect(t.segmentAt(_t(5)), isNull);
      expect(t.search('peace'), hasLength(1));
    });

    test('malformed markers stay in the text; empty stretches are dropped', () {
      final t = Transcript.parse(
        '[0:00] One [1:7] two [0:75] three [1:60:00] four [Music] five '
        '[0:30][0:31] Six',
      );
      expect(t.segments, const [
        TranscriptSegment(
          start: Duration.zero,
          text: 'One [1:7] two [0:75] three [1:60:00] four [Music] five',
        ),
        TranscriptSegment(start: Duration(seconds: 31), text: 'Six'),
      ]);
    });
  });

  group('segmentAt', () {
    final t = Transcript.parse('Intro [0:05] a [0:20] b [1:00:00] c');
    // Segments: 0 untimed intro, 1 @0:05, 2 @0:20, 3 @1:00:00.

    test('nothing is spoken before the first marker', () {
      expect(t.segmentAt(Duration.zero), isNull);
      expect(
        t.segmentAt(const Duration(seconds: 4, milliseconds: 999)),
        isNull,
      );
    });

    test('a segment starts exactly at its marker and runs to the next', () {
      expect(t.segmentAt(_t(0, 5)), 1);
      expect(t.segmentAt(const Duration(seconds: 19, milliseconds: 999)), 1);
      expect(t.segmentAt(_t(0, 20)), 2);
      expect(t.segmentAt(_t(59, 59)), 2);
    });

    test('the last segment holds to the end', () {
      expect(t.segmentAt(_t(0, 0, 1)), 3);
      expect(t.segmentAt(_t(30, 0, 2)), 3);
    });
  });

  group('search', () {
    final t = Transcript.parse(
      '[0:00] GRACE upon grace. [0:10] Café — don’t miss the Grâce. '
      '[0:20] Naïve faith',
    );

    String hit(TranscriptMatch m) =>
        t.segments[m.segment].text.substring(m.start, m.end);

    test('is case- and diacritics-insensitive, in reading order', () {
      final matches = t.search('grace');
      expect(matches.map((m) => m.segment), [0, 0, 1]);
      expect(matches.map(hit), ['GRACE', 'grace', 'Grâce']);
      expect(t.search('CAFE').map(hit), ['Café']);
      expect(t.search('naive').map(hit), ['Naïve']);
    });

    test('folds typographic quotes and collapses query whitespace', () {
      expect(t.search("don't").map(hit), ['don’t']);
      expect(t.search('  upon \n grace ').map(hit), ['upon grace']);
    });

    test('maps hits back through decomposed accents', () {
      final decomposed = Transcript.parse('[0:00] cafe\u0301 au lait');
      final m = decomposed.search('cafe au').single;
      expect(
        decomposed.segments.single.text.substring(m.start, m.end),
        'cafe\u0301 au',
      );
    });

    test('a blank query or a miss finds nothing', () {
      expect(t.search(''), isEmpty);
      expect(t.search('   '), isEmpty);
      expect(t.search('mercy'), isEmpty);
    });
  });

  test('timestamps read m:ss under an hour, h:mm:ss from an hour', () {
    expect(formatPlaybackTimestamp(Duration.zero), '0:00');
    expect(formatPlaybackTimestamp(_t(12, 5)), '12:05');
    expect(formatPlaybackTimestamp(_t(59, 59)), '59:59');
    expect(formatPlaybackTimestamp(_t(2, 7, 1)), '1:02:07');
    expect(formatPlaybackTimestamp(-_t(1)), '0:00');
  });
}
